import { serve } from "https://deno.land/std@0.223.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { requireEnv } from "../_shared/env.ts";

const supabase = createClient(
  requireEnv("SUPABASE_URL"),
  requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
);

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

function sanitizeCallbackPayload(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sanitizeCallbackPayload);
  if (!value || typeof value !== "object") return value;

  const sanitized: Record<string, unknown> = {};
  for (const [key, item] of Object.entries(value)) {
    sanitized[key] = /password|signature|token|secret|key/i.test(key)
      ? "[redacted]"
      : sanitizeCallbackPayload(item);
  }
  return sanitized;
}

function normalizePayoutStatus(raw: string | null): "success" | "failed" | "pending" {
  const status = (raw || "").trim().toLowerCase();
  if (["success", "successful", "completed", "complete", "paid"].includes(status)) return "success";
  if (["failed", "failure", "rejected", "cancelled", "canceled"].includes(status)) return "failed";
  return "pending";
}

async function logAudit(
  eventType: string,
  payoutBatchId: string,
  payload: Record<string, unknown>,
) {
  try {
    await supabase.rpc("log_audit_event", {
      p_event_type: eventType,
      p_entity_type: "payout_batch",
      p_entity_id: payoutBatchId,
      p_payload: payload,
    });
  } catch (_) {
    // Best effort only.
  }
}

serve(async (req) => {
  try {
    const payload = await req.json();
    const payloadMap = payload as Record<string, unknown>;
    const sanitizedPayload = sanitizeCallbackPayload(payloadMap);

    const externalReference = getFirstString(payloadMap, [
      "initiatorReferenceId",
      "initiatorreferenceid",
      "externalReferenceId",
      "externalreferenceid",
    ]);
    const providerReference = getFirstString(payloadMap, [
      "pgReferenceId",
      "pgreferenceid",
      "fspReferenceId",
      "fspreferenceid",
      "reference",
      "transactionId",
      "transactionid",
    ]);
    const status = normalizePayoutStatus(getFirstString(payloadMap, ["status", "transactionStatus"]));
    const amountRaw = Number(getFirstString(payloadMap, ["amount"]));
    const amount = Number.isFinite(amountRaw) && amountRaw > 0 ? amountRaw : null;
    const providerEventId =
      providerReference ||
      externalReference ||
      `${status}:${getFirstString(payloadMap, ["timestamp", "time"]) || Date.now()}`;

    let batch: { id: string; status: string } | null = null;

    if (externalReference) {
      const { data } = await supabase
        .from("payout_batches")
        .select("id,status")
        .eq("provider_external_reference", externalReference)
        .maybeSingle();
      if (data) batch = data;
    }

    if (!batch && providerReference) {
      const { data } = await supabase
        .from("payout_batches")
        .select("id,status")
        .eq("provider_batch_ref", providerReference)
        .maybeSingle();
      if (data) batch = data;
    }

    if (!batch && providerReference) {
      const { data } = await supabase
        .from("payout_batches")
        .select("id,status")
        .eq("provider_reference", providerReference)
        .maybeSingle();
      if (data) batch = data;
    }

    const { error: eventError } = await supabase.from("payout_provider_events").insert({
      provider: "azampay",
      provider_event_id: providerEventId,
      payout_batch_id: batch?.id ?? null,
      status,
      amount,
      payload: sanitizedPayload,
    });

    if (eventError) {
      const code = (eventError as { code?: string }).code;
      if (code === "23505") {
        return new Response("OK", { status: 200 });
      }
      console.error("payout_provider_events insert failed", { eventError, providerEventId });
    }

    if (!batch) {
      console.error("payout callback could not be matched to a batch", {
        externalReference,
        providerReference,
        providerEventId,
      });
      return new Response("OK", { status: 200 });
    }

    if (status === "success") {
      const { error } = await supabase.rpc("complete_payout_batch", {
        p_batch_id: batch.id,
        p_provider_batch_ref: providerReference,
      });
      if (error) {
        console.error("complete_payout_batch failed", { error, batchId: batch.id });
      } else {
        await logAudit("payout_provider_completed", batch.id, {
          provider: "azampay",
          provider_event_id: providerEventId,
          provider_reference: providerReference,
          external_reference: externalReference,
        });
      }
    } else if (status === "failed") {
      const { error } = await supabase.rpc("fail_payout_batch", {
        p_batch_id: batch.id,
        p_reason: `Provider failed payout: ${JSON.stringify(sanitizedPayload).slice(0, 250)}`,
      });
      if (error) {
        console.error("fail_payout_batch failed", { error, batchId: batch.id });
      } else {
        await logAudit("payout_provider_failed", batch.id, {
          provider: "azampay",
          provider_event_id: providerEventId,
          provider_reference: providerReference,
          external_reference: externalReference,
        });
      }
    }

    await supabase
      .from("payout_provider_events")
      .update({ processed_at: new Date().toISOString() })
      .eq("provider", "azampay")
      .eq("provider_event_id", providerEventId);

    return new Response("OK", { status: 200 });
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: (e as Error).message }), { status: 500 });
  }
});
