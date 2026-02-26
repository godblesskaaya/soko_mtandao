import { serve } from "https://deno.land/std@0.223.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL"),
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
);

type NativeMethod = "mno" | "bank";

function parsePositiveNumber(value: unknown): number | null {
  const n = Number(value);
  if (!Number.isFinite(n) || n <= 0) return null;
  return n;
}

async function getAzamPayToken() {
  const { data: tokenData } = await supabase
    .from("azampay_tokens")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (tokenData && new Date(tokenData.expires_at) > new Date()) {
    return tokenData.token;
  }

  const res = await fetch(
    "https://authenticator-sandbox.azampay.co.tz/AppRegistration/GenerateToken",
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        appName: Deno.env.get("AZAMPAY_APP_NAME"),
        clientId: Deno.env.get("AZAMPAY_CLIENT_ID"),
        clientSecret: Deno.env.get("AZAMPAY_CLIENT_SECRET"),
      }),
    },
  );

  const json = await res.json();
  const token = json?.data?.accessToken;
  const expiresIn = json?.data?.expiresIn || 3600;

  await supabase.from("azampay_tokens").insert({
    token,
    expires_at: new Date(Date.now() + expiresIn * 1000).toISOString(),
  });

  return token;
}

serve(async (req) => {
  try {
    const body = await req.json();
    const bookingId = body.booking_id?.toString();
    const method = (body.method?.toString().toLowerCase() || "mno") as NativeMethod;

    if (!bookingId) {
      return new Response(JSON.stringify({ error: "Missing booking_id" }), { status: 400 });
    }
    if (method !== "mno" && method !== "bank") {
      return new Response(JSON.stringify({ error: "Invalid method. Use 'mno' or 'bank'." }), {
        status: 400,
      });
    }

    const { data: booking, error: bookingError } = await supabase
      .from("bookings")
      .select("id,total_price,customer_name,customer_phone,payment_status,status,currency")
      .eq("id", bookingId)
      .maybeSingle();

    if (bookingError || !booking) {
      return new Response(JSON.stringify({ error: "Booking not found" }), { status: 404 });
    }
    if (booking.payment_status === "completed" || booking.status === "confirmed") {
      return new Response(JSON.stringify({ error: "Booking is already paid" }), { status: 409 });
    }

    const bookingTotal = parsePositiveNumber(booking.total_price);
    const amount = parsePositiveNumber(body.amount) ?? bookingTotal;
    if (amount == null) {
      return new Response(JSON.stringify({ error: "Invalid amount" }), { status: 400 });
    }
    if (bookingTotal != null && amount > bookingTotal) {
      return new Response(JSON.stringify({ error: "Amount exceeds booking total" }), { status: 400 });
    }
    const currency = (body.currency?.toString() || booking.currency?.toString() || "TZS").toUpperCase();
    if ((booking.currency?.toString() || "").toUpperCase() != currency) {
      await supabase.from("bookings").update({ currency }).eq("id", booking.id);
    }

    const token = await getAzamPayToken();
    const externalId = `booking_${booking.id}_${Date.now()}`;

    const apiBase = Deno.env.get("AZAMPAY_API_BASE_URL") || "https://sandbox.azampay.co.tz";
    const endpoint =
      method === "mno" ? `${apiBase}/azampay/mno/checkout` : `${apiBase}/azampay/bank/checkout`;

    let gatewayPayload: Record<string, unknown>;
    if (method === "mno") {
      const accountNumber = body.account_number?.toString();
      const provider = body.provider?.toString();
      if (!accountNumber || !provider) {
        return new Response(
          JSON.stringify({ error: "MNO requires account_number and provider" }),
          { status: 400 },
        );
      }

      gatewayPayload = {
        accountNumber,
        amount,
        currency,
        externalId,
        provider,
        additionalProperties: {
          bookingId: booking.id,
        },
      };
    } else {
      const provider = body.provider?.toString();
      const merchantAccountNumber = body.merchant_account_number?.toString();
      const merchantMobileNumber = body.merchant_mobile_number?.toString();
      const otp = body.otp?.toString();
      const merchantName =
        body.merchant_name?.toString() || booking.customer_name?.toString() || null;

      if (!provider || !merchantAccountNumber || !merchantMobileNumber || !otp) {
        return new Response(
          JSON.stringify({
            error:
              "Bank checkout requires provider, merchant_account_number, merchant_mobile_number and otp",
          }),
          { status: 400 },
        );
      }

      gatewayPayload = {
        amount,
        currencyCode: currency,
        merchantAccountNumber,
        merchantMobileNumber,
        merchantName,
        otp,
        provider,
        referenceId: externalId,
        additionalProperties: {
          bookingId: booking.id,
        },
      };
    }

    const headers: Record<string, string> = {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    };
    const apiKey = Deno.env.get("AZAMPAY_API_KEY");
    if (apiKey) headers["X-API-Key"] = apiKey;

    const gatewayResp = await fetch(endpoint, {
      method: "POST",
      headers,
      body: JSON.stringify(gatewayPayload),
    });

    const raw = await gatewayResp.text();
    let responsePayload: unknown = raw;
    try {
      responsePayload = raw ? JSON.parse(raw) : {};
    } catch {
      responsePayload = raw;
    }

    if (!gatewayResp.ok) {
      return new Response(
        JSON.stringify({
          error: "Native checkout failed",
          azamStatus: gatewayResp.status,
          details: responsePayload,
        }),
        { status: 502, headers: { "Content-Type": "application/json" } },
      );
    }

    const checkoutResponse = (responsePayload || {}) as Record<string, unknown>;
    const transactionId = checkoutResponse.transactionId?.toString() || null;
    const message = checkoutResponse.message?.toString() || "Payment initiated";
    const initiated = checkoutResponse.success !== false;

    const { data: existingPayment } = await supabase
      .from("payments")
      .select("id,status,retry_count")
      .eq("booking_id", booking.id)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    const paymentRecord = {
      booking_id: booking.id,
      external_id: externalId,
      amount,
      currency,
      status: "pending",
      type: method === "mno" ? "native_mno" : "native_bank",
      payment_gateway_ref: transactionId,
      retry_count: (existingPayment?.retry_count || 0) + 1,
      last_retry_at: new Date().toISOString(),
      idempotency_key: `native_${booking.id}_${Date.now()}`,
      azampay_response: responsePayload,
      metadata: {
        booking_id: booking.id,
        method,
        provider: body.provider ?? null,
        booking_total: booking.total_price,
        is_partial: bookingTotal != null ? amount < bookingTotal : false,
      },
    };

    if (existingPayment?.status === "pending") {
      const { error: updateError } = await supabase
        .from("payments")
        .update(paymentRecord)
        .eq("id", existingPayment.id);
      if (updateError) throw updateError;
    } else {
      const { error: insertError } = await supabase.from("payments").insert(paymentRecord);
      if (insertError) throw insertError;
    }

    return new Response(
      JSON.stringify({
        success: initiated,
        transactionId,
        message,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
