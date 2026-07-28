import {
  callWithFallback,
  fetchWithTimeout,
  jsonResponse,
  normalizeGeminiModelId,
  providerFailureResponse,
  requireAuth,
  requireGeminiKey,
} from "../_shared/provider.ts"

type ChatMessage = {
  role: string
  content: string
}

type RequestBody = {
  model?: string
  fallback_model?: string
  messages?: ChatMessage[]
  max_tokens?: number
  temperature?: number
}

type GeminiPart = { text: string }
type GeminiContent = { role: string; parts: GeminiPart[] }

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204 })
  }

  if (req.method !== "POST") {
    return jsonResponse(
      {
        error: {
          code: "method_not_allowed",
          message: "POST required",
          retryable: false,
        },
      },
      405,
    )
  }

  const auth = requireAuth(req)
  if (auth instanceof Response) return auth

  const apiKey = requireGeminiKey()
  if (apiKey instanceof Response) return apiKey

  let body: RequestBody
  try {
    body = await req.json()
  } catch {
    return jsonResponse(
      {
        error: {
          code: "bad_request",
          message: "Invalid JSON body",
          retryable: false,
        },
      },
      400,
    )
  }

  const model = body.model?.trim()
  if (!model) {
    return jsonResponse(
      {
        error: {
          code: "bad_request",
          message: "model is required",
          retryable: false,
        },
      },
      400,
    )
  }

  const messages = body.messages
  if (!Array.isArray(messages) || messages.length === 0) {
    return jsonResponse(
      {
        error: {
          code: "bad_request",
          message: "messages must be a non-empty array",
          retryable: false,
        },
      },
      400,
    )
  }

  const fallbackModel = body.fallback_model?.trim() || undefined
  const maxTokens = body.max_tokens ?? 500
  const temperature = body.temperature ?? 0.3

  const { systemInstruction, contents } = toGeminiContents(messages)
  if (contents.length === 0) {
    return jsonResponse(
      {
        error: {
          code: "bad_request",
          message: "messages must include at least one user/assistant turn",
          retryable: false,
        },
      },
      400,
    )
  }

  const result = await callWithFallback(model, fallbackModel, (modelName) =>
    callGeminiGenerate({
      apiKey,
      modelName,
      contents,
      systemInstruction,
      maxTokens,
      temperature,
    }),
  )

  if (!result.ok) {
    logLlmDebug({
      phase: "provider_error",
      model: result.model,
      usedFallback: result.usedFallback,
      status: result.status,
      request: summarizeRequest(messages, maxTokens, temperature),
      providerBodyPreview: truncate(result.bodyText, 800),
    })
    return providerFailureResponse(result)
  }

  let providerJson: Record<string, unknown>
  try {
    providerJson = JSON.parse(result.bodyText)
  } catch {
    logLlmDebug({
      phase: "provider_non_json",
      model: result.model,
      usedFallback: result.usedFallback,
      request: summarizeRequest(messages, maxTokens, temperature),
      providerBodyPreview: truncate(result.bodyText, 800),
    })
    return jsonResponse(
      {
        error: {
          code: "llm_response_invalid",
          message: "Provider returned non-JSON",
          retryable: true,
          model_attempted: result.model,
          used_fallback: result.usedFallback,
        },
      },
      502,
    )
  }

  const extracted = extractGeminiTextDetailed(providerJson)
  if (extracted.text == null) {
    logLlmDebug({
      phase: "missing_or_truncated_text",
      model: result.model,
      usedFallback: result.usedFallback,
      request: summarizeRequest(messages, maxTokens, temperature),
      gemini: extracted.meta,
      providerBodyPreview: truncate(result.bodyText, 800),
    })
    return jsonResponse(
      {
        error: {
          code: "llm_response_invalid",
          message: "Provider response missing text",
          retryable: true,
          model_attempted: result.model,
          used_fallback: result.usedFallback,
        },
      },
      502,
    )
  }

  logLlmDebug({
    phase: "ok",
    model: result.model,
    usedFallback: result.usedFallback,
    request: summarizeRequest(messages, maxTokens, temperature),
    gemini: extracted.meta,
    responsePreview: truncate(extracted.text, 800),
  })

  // OpenAI-shaped envelope so iOS can stay provider-agnostic.
  return jsonResponse({
    choices: [
      {
        message: {
          role: "assistant",
          content: extracted.text,
        },
      },
    ],
    model_used: result.model,
    used_fallback: result.usedFallback,
  })
})

function toGeminiContents(messages: ChatMessage[]): {
  systemInstruction?: { parts: GeminiPart[] }
  contents: GeminiContent[]
} {
  const systemParts: string[] = []
  const contents: GeminiContent[] = []

  for (const message of messages) {
    const content = message.content ?? ""
    const role = (message.role ?? "user").toLowerCase()

    if (role === "system") {
      if (content) systemParts.push(content)
      continue
    }

    const geminiRole = role === "assistant" || role === "model" ? "model" : "user"
    contents.push({
      role: geminiRole,
      parts: [{ text: content }],
    })
  }

  return {
    systemInstruction: systemParts.length
      ? { parts: [{ text: systemParts.join("\n\n") }] }
      : undefined,
    contents,
  }
}

