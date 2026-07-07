import { serve } from "https://deno.land/std@0.223.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { AzamPayAuthError, getAzamPayToken } from "../_shared/azampay_auth.ts";
import { optionalEnv, requireEnv } from "../_shared/env.ts";

const config = {
  supabaseUrl: requireEnv("SUPABASE_URL"),
  supabaseServiceRoleKey: requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
  azamPayAppName: requireEnv("AZAMPAY_APP_NAME"),
  azamPayClientId: requireEnv("AZAMPAY_CLIENT_ID"),
  azamPayClientSecret: requireEnv("AZAMPAY_CLIENT_SECRET"),
  azamPayAuthUrl: optionalEnv(
    "AZAMPAY_AUTH_URL",
    "https://authenticator-sandbox.azampay.co.tz/AppRegistration/GenerateToken",
  ) as string,
  azamPayApiBaseUrl: optionalEnv(
    "AZAMPAY_API_BASE_URL",
    "https://sandbox.azampay.co.tz",
  ) as string,
};

const supabase = createClient(
  config.supabaseUrl,
  config.supabaseServiceRoleKey,
);

type NativeMethod = "mno" | "bank";

function parsePositiveNumber(value: unknown): number | null {
  const n = Number(value);
  if (!Number.isFinite(n) || n <= 0) return null;
  return n;
}

function normalizeTicket(value: unknown): string {
  return (value?.toString() || "").trim().toUpperCase();
}

function createAzamPayExternalId(): string {
  const time = Date.now().toString(36).toUpperCase();
  const random = crypto.randomUUID().replaceAll("-", "").slice(0, 18).toUpperCase();
  return `SM${time}${random}`.slice(0, 30);
}

function isObjectRecord(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === "object" && !Array.isArray(value);
}

async function resolveRequester(req: Request) {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) return null;
  const token = authHeader.replace("Bearer ", "").trim();
  if (!token) return null;

  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data?.user) return null;
  return data.user;
}

async function canAccessBooking(userId: string, hotelId: string | null, bookingUserId: string | null) {
  if (bookingUserId && bookingUserId === userId) return true;

  if (hotelId) {
    const { data: hotel } = await supabase
      .from("hotels")
      .select("manager_user_id")
      .eq("id", hotelId)
      .maybeSingle();
    if (hotel?.manager_user_id === userId) return true;
  }

  const { data: roleRow } = await supabase
    .from("user_roles_view")
    .select("role")
    .eq("user_id", userId)
    .maybeSingle();
  const role = (roleRow?.role || "").toString().toLowerCase();
  return role === "systemadmin" || role === "system_admin";
}

