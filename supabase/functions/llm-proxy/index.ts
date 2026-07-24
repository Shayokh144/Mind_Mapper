import {
  callWithFallback,
  jsonResponse,
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
    return providerFailureResponse(result)
  }

  let providerJson: Record<string, unknown>
  try {
    providerJson = JSON.parse(result.bodyText)
  } catch {
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

  const text = extractGeminiText(providerJson)
  if (text == null) {
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

  // OpenAI-shaped envelope so iOS can stay provider-agnostic.
  return jsonResponse({
    choices: [
      {
        message: {
          role: "assistant",
          content: text,
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
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${
      encodeURIComponent(args.modelName)
    }:generateContent?key=${encodeURIComponent(args.apiKey)}`

  const payload: Record<string, unknown> = {
    contents: args.contents,
    generationConfig: {
      maxOutputTokens: args.maxTokens,
      temperature: args.temperature,
    },
  }
  if (args.systemInstruction) {
    payload.systemInstruction = args.systemInstruction
  }

  return await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  })
}

function extractGeminiText(json: Record<string, unknown>): string | null {
  const candidates = json.candidates as
    | Array<{ content?: { parts?: Array<{ text?: string }> } }>
    | undefined
  const parts = candidates?.[0]?.content?.parts
  if (!parts?.length) return null
  const text = parts.map((p) => p.text ?? "").join("")
  return text.length ? text : null
}
