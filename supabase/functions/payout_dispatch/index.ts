import { serve } from "https://deno.land/std@0.223.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { AzamPayAuthError, getAzamPayToken } from "../_shared/azampay_auth.ts";
import { optionalConfiguredEnv, optionalEnv, requireEnv } from "../_shared/env.ts";

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
  azamPayDisburseTransferType: optionalConfiguredEnv("AZAMPAY_DISBURSE_TRANSFER_TYPE", "INTERNAL") as string,
};

const supabase = createClient(
  config.supabaseUrl,
  config.supabaseServiceRoleKey,
);

const azamPayDisbursementProviders = new Set(["tigo", "airtel", "azampesa"]);

type PayoutAccount = {
  provider_type: string | null;
  provider_name: string | null;
  account_name: string | null;
  account_number: string | null;
  mobile_number: string | null;
  currency: string | null;
  country_code: string | null;
  verification_status: string | null;
};

async function resolveRequester(req: Request) {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) return null;
  const token = authHeader.replace("Bearer ", "").trim();
  if (!token) return null;

  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data?.user) return null;
  return data.user;
}

async function canDispatchForHotel(userId: string, hotelId: string) {
  const { data: hotel } = await supabase
    .from("hotels")
    .select("manager_user_id")
    .eq("id", hotelId)
    .maybeSingle();
  if (hotel?.manager_user_id === userId) return true;

  const { data: roleRow } = await supabase
    .from("user_roles_view")
    .select("role")
    .eq("user_id", userId)
    .maybeSingle();
  const role = (roleRow?.role || "").toString().toLowerCase();
  return role === "systemadmin" || role === "system_admin";
}

function normalizeAzamPayDisbursementProvider(value: string | null | undefined): string | null {
  const normalized = (value || "").trim().toLowerCase();
  if (!azamPayDisbursementProviders.has(normalized)) return null;
  return normalized;
}

function getDisbursementSourceConfig(currency: string | null): {
  countryCode: string;
  fullName: string;
  bankName: string;
  accountNumber: string;
  currency: string;
} | null {
  const fullName = optionalConfiguredEnv("AZAMPAY_DISBURSE_SOURCE_FULL_NAME");
  const bankName = normalizeAzamPayDisbursementProvider(
    optionalConfiguredEnv("AZAMPAY_DISBURSE_SOURCE_BANK_NAME"),
  );
  const accountNumber = optionalConfiguredEnv("AZAMPAY_DISBURSE_SOURCE_ACCOUNT_NUMBER");

  if (!fullName || !bankName || !accountNumber) return null;

  return {
    countryCode: optionalConfiguredEnv("AZAMPAY_DISBURSE_SOURCE_COUNTRY_CODE", "TZ") as string,
    fullName,
    bankName,
    accountNumber,
    currency: optionalConfiguredEnv("AZAMPAY_DISBURSE_SOURCE_CURRENCY", currency || "TZS") as string,
  };
}

async function logAudit(
  eventType: string,
  actorUserId: string,
  payoutBatchId: string,
  payload: Record<string, unknown>,
) {
  try {
    await supabase.rpc("log_audit_event", {
      p_event_type: eventType,
      p_entity_type: "payout_batch",
      p_entity_id: payoutBatchId,
      p_payload: payload,
      p_actor_user_id: actorUserId,
    });
  } catch (_) {
    // Best effort only.
  }
}

function validateDestinationAccount(payoutAccount: PayoutAccount, batchCurrency: string | null) {
  const missing: string[] = [];
  const providerType = (payoutAccount.provider_type || "").toLowerCase();
  const bankName = normalizeAzamPayDisbursementProvider(payoutAccount.provider_name);
  const accountNumber = payoutAccount.mobile_number;

  if ((payoutAccount.verification_status || "").toLowerCase() !== "approved") {
    missing.push("approved payout account");
  }
  if (providerType !== "mobile_money") missing.push("mobile money payout account");
  if (!payoutAccount.account_name?.trim()) missing.push("account holder name");
  if (!bankName) missing.push("provider must be tigo, airtel, or azampesa");
  if (!accountNumber?.trim()) missing.push("mobile wallet number");
  if (!/^[A-Z]{2}$/.test((payoutAccount.country_code || "").trim().toUpperCase())) {
    missing.push("country code");
  }
  if (!/^[A-Z]{3}$/.test((payoutAccount.currency || batchCurrency || "").trim().toUpperCase())) {
    missing.push("currency");
  }

  if (missing.length > 0) {
    return { ok: false as const, reason: `Payout destination is incomplete: ${missing.join(", ")}` };
  }

  return {
    ok: true as const,
    destination: {
      countryCode: (payoutAccount.country_code || "TZ").trim().toUpperCase(),
      fullName: payoutAccount.account_name!.trim(),
      bankName: bankName!,
      accountNumber: accountNumber!.trim(),
      currency: (payoutAccount.currency || batchCurrency || "TZS").trim().toUpperCase(),
    },
  };
}

