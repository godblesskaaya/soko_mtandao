import { serve } from "https://deno.land/std@0.223.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL"),
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
);

export async function logPayment(paymentExternalId: string, level: string, message: string, payload = {}) {
  try {
    await supabase.from("payment_logs").insert({
      level,
      message,
      payload: {
        payment_external_id: paymentExternalId,
        ...payload,
      },
    });
  } catch (e) {
    console.error("failed to log to db", e);
  }
}

function normalizePaymentStatus(raw: string | undefined): "success" | "failed" | "pending" {
  const status = (raw || "").toLowerCase();
  if (status === "success") return "success";
  if (status === "failed") return "failed";
  return "pending";
}

serve(async (req) => {
  try {
    const payload = await req.json();
    const utilityref = payload.utilityref;

    if (!utilityref) {
      return new Response("Missing utility reference", { status: 400 });
    }

    await logPayment(utilityref, "info", "callback payload", { payload });

    const { data: payment } = await supabase
      .from("payments")
      .select("id,booking_id,status")
      .eq("external_id", utilityref)
      .maybeSingle();

    if (!payment) return new Response("Payment not found", { status: 404 });

    const newStatus = normalizePaymentStatus(payload.transactionstatus);

    // Idempotency fast path for duplicate success callbacks.
    if (payment.status === "success" && newStatus === "success") {
      await logPayment(utilityref, "info", "duplicate success callback ignored");
      return new Response("OK", { status: 200 });
    }

    const { error: paymentUpdateError } = await supabase
      .from("payments")
      .update({
        status: newStatus,
        payment_gateway_ref: payload.reference ?? null,
      })
      .eq("id", payment.id);

    if (paymentUpdateError) {
      await logPayment(utilityref, "error", "payment update error", { paymentUpdateError });
    }

    if (newStatus === "success") {
      const bookingId = payment.booking_id;

      const { error: bookingUpdateError } = await supabase
        .from("bookings")
        .update({
          payment_status: "completed",
          status: "confirmed",
        })
        .eq("id", bookingId)
        .neq("payment_status", "completed");

      if (bookingUpdateError) {
        await logPayment(utilityref, "error", "booking update error", { bookingUpdateError });
      }

      const { data: items, error: itemsError } = await supabase
        .from("booking_items")
        .select("id,hotel_id,price_per_night,start_date,end_date")
        .eq("booking_id", bookingId);

      if (itemsError) {
        await logPayment(utilityref, "error", "failed to fetch booking items", { itemsError });
        return new Response("OK", { status: 200 });
      }

      const { data: existingSettlements } = await supabase
        .from("settlements")
        .select("booking_item_id")
        .eq("payment_id", payment.id);

      const existingItemIds = new Set((existingSettlements || []).map((s) => s.booking_item_id));

      const settlementRecords = (items || [])
        .filter((item) => !existingItemIds.has(item.id))
        .map((item) => {
          const checkIn = new Date(item.start_date);
          const checkOut = new Date(item.end_date);
          const nights = Math.max(
            1,
            Math.ceil((checkOut.getTime() - checkIn.getTime()) / (1000 * 60 * 60 * 24)),
          );

          return {
            payment_id: payment.id,
            booking_item_id: item.id,
            hotel_id: item.hotel_id,
            amount_allocated: nights * item.price_per_night,
            status: "paid",
          };
        });

      if (settlementRecords.length > 0) {
        const { error: settleError } = await supabase.from("settlements").insert(settlementRecords);
        if (settleError) {
          await logPayment(utilityref, "error", "settlement insert failed", { settleError });
        } else {
          await logPayment(
            utilityref,
            "info",
            `settlements created for ${settlementRecords.length} items`,
          );
        }
      }
    }

    return new Response("OK", { status: 200 });
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: e.message }), { status: 500 });
  }
});
