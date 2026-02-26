import { serve } from "https://deno.land/std@0.223.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
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
  azamPayDisburseUrl: optionalEnv(
    "AZAMPAY_DISBURSE_URL",
    "https://api-disbursement-sandbox.azampay.co.tz/api/v1/azampay/disburse",
  ) as string,
  azamPayApiKey: optionalEnv("AZAMPAY_API_KEY"),
};

const supabase = createClient(
  config.supabaseUrl,
  config.supabaseServiceRoleKey,
);

async function getAzamPayToken() {
  const { data: tokenData } = await supabase
    .from("azampay_tokens")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (tokenData && new Date(tokenData.expires_at) > new Date()) {
    return tokenData.token as string;
  }

  const res = await fetch(config.azamPayAuthUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      appName: config.azamPayAppName,
      clientId: config.azamPayClientId,
      clientSecret: config.azamPayClientSecret,
    }),
  });

  if (!res.ok) throw new Error(`Failed to obtain AzamPay token (${res.status})`);

  const json = await res.json();
  const token = json?.data?.accessToken;
  const expiresIn = json?.data?.expiresIn || 3600;
  if (!token) throw new Error("AzamPay token missing from auth response");

  await supabase.from("azampay_tokens").insert({
    token,
    expires_at: new Date(Date.now() + expiresIn * 1000).toISOString(),
  });

  return token as string;
}

serve(async (req) => {
  try {
    const body = await req.json();
    const payoutBatchId = body.payout_batch_id?.toString();
    if (!payoutBatchId) {
      return new Response(JSON.stringify({ error: "Missing payout_batch_id" }), { status: 400 });
    }

    const { data: batch, error: batchError } = await supabase
      .from("payout_batches")
      .select("id,hotel_id,status,provider,currency,total_amount,provider_batch_ref")
      .eq("id", payoutBatchId)
      .maybeSingle();

    if (batchError || !batch) {
      return new Response(JSON.stringify({ error: "Payout batch not found" }), { status: 404 });
    }
    if (batch.status === "completed") {
      return new Response(JSON.stringify({ success: true, message: "Batch already completed" }), {
        status: 200,
      });
    }
    if (batch.status === "failed") {
      return new Response(JSON.stringify({ error: "Batch already failed" }), { status: 409 });
    }

    const { data: payoutAccount, error: accountError } = await supabase
      .from("hotel_payout_accounts")
      .select("*")
      .eq("hotel_id", batch.hotel_id)
      .eq("is_active", true)
      .maybeSingle();

    if (accountError || !payoutAccount) {
      await supabase.rpc("fail_payout_batch", {
        p_batch_id: batch.id,
        p_reason: "No active payout account configured for this hotel.",
      });
      return new Response(JSON.stringify({ error: "No active payout account for hotel" }), {
        status: 400,
      });
    }

    await supabase.rpc("mark_payout_batch_processing", {
      p_batch_id: batch.id,
      p_provider_batch_ref: batch.provider_batch_ref ?? null,
    });

    let providerBatchRef: string | null = null;

    if (batch.provider.toLowerCase().includes("azampay")) {
      const token = await getAzamPayToken();
      const endpoint = config.azamPayDisburseUrl;

      const disbursePayload = {
        destination: {
          countryCode: "TZ",
          fullName: payoutAccount.account_name || "Hotel Beneficiary",
          bankName: payoutAccount.provider_name,
          accountNumber: payoutAccount.account_number || payoutAccount.mobile_number,
          currency: batch.currency || "TZS",
        },
        transferDetails: {
          type: "INTERNAL",
          amount: Number(batch.total_amount),
          dateInEpoch: Date.now(),
        },
        additionalProperties: {
          payoutBatchId: batch.id,
          hotelId: batch.hotel_id,
        },
        externalReferenceId: `batch_${batch.id}_${Date.now()}`,
        remarks: `Hotel payout batch ${batch.id}`,
      };

      const disburseResp = await fetch(endpoint, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
          Accept: "application/json",
          ...(config.azamPayApiKey ? { "X-API-Key": config.azamPayApiKey } : {}),
        },
        body: JSON.stringify(disbursePayload),
      });

      const raw = await disburseResp.text();
      let parsed: Record<string, unknown> = {};
      try {
        parsed = raw ? JSON.parse(raw) : {};
      } catch {
        parsed = { raw };
      }

      if (!disburseResp.ok) {
        await supabase.rpc("fail_payout_batch", {
          p_batch_id: batch.id,
          p_reason: `Provider failed: ${JSON.stringify(parsed).slice(0, 250)}`,
        });
        return new Response(
          JSON.stringify({
            error: "Provider disbursement failed",
            status: disburseResp.status,
            details: parsed,
          }),
          { status: 502, headers: { "Content-Type": "application/json" } },
        );
      }

      providerBatchRef =
        (parsed.transactionId as string | undefined) ||
        (parsed.reference as string | undefined) ||
        (parsed.id as string | undefined) ||
        null;
    } else {
      await supabase.rpc("fail_payout_batch", {
        p_batch_id: batch.id,
        p_reason: `Unsupported payout provider: ${batch.provider}`,
      });
      return new Response(JSON.stringify({ error: "Unsupported payout provider" }), { status: 400 });
    }

    await supabase.rpc("complete_payout_batch", {
      p_batch_id: batch.id,
      p_provider_batch_ref: providerBatchRef,
    });

    return new Response(
      JSON.stringify({
        success: true,
        payoutBatchId: batch.id,
        providerBatchRef,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: (e as Error).message }), { status: 500 });
  }
});