serve(async (req) => {
  try {
    const requester = await resolveRequester(req);
    if (!requester) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
    }

    const { data: isFrozen } = await supabase.rpc("is_account_frozen", {
      p_user_id: requester.id,
    });
    if (isFrozen === true) {
      return new Response(JSON.stringify({ error: "Account is suspended." }), {
        status: 403,
      });
    }

    const body = await req.json();
    const payoutBatchId = body.payout_batch_id?.toString();
    if (!payoutBatchId) {
      return new Response(JSON.stringify({ error: "Missing payout_batch_id" }), { status: 400 });
    }

    const { data: batch, error: batchError } = await supabase
      .from("payout_batches")
      .select("id,hotel_id,status,provider,currency,total_amount,provider_batch_ref,provider_external_reference")
      .eq("id", payoutBatchId)
      .maybeSingle();

    if (batchError || !batch) {
      return new Response(JSON.stringify({ error: "Payout batch not found" }), { status: 404 });
    }

    const allowed = await canDispatchForHotel(requester.id, batch.hotel_id.toString());
    if (!allowed) {
      return new Response(JSON.stringify({ error: "Forbidden" }), { status: 403 });
    }

    if (batch.status === "completed") {
      return new Response(JSON.stringify({ success: true, message: "Batch already completed" }), {
        status: 200,
      });
    }
    if (batch.status === "provider_pending" || batch.status === "processing") {
      return new Response(
        JSON.stringify({
          success: true,
          message: "Batch already submitted to provider",
          providerBatchRef: batch.provider_batch_ref ?? null,
          providerExternalReference: batch.provider_external_reference ?? null,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }
    if (batch.status === "failed") {
      return new Response(JSON.stringify({ error: "Batch already failed" }), { status: 409 });
    }

    const { data: payoutAccount, error: accountError } = await supabase
      .from("hotel_payout_accounts")
      .select("provider_type,provider_name,account_name,account_number,mobile_number,currency,country_code,verification_status")
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

    const destinationResult = validateDestinationAccount(
      payoutAccount as PayoutAccount,
      batch.currency || "TZS",
    );
    if (!destinationResult.ok) {
      await supabase.rpc("fail_payout_batch", {
        p_batch_id: batch.id,
        p_reason: destinationResult.reason,
      });
      return new Response(JSON.stringify({ error: destinationResult.reason }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const sourceConfig = getDisbursementSourceConfig(batch.currency || "TZS");
    if (!sourceConfig) {
      return new Response(
        JSON.stringify({
          error:
            "AzamPay disbursement source account is not configured. Set AZAMPAY_DISBURSE_SOURCE_* secrets.",
        }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    const { data: transitionOk, error: transitionError } = await supabase.rpc("mark_payout_batch_processing", {
      p_batch_id: batch.id,
      p_provider_batch_ref: batch.provider_batch_ref ?? null,
    });
    if (transitionError) throw transitionError;
    if (transitionOk !== true) {
      return new Response(
        JSON.stringify({ error: "Batch is not dispatchable from its current state" }),
        { status: 409, headers: { "Content-Type": "application/json" } },
      );
    }

    let providerBatchRef: string | null = null;
    let providerResponse: Record<string, unknown> = {};
    const providerExternalReference =
      batch.provider_external_reference ||
      `SM${batch.id.replaceAll("-", "").slice(0, 28)}`;

    if (batch.provider.toLowerCase().includes("azampay")) {
      const token = await getAzamPayToken(supabase, config);
      const endpoint = config.azamPayDisburseUrl;

      const disbursePayload = {
        source: sourceConfig,
        destination: destinationResult.destination,
        transferDetails: {
          type: config.azamPayDisburseTransferType,
          amount: Number(batch.total_amount),
          dateInEpoch: Date.now(),
        },
        additionalProperties: {
          payoutBatchId: batch.id,
          hotelId: batch.hotel_id,
        },
        externalReferenceId: providerExternalReference,
        remarks: `Hotel payout batch ${batch.id}`,
      };

      const disburseResp = await fetch(endpoint, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
          Accept: "application/json",
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
      providerResponse = parsed;

      if (!disburseResp.ok) {
        await logAudit("payout_dispatch", requester.id, batch.id, {
          outcome: "failed",
          provider: batch.provider,
          provider_status: disburseResp.status,
        });
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
        (parsed.pgReferenceId as string | undefined) ||
        (parsed.pgreferenceid as string | undefined) ||
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

    await supabase.rpc("mark_payout_batch_submitted", {
      p_batch_id: batch.id,
      p_provider_batch_ref: providerBatchRef,
      p_provider_external_reference: providerExternalReference,
      p_provider_response: providerResponse,
    });

    await logAudit("payout_dispatch", requester.id, batch.id, {
      outcome: "provider_pending",
      provider: batch.provider,
      provider_batch_ref: providerBatchRef,
      provider_external_reference: providerExternalReference,
      total_amount: batch.total_amount,
    });

    return new Response(
      JSON.stringify({
        success: true,
        payoutBatchId: batch.id,
        status: "provider_pending",
        providerBatchRef,
        providerExternalReference,
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
    return new Response(JSON.stringify({ error: (e as Error).message }), { status: 500 });
  }
});
