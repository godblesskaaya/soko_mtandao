import { serve } from "https://deno.land/std@0.223.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { optionalEnv, requireEnv } from "../_shared/env.ts";

const supabase = createClient(
  requireEnv("SUPABASE_URL"),
  requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
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

function getFirstString(payload: Record<string, unknown>, keys: string[]): string | null {
  const entries = Object.entries(payload);
  for (const key of keys) {
    const found = entries.find(([k]) => k.toLowerCase() === key.toLowerCase());
    if (!found || found[1] == null) continue;
    const str = found[1].toString().trim();
    if (str.length > 0) return str;
  }
  return null;
}

function extractBookingId(payload: Record<string, unknown>): string | null {
  const additional =
    (payload.additionalProperties as Record<string, unknown> | undefined) ||
    (payload.additionalproperties as Record<string, unknown> | undefined);

  const fromAdditional = additional?.bookingId?.toString();
  if (fromAdditional && fromAdditional.trim().length > 0) return fromAdditional.trim();

  const fromAdditionalLower = additional?.bookingid?.toString();
  if (fromAdditionalLower && fromAdditionalLower.trim().length > 0) return fromAdditionalLower.trim();

  const raw = getFirstString(payload, ["utilityref", "utilityRef"]) || "";
  const match = raw.match(/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/);
  return match?.[0] || null;
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
    const payloadMap = payload as Record<string, unknown>;

    const utilityref = getFirstString(payloadMap, ["utilityref", "utilityRef"]);
    const reference = getFirstString(payloadMap, ["reference", "transid", "txnReferenceNumber"]);
    const externalreference = getFirstString(payloadMap, ["externalreference", "externalReference"]);
    const fspReferenceId = getFirstString(payloadMap, ["fspReferenceId", "fspreferenceid"]);
    const bookingIdFromPayload = extractBookingId(payloadMap);

    const paymentIdCandidates = [utilityref, externalreference, reference, fspReferenceId].filter(
      (v): v is string => !!v && v.trim().length > 0,
    );

    const correlationId = paymentIdCandidates[0] || bookingIdFromPayload || "unknown";

    await logPayment(correlationId, "info", "callback payload", {
      payload,
      paymentIdCandidates,
      bookingIdFromPayload,
    });

    const callbackAmountRaw = Number(getFirstString(payloadMap, ["amount"]));
    const callbackAmount =
      Number.isFinite(callbackAmountRaw) && callbackAmountRaw > 0 ? callbackAmountRaw : null;

    let payment: { id: string; booking_id: string; status: string; amount: number | null } | null =
      null;

    for (const candidate of paymentIdCandidates) {
      const { data } = await supabase
        .from("payments")
        .select("id,booking_id,status,amount")
        .eq("external_id", candidate)
        .maybeSingle();
      if (data) {
        payment = data;
        break;
      }
    }

    if (!payment) {
      for (const candidate of paymentIdCandidates) {
        const { data } = await supabase
          .from("payments")
          .select("id,booking_id,status,amount")
          .eq("payment_gateway_ref", candidate)
          .maybeSingle();
        if (data) {
          payment = data;
          break;
        }
      }
    }

    if (!payment && bookingIdFromPayload) {
      const { data } = await supabase
        .from("payments")
        .select("id,booking_id,status,amount")
        .eq("booking_id", bookingIdFromPayload)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      if (data) {
        payment = data;
      }
    }

    if (!payment && bookingIdFromPayload) {
      const { data: booking } = await supabase
        .from("bookings")
        .select("id,total_price")
        .eq("id", bookingIdFromPayload)
        .maybeSingle();

      if (booking) {
        const bookingAmount = Number(booking.total_price);
        const amount = callbackAmount != null && callbackAmount > 0
          ? callbackAmount
          : Number.isFinite(bookingAmount) && bookingAmount > 0
          ? bookingAmount
          : 1;

        const recoveryExternalId =
          utilityref || externalreference || reference || `recovered_${booking.id}_${Date.now()}`;
        const gatewayRef = reference || fspReferenceId || null;

        const { data: createdPayment, error: createPaymentError } = await supabase
          .from("payments")
          .insert({
            booking_id: booking.id,
            amount,
            currency: "TZS",
            external_id: recoveryExternalId,
            status: "pending",
            type: "callback_recovery",
            payment_gateway_ref: gatewayRef,
            amount_received: callbackAmount,
            idempotency_key: `callback_recovery_${booking.id}_${Date.now()}`,
            azampay_response: payloadMap,
            metadata: {
              recovery: true,
              bookingIdFromPayload,
              correlationId,
            },
          })
          .select("id,booking_id,status,amount")
          .single();

        if (!createPaymentError && createdPayment) {
          payment = createdPayment;
          await logPayment(correlationId, "warn", "payment recovered from callback booking id", {
            bookingIdFromPayload,
            recoveryExternalId,
          });
        } else {
          await logPayment(correlationId, "error", "payment recovery failed", {
            createPaymentError,
            bookingIdFromPayload,
          });
        }
      }
    }

    if (!payment) {
      await logPayment(correlationId, "warn", "payment not found for callback references", {
        paymentIdCandidates,
        bookingIdFromPayload,
      });
      // Acknowledge callback to avoid endless retries; ops can reconcile from payment_logs.
      return new Response("OK", { status: 200 });
    }

    const newStatus = normalizePaymentStatus(
      getFirstString(payloadMap, ["transactionstatus", "transactionStatus", "status"]) || undefined,
    );

    const providerEventId =
      getFirstString(payloadMap, [
        "transactionId",
        "transactionid",
        "transid",
        "reference",
        "fspReferenceId",
        "utilityref",
      ]) ||
      `${correlationId}:${newStatus}:${getFirstString(payloadMap, ["timestamp", "time"]) || Date.now()}`;

    const { error: webhookEventError } = await supabase
      .from("payment_webhook_events")
      .insert({
        provider: "azampay",
        provider_event_id: providerEventId,
        payment_id: payment.id,
        booking_id: payment.booking_id,
        webhook_status: newStatus,
        amount: callbackAmount,
        payload: payloadMap,
      });

    if (webhookEventError) {
      const code = (webhookEventError as { code?: string }).code;
      if (code === "23505") {
        await logPayment(correlationId, "info", "duplicate webhook event ignored", {
          providerEventId,
        });
        return new Response("OK", { status: 200 });
      }
      await logPayment(correlationId, "error", "payment_webhook_events insert failed", {
        webhookEventError,
        providerEventId,
      });
    }

    if (payment.status === "success" && newStatus === "success") {
      await logPayment(correlationId, "info", "duplicate success callback ignored");
      await supabase
        .from("payment_webhook_events")
        .update({ processed_at: new Date().toISOString() })
        .eq("provider", "azampay")
        .eq("provider_event_id", providerEventId);
      return new Response("OK", { status: 200 });
    }

    const { error: paymentUpdateError } = await supabase
      .from("payments")
      .update({
        status: newStatus,
        payment_gateway_ref: reference ?? fspReferenceId ?? null,
        amount_received: callbackAmount ?? payment.amount ?? null,
        failed_reason: newStatus === "failed" ? "Gateway reported failed status." : null,
      })
      .eq("id", payment.id);

    if (paymentUpdateError) {
      await logPayment(correlationId, "error", "payment update error", { paymentUpdateError });
    }

    if (newStatus === "failed") {
      await supabase
        .from("bookings")
        .update({
          payment_status: "failed",
        })
        .eq("id", payment.booking_id)
        .neq("payment_status", "completed");

      await supabase
        .from("payment_webhook_events")
        .update({ processed_at: new Date().toISOString() })
        .eq("provider", "azampay")
        .eq("provider_event_id", providerEventId);

      return new Response("OK", { status: 200 });
    }

    if (newStatus !== "success") {
      await supabase
        .from("payment_webhook_events")
        .update({ processed_at: new Date().toISOString() })
        .eq("provider", "azampay")
        .eq("provider_event_id", providerEventId);
      return new Response("OK", { status: 200 });
    }

    const bookingId = payment.booking_id;
    const { data: booking, error: bookingFetchError } = await supabase
      .from("bookings")
      .select("id,total_price,payment_status,amount_paid,currency")
      .eq("id", bookingId)
      .maybeSingle();

    if (bookingFetchError || !booking) {
      await logPayment(correlationId, "error", "booking fetch error", { bookingFetchError });
      return new Response("OK", { status: 200 });
    }

    const { data: successfulPayments, error: successfulPaymentsError } = await supabase
      .from("payments")
      .select("amount,amount_received")
      .eq("booking_id", bookingId)
      .eq("status", "success");

    if (successfulPaymentsError) {
      await logPayment(correlationId, "error", "failed to fetch successful payments", {
        successfulPaymentsError,
      });
      return new Response("OK", { status: 200 });
    }

    const totalPaid = (successfulPayments || []).reduce((sum, row) => {
      const amount = Number(row.amount_received ?? row.amount ?? 0);
      return Number.isFinite(amount) ? sum + amount : sum;
    }, 0);

    const bookingTotal = Number(booking.total_price ?? 0);
    const isFullyPaid = bookingTotal > 0 ? totalPaid + 0.0001 >= bookingTotal : totalPaid > 0;

    if (!isFullyPaid) {
      await supabase
        .from("bookings")
        .update({
          amount_paid: totalPaid,
          payment_status: "pending",
        })
        .eq("id", bookingId)
        .neq("payment_status", "completed");

      await logPayment(correlationId, "warn", "partial payment received", {
        bookingTotal,
        totalPaid,
      });

      await supabase
        .from("payment_webhook_events")
        .update({ processed_at: new Date().toISOString() })
        .eq("provider", "azampay")
        .eq("provider_event_id", providerEventId);

      return new Response("OK", { status: 200 });
    }

    const { error: bookingUpdateError } = await supabase
      .from("bookings")
      .update({
        payment_status: "completed",
        status: "confirmed",
        amount_paid: bookingTotal,
        payment_completed_at: new Date().toISOString(),
      })
      .eq("id", bookingId)
      .neq("payment_status", "completed");

    if (bookingUpdateError) {
      await logPayment(correlationId, "error", "booking update error", { bookingUpdateError });
    }

    const holdHoursRaw = Number(optionalEnv("SETTLEMENT_HOLD_HOURS", "24"));
    const holdHours = Number.isFinite(holdHoursRaw) ? Math.max(0, holdHoursRaw) : 24;
    const { data: settledCount, error: allocateError } = await supabase.rpc(
      "allocate_settlements_for_payment",
      {
        p_payment_id: payment.id,
        p_booking_id: bookingId,
        p_hold_hours: holdHours,
      },
    );

    if (allocateError) {
      await logPayment(correlationId, "error", "allocate_settlements_for_payment failed", {
        allocateError,
      });
    } else {
      await logPayment(correlationId, "info", "settlements allocated", {
        bookingId,
        settledCount,
      });
    }

    await supabase
      .from("payment_webhook_events")
      .update({ processed_at: new Date().toISOString() })
      .eq("provider", "azampay")
      .eq("provider_event_id", providerEventId);

    return new Response("OK", { status: 200 });
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: e.message }), { status: 500 });
  }
});
