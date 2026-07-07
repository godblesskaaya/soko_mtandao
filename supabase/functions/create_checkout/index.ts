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
  azamPayVendorId: requireEnv("AZAMPAY_VENDOR_ID"),
  azamPayVendorName: requireEnv("AZAMPAY_VENDOR_NAME"),
  appOrigin: optionalEnv("ORIGIN", "https://yourapp.com") as string,
};

const supabase = createClient(
  config.supabaseUrl,
  config.supabaseServiceRoleKey,
);

function isHttpUrl(value: unknown): value is string {
  if (typeof value !== "string" || value.trim().length === 0) return false;
  try {
    const u = new URL(value);
    return u.protocol === "http:" || u.protocol === "https:";
  } catch {
    return false;
  }
}

function resolveHttpOrigin(value: unknown): string {
  if (!isHttpUrl(value)) return "https://yourapp.com";
  return new URL(value).origin;
}

function trimTrailingSlashes(value: string): string {
  return value.replace(/\/+$/, "");
}

function normalizeTicket(value: unknown): string {
  return (value?.toString() || "").trim().toUpperCase();
}

function createAzamPayExternalId(): string {
  const time = Date.now().toString(36).toUpperCase();
  const random = crypto.randomUUID().replaceAll("-", "").slice(0, 18).toUpperCase();
  return `SM${time}${random}`.slice(0, 30);
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
    const { booking_id, redirectSuccessURL, redirectFailURL, ticket_number } = body;
    const requester = await resolveRequester(req);

    if (!booking_id) {
      return new Response(JSON.stringify({ error: "Missing booking_id" }), {
        status: 400,
      });
    }

    const { data: booking, error: bookingError } = await supabase
      .from("bookings")
      .select("id,hotel_id,user_id,ticket_number,total_price,customer_name,customer_phone,payment_status,currency")
      .eq("id", booking_id)
      .maybeSingle();

    if (bookingError || !booking) {
      return new Response(JSON.stringify({ error: "Booking not found" }), {
        status: 404,
      });
    }

    if (booking.payment_status === "completed") {
      return new Response(JSON.stringify({ error: "Booking is already paid" }), {
        status: 409,
      });
    }

    const ticketMatches =
      normalizeTicket(ticket_number) !== "" &&
      normalizeTicket(ticket_number) === normalizeTicket(booking.ticket_number);

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

    const currency = (body.currency?.toString() || booking.currency || "TZS").toUpperCase();
    if ((booking.currency || "").toString().toUpperCase() !== currency) {
      await supabase.from("bookings").update({ currency }).eq("id", booking.id);
    }

    // One active payment per booking: reuse existing pending checkout url.
    const { data: existingPayment } = await supabase
      .from("payments")
      .select("id,status,checkout_url,retry_count,external_id")
      .eq("booking_id", booking.id)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (existingPayment?.status === "pending" && existingPayment.checkout_url) {
      return new Response(JSON.stringify({ checkoutUrl: existingPayment.checkout_url }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const token = await getAzamPayToken(supabase, config);
    const externalId = existingPayment?.status === "pending" && existingPayment.external_id
      ? existingPayment.external_id.toString()
      : createAzamPayExternalId();

    const appOrigin = resolveHttpOrigin(config.appOrigin);
    const fallbackSuccessUrl = `${appOrigin}/payment-success`;
    const fallbackFailUrl = `${appOrigin}/payment-failed`;

    // AzamPay expects web URLs. Ignore custom deep-link schemes from mobile clients.
    const safeRedirectSuccessURL = isHttpUrl(redirectSuccessURL)
      ? redirectSuccessURL
      : fallbackSuccessUrl;
    const safeRedirectFailURL = isHttpUrl(redirectFailURL)
      ? redirectFailURL
      : fallbackFailUrl;

    const requestOrigin = new URL(safeRedirectSuccessURL).origin;

    const payload: Record<string, unknown> = {
      amount: booking.total_price.toString(),
      appName: config.azamPayAppName,
      clientId: config.azamPayClientId,
      currency,
      externalId,
      language: "en",
      redirectFailURL: safeRedirectFailURL,
      redirectSuccessURL: safeRedirectSuccessURL,
      requestOrigin,
      vendorId: config.azamPayVendorId,
      vendorName: config.azamPayVendorName,
      cart: {
        // Keep shape aligned to AzamPay PostCheckoutRequest.cart contract.
        items: [
          {
            name: `Booking ${booking.id}`,
          },
        ],
      },
    };

    const checkoutEndpoint = `${trimTrailingSlashes(config.azamPayApiBaseUrl)}/api/v1/Partner/PostCheckout`;

    const paymentRecord = {
      booking_id: booking.id,
      external_id: externalId,
      amount: booking.total_price,
      currency,
      status: "pending",
      type: "hosted_checkout",
      provider_status: "initiating",
      retry_count: (existingPayment?.retry_count || 0) + 1,
      last_retry_at: new Date().toISOString(),
      idempotency_key: `checkout_${booking.id}_${Date.now()}`,
      metadata: {
        booking_id: booking.id,
        customer_name: booking.customer_name,
        customer_phone: booking.customer_phone,
        retry: (existingPayment?.retry_count || 0) + 1,
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

    let resp: Response;
    try {
      resp = await fetch(checkoutEndpoint, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
          Accept: "application/json, text/plain, text/json",
        },
        body: JSON.stringify(payload),
      });
    } catch (error) {
      if (paymentId) {
        await supabase
          .from("payments")
          .update({
            status: "failed",
            provider_status: "request_failed",
            failed_reason: error instanceof Error ? error.message : "AzamPay hosted checkout request failed",
          })
          .eq("id", paymentId);
      }
      return new Response(
        JSON.stringify({
          error: "AzamPay hosted checkout request failed",
          details: error instanceof Error ? error.message : "Request failed",
        }),
        { status: 502, headers: { "Content-Type": "application/json" } },
      );
    }

    const raw = await resp.text();
    const locationHeader = resp.headers.get("location");
    let checkoutUrl = "";
    let azampayResponse: unknown = raw;

    try {
      const parsed = JSON.parse(raw);
      azampayResponse = parsed;
      if (typeof parsed === "string") {
        checkoutUrl = parsed;
      } else if (parsed && typeof parsed === "object") {
        checkoutUrl = parsed.checkoutUrl || parsed.url || parsed.redirectUrl || "";
      }
    } catch {
      checkoutUrl = raw.replace(/^"|"$/g, "");
    }

    // Some gateways respond 200 with empty body and provide URL in headers/redirect.
    if (!checkoutUrl && locationHeader && isHttpUrl(locationHeader)) {
      checkoutUrl = locationHeader;
    }
    if (!checkoutUrl && resp.redirected && isHttpUrl(resp.url)) {
      checkoutUrl = resp.url;
    }

    if (!resp.ok || !checkoutUrl) {
      console.error("AzamPay checkout creation failed", {
        status: resp.status,
        statusText: resp.statusText,
        contentType: resp.headers.get("content-type"),
        locationHeader,
        redirected: resp.redirected,
        responseUrl: resp.url,
        raw,
      });
      if (paymentId) {
        await supabase
          .from("payments")
          .update({
            status: "failed",
            provider_status: resp.ok ? "invalid_response" : "failed",
            failed_reason: resp.ok
              ? "AzamPay hosted checkout returned no checkout URL"
              : "AzamPay hosted checkout failed",
            azampay_response: azampayResponse,
          })
          .eq("id", paymentId);
      }
      return new Response(
        JSON.stringify({
          error: "Failed to create hosted checkout",
          azamStatus: resp.status,
          azamStatusText: resp.statusText,
          contentType: resp.headers.get("content-type"),
          locationHeader,
          redirected: resp.redirected,
          responseUrl: resp.url,
          details: azampayResponse,
        }),
        { status: 502, headers: { "Content-Type": "application/json" } },
      );
    }

    if (paymentId) {
      const { error: paymentUpdateError } = await supabase
        .from("payments")
        .update({
          checkout_url: checkoutUrl,
          provider_status: "initiated",
          azampay_response: azampayResponse,
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

    return new Response(JSON.stringify({ checkoutUrl }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
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
    return new Response(JSON.stringify({ error: e.message }), { status: 500 });
  }
});
