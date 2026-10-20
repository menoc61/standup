import { withSupabase } from "@supabase/server";
import {
  consentVersion,
  parseCompletionResponse,
  parseGuidanceInput,
} from "./contract.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

function json(body: unknown, status = 200): Response {
  return Response.json(body, {
    status,
    headers: { ...corsHeaders, "Cache-Control": "no-store" },
  });
}

function withCors(response: Response): Response {
  const headers = new Headers(response.headers);
  for (const [name, value] of Object.entries(corsHeaders)) {
    headers.set(name, value);
  }
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

async function readJsonLimited(request: Request, maxBytes: number): Promise<unknown> {
  const reader = request.body?.getReader();
  if (reader === undefined) throw new SyntaxError("Missing body");
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel();
      throw new RangeError("Request too large");
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return JSON.parse(new TextDecoder().decode(bytes));
}

type GuidanceConfig = {
  endpoint: string;
  apiKey: string;
  model: string;
};

/// Dashboard secrets win. They are the documented path and need no database
/// round trip. The Vault fallback exists for a project without CLI access to
/// set secrets: the credentials are encrypted at rest and only service_role
/// may read them (`public.ai_guidance_config` revokes anon/authenticated).
function envConfig(): GuidanceConfig | null {
  const endpoint = Deno.env.get("AI_GUIDANCE_COMPLETIONS_URL")?.trim() ?? "";
  const apiKey = Deno.env.get("AI_GUIDANCE_API_KEY")?.trim() ?? "";
  const model = Deno.env.get("AI_GUIDANCE_MODEL")?.trim() ?? "";
  return endpoint.length > 0 && apiKey.length > 0 && model.length > 0
    ? { endpoint, apiKey, model }
    : null;
}

async function loadGuidanceConfig(): Promise<GuidanceConfig | null> {
  const fromEnv = envConfig();
  if (fromEnv !== null) return fromEnv;

  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim();
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();
  if (!supabaseUrl || !serviceKey) return null;

  try {
    const response = await fetch(`${supabaseUrl}/rest/v1/rpc/ai_guidance_config`, {
      method: "POST",
      headers: {
        "apikey": serviceKey,
        "Authorization": `Bearer ${serviceKey}`,
        "Content-Type": "application/json",
      },
      body: "{}",
      signal: AbortSignal.timeout(4_000),
    });
    if (!response.ok) return null;
    const payload: unknown = await response.json();
    if (typeof payload !== "object" || payload === null) return null;
    const record = payload as Record<string, unknown>;
    const endpoint = typeof record.endpoint === "string" ? record.endpoint.trim() : "";
    const apiKey = typeof record.api_key === "string" ? record.api_key.trim() : "";
    const model = typeof record.model === "string" ? record.model.trim() : "";
    return endpoint.length > 0 && apiKey.length > 0 && model.length > 0
      ? { endpoint, apiKey, model }
      : null;
  } catch {
    return null;
  }
}

const authenticatedHandler = withSupabase(
  { auth: "user", cors: "disabled" },
  async (request) => {
    if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);
    if (!request.headers.get("content-type")?.startsWith("application/json")) {
      return json({ error: "unsupported_media_type" }, 415);
    }

    let body: unknown;
    try {
      body = await readJsonLimited(request, 2048);
    } catch (error) {
      if (error instanceof RangeError) {
        return json({ error: "request_too_large" }, 413);
      }
      return json({ error: "invalid_json" }, 400);
    }
    if (
      typeof body !== "object" || body === null || Array.isArray(body) ||
      Object.keys(body).sort().join(",") !== "consent_version,input"
    ) {
      return json({ error: "invalid_request" }, 400);
    }

    const requestBody = body as Record<string, unknown>;
    if (requestBody.consent_version !== consentVersion) {
      return json({ error: "consent_required" }, 403);
    }
    const input = parseGuidanceInput(requestBody.input);
    if (input === null) return json({ error: "invalid_guidance_input" }, 400);

    const config = await loadGuidanceConfig();
    if (config === null) {
      return json({ error: "ai_not_configured" }, 503);
    }

    let endpointUrl: URL;
    try {
      endpointUrl = new URL(config.endpoint);
    } catch {
      return json({ error: "ai_not_configured" }, 503);
    }
    if (
      endpointUrl.protocol !== "https:" ||
      endpointUrl.username.length > 0 ||
      endpointUrl.password.length > 0 ||
      endpointUrl.search.length > 0 ||
      endpointUrl.hash.length > 0
    ) {
      return json({ error: "ai_not_configured" }, 503);
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15_000);
    try {
      const upstream = await fetch(endpointUrl, {
        method: "POST",
        redirect: "error",
        headers: {
          "Authorization": `Bearer ${config.apiKey}`,
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: JSON.stringify({
          model: config.model,
          temperature: 0,
          max_tokens: 100,
          messages: [
            {
              role: "system",
              content:
                'Give one brief, non-medical workplace movement suggestion. Return only JSON with exactly two string keys: "kind" and "reason". kind must be takeShortMovementBreak, adjustReminderCadence, or celebrate. reason must be goalProgress, repeatedSnoozes, consistentActivity, noActivityYet, or feedbackTooFrequent. Use only these valid pairs: takeShortMovementBreak with goalProgress, repeatedSnoozes, or noActivityYet; adjustReminderCadence with repeatedSnoozes or feedbackTooFrequent; celebrate with goalProgress or consistentActivity. Read the whole input before answering: if feedback is suggestionsTooFrequent, answer adjustReminderCadence with feedbackTooFrequent. Do not output prose, personal data, medical claims, or actions that change app settings.',
            },
            { role: "user", content: JSON.stringify(input) },
          ],
        }),
        signal: controller.signal,
      });
      if (!upstream.ok) return json({ error: "ai_unavailable" }, 502);

      const responseLength = Number(upstream.headers.get("content-length") ?? 0);
      if (responseLength > 8192) return json({ error: "invalid_ai_response" }, 502);
      const responseText = await upstream.text();
      if (new TextEncoder().encode(responseText).byteLength > 8192) {
        return json({ error: "invalid_ai_response" }, 502);
      }
      let completion: unknown;
      try {
        completion = JSON.parse(responseText);
      } catch {
        return json({ error: "invalid_ai_response" }, 502);
      }
      const result = parseCompletionResponse(completion);
      if (result === null) return json({ error: "invalid_ai_response" }, 502);
      return json(result);
    } catch {
      return json({ error: "ai_unavailable" }, 502);
    } finally {
      clearTimeout(timeout);
    }
  },
);

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  return withCors(await authenticatedHandler(request));
});
