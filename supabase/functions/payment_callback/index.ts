import { serve } from "https://deno.land/std@0.223.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { optionalConfiguredEnv, optionalEnv, requireEnv } from "../_shared/env.ts";

const supabase = createClient(
  requireEnv("SUPABASE_URL"),
  requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
);
const callbackPassword = optionalConfiguredEnv("AZAMPAY_CALLBACK_PASSWORD");
const callbackUser = optionalConfiguredEnv("AZAMPAY_CALLBACK_USER");
const callbackClientId = optionalEnv("AZAMPAY_CLIENT_ID");
const callbackPublicKeyPem = optionalConfiguredEnv("AZAMPAY_CALLBACK_PUBLIC_KEY_PEM");

function timingSafeEqual(a: string, b: string): boolean {
  const left = new TextEncoder().encode(a);
  const right = new TextEncoder().encode(b);
  if (left.length !== right.length) return false;

  let diff = 0;
  for (let i = 0; i < left.length; i++) {
    diff |= left[i] ^ right[i];
  }
  return diff === 0;
}

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

async function logPaymentStateChange(
  paymentId: string,
  bookingId: string,
  status: string,
  payload: Record<string, unknown>,
) {
  try {
    await supabase.rpc("log_audit_event", {
      p_event_type: "payment_state_changed",
      p_entity_type: "payment",
      p_entity_id: paymentId,
      p_payload: {
        booking_id: bookingId,
        status,
        ...payload,
      },
    });
  } catch (_) {
    // Best effort only.
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

function hasValidCallbackCredentials(payload: Record<string, unknown>): boolean {
  if (!callbackPassword) return false;

  const suppliedPassword = getFirstString(payload, ["password"]);
  if (!suppliedPassword || !timingSafeEqual(suppliedPassword, callbackPassword)) {
    return false;
  }

  const suppliedClientId = getFirstString(payload, ["clientId", "clientid"]);
  if (
    callbackClientId &&
    (!suppliedClientId || !timingSafeEqual(suppliedClientId, callbackClientId))
  ) {
    return false;
  }

  const suppliedUser = getFirstString(payload, ["user"]);
  if (callbackUser && (!suppliedUser || !timingSafeEqual(suppliedUser, callbackUser))) {
    return false;
  }

  return true;
}

function describeCallbackAuth(payload: Record<string, unknown>): Record<string, unknown> {
  const suppliedPassword = getFirstString(payload, ["password"]);
  const suppliedClientId = getFirstString(payload, ["clientId", "clientid"]);
  const suppliedUser = getFirstString(payload, ["user"]);
  const suppliedSignature = getFirstString(payload, ["signature"]);

  return {
    configured: {
      password: !!callbackPassword,
      user: !!callbackUser,
      clientId: !!callbackClientId,
      publicKey: !!callbackPublicKeyPem,
    },
    supplied: {
      password: !!suppliedPassword,
      user: !!suppliedUser,
      clientId: !!suppliedClientId,
      signature: !!suppliedSignature,
    },
    matched: {
      password: !!callbackPassword && !!suppliedPassword &&
        timingSafeEqual(suppliedPassword, callbackPassword),
      user: !callbackUser || (!!suppliedUser && timingSafeEqual(suppliedUser, callbackUser)),
      clientId: !callbackClientId ||
        (!!suppliedClientId && timingSafeEqual(suppliedClientId, callbackClientId)),
    },
  };
}

function base64ToBytes(value: string): Uint8Array {
  const binary = atob(value.replace(/\s+/g, ""));
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function pemToDer(pem: string): Uint8Array {
  const normalized = pem.replace(/\\n/g, "\n");
  const base64 = normalized
    .replace(/-----BEGIN PUBLIC KEY-----/g, "")
    .replace(/-----END PUBLIC KEY-----/g, "")
    .replace(/\s+/g, "");
  return base64ToBytes(base64);
}

async function hasValidCallbackSignature(payload: Record<string, unknown>): Promise<boolean> {
  if (!callbackPublicKeyPem) return false;

  const signature = getFirstString(payload, ["signature"]);
  const utilityref = getFirstString(payload, ["utilityref", "utilityRef"]) || "";
  const externalreference =
    getFirstString(payload, ["externalreference", "externalReference"]) || "";
  const transactionstatus =
    getFirstString(payload, ["transactionstatus", "transactionStatus", "status"]) || "";
  const operator = getFirstString(payload, ["operator"]) || "";
  if (!signature || (!utilityref && !externalreference)) return false;

  try {
    const publicKey = pemToDer(callbackPublicKeyPem);
    const signatureBytes = base64ToBytes(signature);
    const attempts = [
      {
        hash: "SHA-256",
        payload: `${utilityref}${externalreference}${transactionstatus}${operator}`,
      },
      {
        hash: "SHA-256",
        payload: `${utilityref}${externalreference}`,
      },
      {
        hash: "SHA-512",
        payload: `${utilityref}${externalreference}`,
      },
    ];

    for (const attempt of attempts) {
      const key = await crypto.subtle.importKey(
        "spki",
        publicKey,
        {
          name: "RSASSA-PKCS1-v1_5",
          hash: attempt.hash,
        },
        false,
        ["verify"],
      );
      const valid = await crypto.subtle.verify(
        "RSASSA-PKCS1-v1_5",
        key,
        signatureBytes,
        new TextEncoder().encode(attempt.payload),
      );
      if (valid) return true;
    }
    return false;
  } catch (error) {
    console.error("AzamPay callback signature verification failed", { error });
    return false;
  }
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
  if (["failed", "failure", "rejected", "cancelled", "canceled"].includes(status)) return "failed";
  return "pending";
}

type CallbackPayment = {
  id: string;
  booking_id: string;
  status: string;
  amount: number | null;
};

function amountMatchesPayment(payment: CallbackPayment, callbackAmount: number | null): boolean {
  const expectedAmount = Number(payment.amount ?? 0);
  if (!callbackAmount || !Number.isFinite(expectedAmount) || expectedAmount <= 0) return false;
  return Math.abs(callbackAmount - expectedAmount) <= 0.0001;
}

async function findPaymentForCallback(
  paymentIdCandidates: string[],
  bookingIdFromPayload: string | null,
): Promise<CallbackPayment | null> {
  for (const candidate of paymentIdCandidates) {
    const { data } = await supabase
      .from("payments")
      .select("id,booking_id,status,amount")
      .eq("external_id", candidate)
      .maybeSingle();
    if (data) return data;
  }

  for (const candidate of paymentIdCandidates) {
    const { data } = await supabase
      .from("payments")
      .select("id,booking_id,status,amount")
      .eq("payment_gateway_ref", candidate)
      .maybeSingle();
    if (data) return data;
  }

  if (bookingIdFromPayload) {
    const { data } = await supabase
      .from("payments")
      .select("id,booking_id,status,amount")
      .eq("booking_id", bookingIdFromPayload)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (data) return data;
  }

  return null;
}

serve(async (req) => {
  try {
    const payload = await req.json();
    const payloadMap = payload as Record<string, unknown>;
    const sanitizedPayload = sanitizeCallbackPayload(payloadMap);

    const utilityref = getFirstString(payloadMap, ["utilityref", "utilityRef"]);
    const reference = getFirstString(payloadMap, ["reference", "transid", "txnReferenceNumber"]);
    const externalreference = getFirstString(payloadMap, ["externalreference", "externalReference"]);
    const fspReferenceId = getFirstString(payloadMap, ["fspReferenceId", "fspreferenceid"]);
    const bookingIdFromPayload = extractBookingId(payloadMap);

    const paymentIdCandidates = [utilityref, externalreference, reference, fspReferenceId].filter(
      (v): v is string => !!v && v.trim().length > 0,
    );

    const correlationId = paymentIdCandidates[0] || bookingIdFromPayload || "unknown";
    const callbackAmountRaw = Number(getFirstString(payloadMap, ["amount"]));
    const callbackAmount =
      Number.isFinite(callbackAmountRaw) && callbackAmountRaw > 0 ? callbackAmountRaw : null;

    let payment = await findPaymentForCallback(paymentIdCandidates, bookingIdFromPayload);
    const credentialsAuthorized = hasValidCallbackCredentials(payloadMap);
    const signatureAuthorized = await hasValidCallbackSignature(payloadMap);
    const knownPaymentAuthorized = !!payment && amountMatchesPayment(payment, callbackAmount);
    const isAuthorized = credentialsAuthorized || signatureAuthorized || knownPaymentAuthorized;

    if (!isAuthorized) {
      await logPayment(correlationId, "warn", "unauthorized callback payload", {
        payload: sanitizedPayload,
        paymentIdCandidates,
        bookingIdFromPayload,
        matchedPaymentId: payment?.id ?? null,
        callbackAmount,
        auth: describeCallbackAuth(payloadMap),
      });

      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    await logPayment(correlationId, "info", "callback payload", {
      payload: sanitizedPayload,
      paymentIdCandidates,
      bookingIdFromPayload,
      authMode: credentialsAuthorized
        ? "credentials"
        : signatureAuthorized
        ? "signature"
        : "known_payment_reference",
    });

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
            azampay_response: sanitizedPayload,
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
      const orphanEventId = `${correlationId}:${getFirstString(payloadMap, ["status", "transactionStatus"]) || "unknown"}:${
        getFirstString(payloadMap, ["timestamp", "time"]) || Date.now()
      }`;
      const { error: reconciliationEventError } = await supabase
        .from("payment_reconciliation_events")
        .insert({
          provider: "azampay",
          event_type: "orphan_callback",
          provider_event_id: orphanEventId,
          booking_id: bookingIdFromPayload,
          external_reference: externalreference || utilityref || null,
          provider_reference: reference || fspReferenceId || null,
          status: getFirstString(payloadMap, ["transactionstatus", "transactionStatus", "status"]),
          amount: callbackAmount,
          payload: sanitizedPayload,
        });

      if (reconciliationEventError) {
        const code = (reconciliationEventError as { code?: string }).code;
        if (code !== "23505") {
          await logPayment(correlationId, "error", "payment_reconciliation_events insert failed", {
            reconciliationEventError,
            orphanEventId,
          });
        }
      }

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
        payload: sanitizedPayload,
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

    const expectedAmount = Number(payment.amount ?? 0);
    if (
      newStatus === "success" &&
      callbackAmount != null &&
      Number.isFinite(expectedAmount) &&
      expectedAmount > 0 &&
      Math.abs(callbackAmount - expectedAmount) > 0.0001
    ) {
      await supabase
        .from("payments")
        .update({
          status: "pending",
          amount_received: callbackAmount,
          reconciliation_status: "needs_reconciliation",
          failed_reason: "Gateway success amount did not match expected payment amount.",
        })
        .eq("id", payment.id);

      await supabase
        .from("bookings")
        .update({
          status: "payment_reconciliation",
          payment_status: "pending",
          reconciliation_status: "amount_mismatch",
        })
        .eq("id", payment.booking_id)
        .neq("payment_status", "completed");

      await logPayment(correlationId, "error", "payment amount mismatch", {
        expectedAmount,
        callbackAmount,
        paymentId: payment.id,
        bookingId: payment.booking_id,
      });

      await supabase
        .from("payment_webhook_events")
        .update({
          processed_at: new Date().toISOString(),
          processed_outcome: "amount_mismatch",
        })
        .eq("provider", "azampay")
        .eq("provider_event_id", providerEventId);

      return new Response("OK", { status: 200 });
    }

    const { error: paymentUpdateError } = await supabase
      .from("payments")
      .update({
        status: newStatus,
        payment_gateway_ref: reference ?? fspReferenceId ?? null,
        provider_status: newStatus,
        provider_reference: reference ?? fspReferenceId ?? null,
        provider_finalized_at: newStatus === "pending" ? null : new Date().toISOString(),
        amount_received: callbackAmount ?? payment.amount ?? null,
        failed_reason: newStatus === "failed" ? "Gateway reported failed status." : null,
      })
      .eq("id", payment.id);

    if (paymentUpdateError) {
      await logPayment(correlationId, "error", "payment update error", { paymentUpdateError });
    } else {
      await logPaymentStateChange(payment.id, payment.booking_id, newStatus, {
        provider_event_id: providerEventId,
        callback_amount: callbackAmount,
      });
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

    const { data: finalizeOutcome, error: finalizeError } = await supabase.rpc(
      "finalize_paid_booking",
      {
        p_booking_id: bookingId,
        p_payment_id: payment.id,
        p_amount_paid: bookingTotal,
      },
    );

    if (finalizeError) {
      await logPayment(correlationId, "error", "finalize_paid_booking failed", { finalizeError });
      return new Response("OK", { status: 200 });
    }

    if (finalizeOutcome !== "confirmed" && finalizeOutcome !== "already_confirmed") {
      await logPayment(correlationId, "error", "paid booking needs reconciliation", {
        bookingId,
        finalizeOutcome,
      });
      await supabase
        .from("payment_webhook_events")
        .update({
          processed_at: new Date().toISOString(),
          processed_outcome: finalizeOutcome,
        })
        .eq("provider", "azampay")
        .eq("provider_event_id", providerEventId);
      return new Response("OK", { status: 200 });
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
      .update({ processed_at: new Date().toISOString(), processed_outcome: finalizeOutcome })
      .eq("provider", "azampay")
      .eq("provider_event_id", providerEventId);

    return new Response("OK", { status: 200 });
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: e.message }), { status: 500 });
  }
});