async function callGeminiGenerate(args: {
  apiKey: string
  modelName: string
  contents: GeminiContent[]
  systemInstruction?: { parts: GeminiPart[] }
  maxTokens: number
  temperature: number
}): Promise<Response> {
  const modelId = normalizeGeminiModelId(args.modelName)
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${
      encodeURIComponent(modelId)
    }:generateContent?key=${encodeURIComponent(args.apiKey)}`

  // Prefer minimal/no thinking for app workloads (guards, JSON extract, titles).
  // Gemini 2.0 has no thinking — thinkingConfigFor returns undefined for those.
  const preferMinimalThinking = true

  const first = await postGemini(url, { ...args, modelName: modelId }, preferMinimalThinking)
  if (preferMinimalThinking && first.status === 400) {
    const bodyText = await first.text()
    console.log(
      `thinking_config_rejected model=${modelId} — retrying without thinkingConfig (${
        truncate(bodyText, 160)
      })`,
    )
    return await postGemini(url, { ...args, modelName: modelId }, false)
  }
  return first
}

async function postGemini(
  url: string,
  args: {
    apiKey: string
    modelName: string
    contents: GeminiContent[]
    systemInstruction?: { parts: GeminiPart[] }
    maxTokens: number
    temperature: number
  },
  preferMinimalThinking: boolean,
): Promise<Response> {
  const generationConfig: Record<string, unknown> = {
    maxOutputTokens: args.maxTokens,
    temperature: args.temperature,
  }

  const thinking = thinkingConfigFor(args.modelName, preferMinimalThinking)
  if (thinking) {
    generationConfig.thinkingConfig = thinking
  }

  // Structured extract / title JSON — forces compact JSON and cuts prose/thinking.
  if (args.temperature === 0 && args.maxTokens >= 40) {
    generationConfig.responseMimeType = "application/json"
  }

  const payload: Record<string, unknown> = {
    contents: args.contents,
    generationConfig,
  }
  if (args.systemInstruction) {
    payload.systemInstruction = args.systemInstruction
  }

  return await fetchWithTimeout(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  })
}

/** Gemini 2.5 uses thinkingBudget; Gemini 3.x uses thinkingLevel.
 *  Gemini 2.0 Flash / Flash-Lite are non-thinking — omit config entirely.
 *  Lite aliases that still advertise thinking get budget 0 when supported.
 */
function thinkingConfigFor(
  modelName: string,
  preferMinimal: boolean,
): Record<string, unknown> | undefined {
  if (!preferMinimal) return undefined
  // Stable 2.0 family has no thinking in the models list — don't send thinkingConfig.
  if (/gemini-2\.0/i.test(modelName)) return undefined
  if (/gemini-3/i.test(modelName) || /flash-latest/i.test(modelName) || /pro-latest/i.test(modelName)) {
    return { thinkingLevel: "minimal" }
  }
  // 2.5 Flash / Flash-Lite and other thinking models
  if (/\blite\b/i.test(modelName)) {
    return { thinkingBudget: 0 }
  }
  return { thinkingBudget: 0 }
}

function extractGeminiText(json: Record<string, unknown>): string | null {
  return extractGeminiTextDetailed(json).text
}

function extractGeminiTextDetailed(json: Record<string, unknown>): {
  text: string | null
  meta: Record<string, unknown>
} {
  const candidates = json.candidates as
    | Array<{
      content?: {
        parts?: Array<{ text?: string; thought?: boolean }>
      }
      finishReason?: string
    }>
    | undefined
  const candidate = candidates?.[0]
  const parts = candidate?.content?.parts ?? []
  const thoughtCount = parts.filter((p) => p.thought === true).length
  const answerParts = parts.filter((p) => p.thought !== true)
  const selected = answerParts.length > 0 ? answerParts : parts
  const text = selected.map((p) => p.text ?? "").join("")
  const meta = {
    finishReason: candidate?.finishReason ?? null,
    partCount: parts.length,
    thoughtPartCount: thoughtCount,
    answerPartCount: answerParts.length,
    textLength: text.length,
  }

  if (!text.length) {
    return { text: null, meta }
  }

  // Truncated JSON is useless to the client; surface a clearer failure.
  if (
    candidate?.finishReason === "MAX_TOKENS" &&
    text.trimStart().startsWith("{") &&
    !text.trimEnd().endsWith("}")
  ) {
    return { text: null, meta: { ...meta, truncatedJson: true } }
  }

  return { text, meta }
}

/** Opt-in via Supabase secret `LLM_DEBUG=1` (or `true`). Off by default. */
function isLlmDebugEnabled(): boolean {
  const value = (Deno.env.get("LLM_DEBUG") ?? "").trim().toLowerCase()
  return value === "1" || value === "true" || value === "yes"
}

function truncate(text: string, max: number): string {
  if (text.length <= max) return text
  return `${text.slice(0, max)}…(+${text.length - max} chars)`
}

function summarizeRequest(
  messages: ChatMessage[],
  maxTokens: number,
  temperature: number,
): Record<string, unknown> {
  const lastUser = [...messages].reverse().find((m) =>
    (m.role ?? "").toLowerCase() === "user"
  )
  return {
    messageCount: messages.length,
    maxTokens,
    temperature,
    lastUserPreview: truncate(lastUser?.content ?? "", 240),
  }
}

function logLlmDebug(payload: Record<string, unknown>): void {
  if (!isLlmDebugEnabled()) return
  console.log(`llm_debug ${JSON.stringify(payload)}`)
}
