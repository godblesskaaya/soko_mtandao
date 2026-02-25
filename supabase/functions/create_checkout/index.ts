import { serve } from "https://deno.land/std@0.223.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL"),
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
);

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
    const { booking_id, redirectSuccessURL, redirectFailURL } = body;

    if (!booking_id) {
      return new Response(JSON.stringify({ error: "Missing booking_id" }), {
        status: 400,
      });
    }

    const { data: booking, error: bookingError } = await supabase
      .from("bookings")
      .select("id,total_price,customer_name,customer_phone,payment_status")
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

    // One active payment per booking: reuse existing pending checkout url.
    const { data: existingPayment } = await supabase
      .from("payments")
      .select("id,status,checkout_url")
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

    const token = await getAzamPayToken();
    const externalId = `booking_${booking.id}_${Date.now()}`;

    const payload = {
      amount: booking.total_price.toString(),
      appName: Deno.env.get("AZAMPAY_APP_NAME"),
      clientId: Deno.env.get("AZAMPAY_CLIENT_ID"),
      currency: "TZS",
      externalId,
      language: "en",
      redirectFailURL: redirectFailURL || "https://yourapp.com/payment-failed",
      redirectSuccessURL: redirectSuccessURL || "https://yourapp.com/payment-success",
      requestOrigin: Deno.env.get("AZAMPAY_REQUEST_ORIGIN") || "https://yourapp.com",
      cart: {
        booking_id: booking.id,
        customer_name: booking.customer_name,
        customer_phone: booking.customer_phone,
      },
    };

    const resp = await fetch("https://sandbox.azampay.co.tz/api/v1/Partner/PostCheckout", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    const raw = await resp.text();
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

    if (!resp.ok || !checkoutUrl) {
      return new Response(
        JSON.stringify({
          error: "Failed to create hosted checkout",
          details: azampayResponse,
        }),
        { status: 502 },
      );
    }

    const paymentRecord = {
      booking_id: booking.id,
      external_id: externalId,
      amount: booking.total_price,
      currency: "TZS",
      status: "pending",
      checkout_url: checkoutUrl,
      azampay_response: azampayResponse,
      metadata: {
        booking_id: booking.id,
        customer_name: booking.customer_name,
        customer_phone: booking.customer_phone,
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

    return new Response(JSON.stringify({ checkoutUrl }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: e.message }), { status: 500 });
  }
});
