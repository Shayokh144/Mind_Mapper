/** Shared Gemini (dev) helpers for llm-proxy and embed. */

export type StructuredError = {
  error: {
    code: string
    message: string
    retryable: boolean
    model_attempted?: string
    used_fallback?: boolean
  }
}

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}

export function unauthorized(): Response {
  return jsonResponse(
    {
      error: {
        code: "unauthorized",
        message: "Missing Authorization header",
        retryable: false,
      },
    } satisfies StructuredError,
    401,
  )
}

export function requireAuth(req: Request): string | Response {
  const authHeader = req.headers.get("Authorization")
  if (!authHeader?.trim()) {
    return unauthorized()
  }
  return authHeader
}

export function requireGeminiKey(): string | Response {
  const key = Deno.env.get("GEMINI_API_KEY")
  if (!key) {
    return jsonResponse(
      {
        error: {
          code: "server_misconfigured",
          message: "GEMINI_API_KEY is not set in Supabase secrets",
          retryable: false,
        },
      } satisfies StructuredError,
      500,
    )
  }
  return key
}

/**
 * Gemini list API returns `models/gemini-2.0-flash`; generateContent URLs need
 * the bare id after `/v1beta/models/`. Encoding a slash (`models%2F…`) would 404.
 * Our iOS client already sends bare ids — this strips a prefix if one is passed.
 */
export function normalizeGeminiModelId(modelName: string): string {
  const trimmed = modelName.trim()
  return trimmed.replace(/^models\//i, "")
}

/**
 * Rate limit / quota — retry once with fallback_model.
 * Also treats missing/invalid model (404 / NOT_FOUND) as retryable so a
 * temporary bad primary can verify fallback (task 08 step 11).
 * 504 = our AbortSignal timeout waiting on the provider.
 */
export function isRetryableProviderFailure(
  status: number,
  bodyText: string,
): boolean {
  if (
    status === 429 ||
    status === 402 ||
    status === 403 ||
    status === 404 ||
    status === 504
  ) {
    return true
  }
  const lower = bodyText.toLowerCase()
  return (
    lower.includes("resource_exhausted") ||
    lower.includes("insufficient_quota") ||
    lower.includes("quota exceeded") ||
    lower.includes("rate limit") ||
    lower.includes("not_found") ||
    lower.includes("is not found") ||
    lower.includes("no longer available") ||
    lower.includes("timed out") ||
    lower.includes("timeout")
  )
}

/** Default wait for Gemini before aborting (then fallback once). Keep short so a
 * queued free-tier primary does not burn the whole UX budget before fallback. */
export const PROVIDER_FETCH_TIMEOUT_MS = 20_000

/**
 * `fetch` with AbortSignal timeout. On abort returns a synthetic 504 Response
 * so `callWithFallback` can retry / race the fallback model.
 */
export async function fetchWithTimeout(
  url: string,
  init: RequestInit,
  timeoutMs = PROVIDER_FETCH_TIMEOUT_MS,
): Promise<Response> {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), timeoutMs)
  try {
    return await fetch(url, { ...init, signal: controller.signal })
  } catch (error) {
    const name = error instanceof Error ? error.name : ""
    if (name === "AbortError" || name === "TimeoutError") {
      console.log(`provider_timeout after_ms=${timeoutMs}`)
      return new Response(
        JSON.stringify({
          error: {
            message: `Provider request timed out after ${timeoutMs}ms`,
            status: "TIMEOUT",
          },
        }),
        { status: 504, headers: { "Content-Type": "application/json" } },
      )
    }
    throw error
  } finally {
    clearTimeout(timer)
  }
}

export type CallResult = {
  ok: boolean
  status: number
  bodyText: string
  model: string
  usedFallback: boolean
}

async function invokeModel(
  model: string,
  usedFallback: boolean,
  invoke: (model: string) => Promise<Response>,
): Promise<CallResult> {
  const res = await invoke(model)
  const bodyText = await res.text()
  if (res.ok) {
    console.log(`provider_ok model=${model} used_fallback=${usedFallback}`)
  } else {
    console.log(
      `provider_fail model=${model} status=${res.status} used_fallback=${usedFallback}`,
    )
  }
  return {
    ok: res.ok,
    status: res.status,
    bodyText,
    model,
    usedFallback,
  }
}

/**
 * Call primary model; on rate-limit/quota/timeout/not-found, retry once with fallback.
 * Does not loop.
 */
export async function callWithFallback(
  primary: string,
  fallback: string | undefined,
  invoke: (model: string) => Promise<Response>,
): Promise<CallResult> {
  const primaryResult = await invokeModel(primary, false, invoke)
  if (primaryResult.ok) {
    return primaryResult
  }

  const canRetry =
    Boolean(fallback) &&
    fallback !== primary &&
    isRetryableProviderFailure(primaryResult.status, primaryResult.bodyText)

  if (!canRetry || !fallback) {
    return primaryResult
  }

  console.log(
    `provider_retry primary=${primary} fallback=${fallback} status=${primaryResult.status}`,
  )
  return await invokeModel(fallback, true, invoke)
}

export function providerFailureResponse(result: CallResult): Response {
  let providerMessage = result.bodyText
  try {
    const parsed = JSON.parse(result.bodyText)
    providerMessage =
      parsed?.error?.message ?? parsed?.error?.status ?? result.bodyText
  } catch {
    // keep raw text
  }

  return jsonResponse(
    {
      error: {
        code: "llm_unavailable",
        message: typeof providerMessage === "string"
          ? providerMessage
          : "Provider request failed",
        retryable: isRetryableProviderFailure(result.status, result.bodyText),
        model_attempted: result.model,
        used_fallback: result.usedFallback,
      },
    } satisfies StructuredError,
    result.status >= 400 ? result.status : 502,
  )
}
