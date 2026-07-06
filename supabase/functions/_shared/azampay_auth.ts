type TokenStore = {
  from: (table: string) => any;
};

type AzamPayAuthConfig = {
  azamPayAppName: string;
  azamPayClientId: string;
  azamPayClientSecret: string;
  azamPayAuthUrl: string;
};

export class AzamPayAuthError extends Error {
  status: number;
  statusText: string;
  details: unknown;

  constructor(status: number, statusText: string, details: unknown) {
    super(`Failed to obtain AzamPay token (${status})`);
    this.name = "AzamPayAuthError";
    this.status = status;
    this.statusText = statusText;
    this.details = details;
  }
}

function stripWrappingQuotes(value: string): string {
  const trimmed = value.trim();
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1).trim();
  }
  return trimmed;
}

function parseJsonOrText(raw: string): unknown {
  if (!raw) return {};
  try {
    return JSON.parse(raw);
  } catch {
    return raw;
  }
}

function sanitizeProviderPayload(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(sanitizeProviderPayload);
  if (!value || typeof value !== "object") return value;

  const redacted: Record<string, unknown> = {};
  for (const [key, item] of Object.entries(value)) {
    redacted[key] = /token|secret|password|key/i.test(key)
      ? "[redacted]"
      : sanitizeProviderPayload(item);
  }
  return redacted;
}

async function shortFingerprint(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .slice(0, 6)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function extractToken(payload: unknown): { token: string | null; expiresIn: number } {
  if (!payload || typeof payload !== "object") {
    return { token: null, expiresIn: 3600 };
  }

  const root = payload as Record<string, unknown>;
  const data = (root.data && typeof root.data === "object")
    ? root.data as Record<string, unknown>
    : root;
  const token = data.accessToken ?? data.token;
  const expiresIn = Number(data.expiresIn ?? root.expiresIn ?? 3600);

  return {
    token: typeof token === "string" && token.trim() ? token : null,
    expiresIn: Number.isFinite(expiresIn) && expiresIn > 0 ? expiresIn : 3600,
  };
}

export async function getAzamPayToken(
  supabase: TokenStore,
  config: AzamPayAuthConfig,
): Promise<string> {
  const { data: tokenData } = await supabase
    .from("azampay_tokens")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (tokenData && new Date(tokenData.expires_at as string) > new Date()) {
    return tokenData.token as string;
  }

  const appName = stripWrappingQuotes(config.azamPayAppName);
  const clientId = stripWrappingQuotes(config.azamPayClientId);
  const clientSecret = stripWrappingQuotes(config.azamPayClientSecret);

  const res = await fetch(config.azamPayAuthUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify({ appName, clientId, clientSecret }),
  });

  const raw = await res.text();
  const parsed = parseJsonOrText(raw);
  const providerPayload = sanitizeProviderPayload(parsed);

  if (!res.ok) {
    console.error("AzamPay token request failed", {
      status: res.status,
      statusText: res.statusText,
      authUrl: config.azamPayAuthUrl,
      appName,
      clientIdSuffix: clientId.slice(-6),
      clientSecretLength: clientSecret.length,
      clientSecretFingerprint: await shortFingerprint(clientSecret),
      strippedCredentialQuotes:
        appName !== config.azamPayAppName ||
        clientId !== config.azamPayClientId ||
        clientSecret !== config.azamPayClientSecret,
      providerPayload,
    });
    throw new AzamPayAuthError(res.status, res.statusText, providerPayload);
  }

  const { token, expiresIn } = extractToken(parsed);
  if (!token) {
    console.error("AzamPay token missing from auth response", {
      status: res.status,
      providerPayload,
    });
    throw new Error("AzamPay token missing from auth response");
  }

  await supabase.from("azampay_tokens").insert({
    token,
    expires_at: new Date(Date.now() + expiresIn * 1000).toISOString(),
  });

  return token;
}
