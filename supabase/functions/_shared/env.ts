function readEnv(name: string): string | null {
  const value = Deno.env.get(name);
  if (value == null) return null;
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}

export function requireEnv(name: string): string {
  const value = readEnv(name);
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

export function optionalEnv(name: string, fallback?: string): string | undefined {
  return readEnv(name) ?? fallback;
}

export function optionalConfiguredEnv(name: string, fallback?: string): string | undefined {
  const value = readEnv(name);
  if (!value) return fallback;

  const normalized = value.toLowerCase();
  if (
    normalized.startsWith("replace_me") ||
    normalized.startsWith("replace-with") ||
    normalized.startsWith("your-") ||
    normalized.includes("replace-me")
  ) {
    return fallback;
  }

  return value;
}
