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
 * Rate limit / quota — retry once with fallback_model.
 * Also treats missing/invalid model (404 / NOT_FOUND) as retryable so a
 * temporary bad primary can verify fallback (task 08 step 11).
 */
export function isRetryableProviderFailure(
  status: number,
  bodyText: string,
): boolean {
  if (status === 429 || status === 402 || status === 403 || status === 404) {
    return true
  }
  const lower = bodyText.toLowerCase()
  return (
    lower.includes("resource_exhausted") ||
    lower.includes("insufficient_quota") ||
    lower.includes("quota exceeded") ||
    lower.includes("rate limit") ||
    lower.includes("not_found") ||
    lower.includes("is not found")
  )
}

export type CallResult = {
  ok: boolean
  status: number
  bodyText: string
  model: string
  usedFallback: boolean
}

/**
 * Call primary model; on rate-limit/quota, retry once with fallback.
 * Does not loop.
 */
export async function callWithFallback(
  primary: string,
  fallback: string | undefined,
  invoke: (model: string) => Promise<Response>,
): Promise<CallResult> {
  const primaryRes = await invoke(primary)
  const primaryText = await primaryRes.text()

  if (primaryRes.ok) {
    console.log(`provider_ok model=${primary} used_fallback=false`)
    return {
      ok: true,
      status: primaryRes.status,
      bodyText: primaryText,
      model: primary,
      usedFallback: false,
    }
  }

  const canRetry =
    Boolean(fallback) &&
    fallback !== primary &&
    isRetryableProviderFailure(primaryRes.status, primaryText)

  if (!canRetry || !fallback) {
    console.log(
      `provider_fail model=${primary} status=${primaryRes.status} used_fallback=false`,
    )
    return {
      ok: false,
      status: primaryRes.status,
      bodyText: primaryText,
      model: primary,
      usedFallback: false,
    }
  }

  console.log(
    `provider_retry primary=${primary} fallback=${fallback} status=${primaryRes.status}`,
  )
  const fallbackRes = await invoke(fallback)
  const fallbackText = await fallbackRes.text()

  if (fallbackRes.ok) {
    console.log(`provider_ok model=${fallback} used_fallback=true`)
  } else {
    console.log(
      `provider_fail model=${fallback} status=${fallbackRes.status} used_fallback=true`,
    )
  }

  return {
    ok: fallbackRes.ok,
    status: fallbackRes.status,
    bodyText: fallbackText,
    model: fallback,
    usedFallback: true,
  }
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