serve(async (req) => {
  try {
    const body = await req.json();
    const bookingId = body.booking_id?.toString();
    const ticketNumber = body.ticket_number?.toString();
    const action = body.action?.toString().toLowerCase() || "";
    const method = (body.method?.toString().toLowerCase() || "mno") as NativeMethod;
    const requester = await resolveRequester(req);

    if (!bookingId) {
      return new Response(JSON.stringify({ error: "Missing booking_id" }), { status: 400 });
    }
    if (action !== "generate_bank_otp" && method !== "mno" && method !== "bank") {
      return new Response(JSON.stringify({ error: "Invalid method. Use 'mno' or 'bank'." }), {
        status: 400,
      });
    }

    const { data: booking, error: bookingError } = await supabase
      .from("bookings")
      .select("id,hotel_id,user_id,ticket_number,total_price,customer_name,customer_phone,payment_status,status,currency")
      .eq("id", bookingId)
      .maybeSingle();

    if (bookingError || !booking) {
      return new Response(JSON.stringify({ error: "Booking not found" }), { status: 404 });
    }
    if (booking.payment_status === "completed" || booking.status === "confirmed") {
      return new Response(JSON.stringify({ error: "Booking is already paid" }), { status: 409 });
    }

    const ticketMatches =
      normalizeTicket(ticketNumber) !== "" &&
      normalizeTicket(ticketNumber) === normalizeTicket(booking.ticket_number);

    if (requester) {
      const { data: isFrozen } = await supabase.rpc("is_account_frozen", {
        p_user_id: requester.id,
      });
      if (isFrozen === true) {
        return new Response(JSON.stringify({ error: "Account is suspended." }), {
          status: 403,
        });
      }

      const allowed = await canAccessBooking(
        requester.id,
        booking.hotel_id?.toString() ?? null,
        booking.user_id?.toString() ?? null,
      );
      if (!allowed && !ticketMatches) {
        return new Response(JSON.stringify({ error: "Unauthorized booking access" }), {
          status: 403,
        });
      }
    } else {
      if (!ticketMatches) {
        return new Response(JSON.stringify({ error: "Invalid ticket number" }), {
          status: 403,
        });
      }
    }

    const token = await getAzamPayToken(supabase, config);
    const apiBase = config.azamPayApiBaseUrl;
    const headers: Record<string, string> = {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    };

    if (action === "generate_bank_otp") {
      const provider = body.provider?.toString().toUpperCase();
      if (provider !== "CRDB" && provider !== "NMB") {
        return new Response(JSON.stringify({ error: "OTP provider must be CRDB or NMB" }), {
          status: 400,
        });
      }

      const endpoint = `${apiBase}/azampay/bank/${provider === "CRDB" ? "otp" : "otp1"}`;
      const otpResp = await fetch(endpoint, {
        method: "POST",
        headers,
      });
      const raw = await otpResp.text();
      let responsePayload: unknown = raw;
      try {
        responsePayload = raw ? JSON.parse(raw) : {};
      } catch {
        responsePayload = raw;
      }

      if (!otpResp.ok) {
        return new Response(
          JSON.stringify({
            error: "Bank OTP generation failed",
            azamStatus: otpResp.status,
            details: responsePayload,
          }),
          { status: 502, headers: { "Content-Type": "application/json" } },
        );
      }

      return new Response(
        JSON.stringify({
          success: true,
          message: "OTP requested. Check the bank-registered mobile number.",
          provider,
          details: responsePayload,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    const bookingTotal = parsePositiveNumber(booking.total_price);
    const amount = parsePositiveNumber(body.amount) ?? bookingTotal;
    if (amount == null || bookingTotal == null) {
      return new Response(JSON.stringify({ error: "Invalid booking amount" }), { status: 400 });
    }
    if (Math.abs(amount - bookingTotal) > 0.0001) {
      return new Response(JSON.stringify({ error: "Amount must equal booking total" }), { status: 400 });
    }
    const currency = (body.currency?.toString() || booking.currency?.toString() || "TZS").toUpperCase();
    if ((booking.currency?.toString() || "").toUpperCase() != currency) {
      await supabase.from("bookings").update({ currency }).eq("id", booking.id);
    }

    const { data: existingPayment } = await supabase
      .from("payments")
      .select("id,status,retry_count,external_id")
      .eq("booking_id", booking.id)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    const externalId = existingPayment?.status === "pending" && existingPayment.external_id
      ? existingPayment.external_id.toString()
      : createAzamPayExternalId();

    const endpoint =
      method === "mno" ? `${apiBase}/azampay/mno/checkout` : `${apiBase}/azampay/bank/checkout`;

    let gatewayPayload: Record<string, unknown>;
    let provider: string | undefined;
    if (method === "mno") {
      const accountNumber = body.account_number?.toString();
      provider = body.provider?.toString();
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
      };
    } else {
      provider = body.provider?.toString();
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

    const paymentRecord = {
      booking_id: booking.id,
      external_id: externalId,
      amount,
      currency,
      status: "pending",
      type: method === "mno" ? "native_mno" : "native_bank",
      provider_status: "initiating",
      retry_count: (existingPayment?.retry_count || 0) + 1,
      last_retry_at: new Date().toISOString(),
      idempotency_key: `native_${booking.id}_${Date.now()}`,
      metadata: {
        booking_id: booking.id,
        method,
        provider,
        booking_total: booking.total_price,
        is_partial: false,
      },
    };

    let paymentId: string | null = existingPayment?.id ?? null;

    if (existingPayment?.status === "pending") {
      const { data: updatedPayment, error: updateError } = await supabase
        .from("payments")
        .update(paymentRecord)
        .eq("id", existingPayment.id)
        .select("id")
        .single();
      if (updateError) throw updateError;
      paymentId = updatedPayment?.id ?? paymentId;
    } else {
      const { data: insertedPayment, error: insertError } = await supabase
        .from("payments")
        .insert(paymentRecord)
        .select("id")
        .single();
      if (insertError) throw insertError;
      paymentId = insertedPayment?.id ?? null;
    }

    let gatewayResp: Response;
    try {
      gatewayResp = await fetch(endpoint, {
        method: "POST",
        headers,
        body: JSON.stringify(gatewayPayload),
      });
    } catch (error) {
      if (paymentId) {
        await supabase
          .from("payments")
          .update({
            status: "failed",
            provider_status: "request_failed",
            failed_reason: error instanceof Error ? error.message : "AzamPay request failed",
          })
          .eq("id", paymentId);
      }
      return new Response(
        JSON.stringify({
          error: "AzamPay native checkout request failed",
          details: error instanceof Error ? error.message : "Request failed",
        }),
        { status: 502, headers: { "Content-Type": "application/json" } },
      );
    }

    const raw = await gatewayResp.text();
    let responsePayload: unknown = raw;
    try {
      responsePayload = raw ? JSON.parse(raw) : {};
    } catch {
      responsePayload = raw;
    }

    if (!gatewayResp.ok) {
      if (paymentId) {
        await supabase
          .from("payments")
          .update({
            status: "failed",
            provider_status: "failed",
            failed_reason: "AzamPay native checkout failed",
            azampay_response: responsePayload,
          })
          .eq("id", paymentId);
      }
      return new Response(
        JSON.stringify({
          error: "Native checkout failed",
          azamStatus: gatewayResp.status,
          details: responsePayload,
        }),
        { status: 502, headers: { "Content-Type": "application/json" } },
      );
    }

    if (!isObjectRecord(responsePayload) || typeof responsePayload.success !== "boolean") {
      console.error("AzamPay native checkout returned an invalid success payload", {
        status: gatewayResp.status,
        statusText: gatewayResp.statusText,
        endpoint,
        raw,
        responsePayload,
      });
      if (paymentId) {
        await supabase
          .from("payments")
          .update({
            status: "failed",
            provider_status: "invalid_response",
            failed_reason: "AzamPay native checkout returned an invalid response",
            azampay_response: responsePayload,
          })
          .eq("id", paymentId);
      }
      return new Response(
        JSON.stringify({
          error: "Native checkout returned an invalid AzamPay response",
          azamStatus: gatewayResp.status,
          details: responsePayload,
        }),
        { status: 502, headers: { "Content-Type": "application/json" } },
      );
    }

    const checkoutResponse = responsePayload;
    const transactionId = checkoutResponse.transactionId?.toString() || null;
    const message = checkoutResponse.message?.toString() || "Payment initiated";
    const initiated = checkoutResponse.success === true;

    if (!initiated) {
      if (paymentId) {
        await supabase
          .from("payments")
          .update({
            status: "failed",
            provider_status: "not_initiated",
            failed_reason: message || "AzamPay native checkout was not initiated",
            azampay_response: responsePayload,
          })
          .eq("id", paymentId);
      }
      return new Response(
        JSON.stringify({
          error: message || "Native checkout was not initiated",
          azamStatus: gatewayResp.status,
          details: responsePayload,
        }),
        { status: 502, headers: { "Content-Type": "application/json" } },
      );
    }

    if (paymentId) {
      const { error: paymentUpdateError } = await supabase
        .from("payments")
        .update({
          payment_gateway_ref: transactionId,
          provider_status: "initiated",
          azampay_response: responsePayload,
          failed_reason: null,
        })
        .eq("id", paymentId);
      if (paymentUpdateError) throw paymentUpdateError;
    }

    const { error: lifecycleError } = await supabase.rpc("mark_booking_payment_initiated", {
      p_booking_id: booking.id,
      p_payment_id: paymentId,
      p_grace_minutes: 15,
    });
    if (lifecycleError) {
      console.error("mark_booking_payment_initiated failed", { lifecycleError, bookingId: booking.id });
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
    if (e instanceof AzamPayAuthError) {
      return new Response(
        JSON.stringify({
          error: e.message,
          azamStatus: e.status,
          azamStatusText: e.statusText,
          details: e.details,
        }),
        { status: 502, headers: { "Content-Type": "application/json" } },
      );
    }
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
