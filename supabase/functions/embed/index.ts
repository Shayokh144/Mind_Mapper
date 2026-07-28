import {
  callWithFallback,
  fetchWithTimeout,
  jsonResponse,
  normalizeGeminiModelId,
  providerFailureResponse,
  requireAuth,
  requireGeminiKey,
} from "../_shared/provider.ts"

type RequestBody = {
  input?: string
  model?: string
  fallback_model?: string
}

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

  const input = body.input?.trim()
  const model = body.model?.trim()
  if (!input) {
    return jsonResponse(
      {
        error: {
          code: "bad_request",
          message: "input is required",
          retryable: false,
        },
      },
      400,
    )
  }
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

  const fallbackModel = body.fallback_model?.trim() || undefined

  const result = await callWithFallback(model, fallbackModel, (modelName) =>
    callGeminiEmbed({ apiKey, modelName, input }),
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
          code: "embedding_failed",
          message: "Provider returned non-JSON",
          retryable: true,
          model_attempted: result.model,
          used_fallback: result.usedFallback,
        },
      },
      502,
    )
  }

  const values = extractEmbeddingValues(providerJson)
  if (!values?.length) {
    return jsonResponse(
      {
        error: {
          code: "embedding_failed",
          message: "Provider response missing embedding values",
          retryable: true,
          model_attempted: result.model,
          used_fallback: result.usedFallback,
        },
      },
      502,
    )
  }

  // OpenAI-shaped envelope for iOS LLMClient.
  return jsonResponse({
    data: [
      {
        embedding: values,
        index: 0,
      },
    ],
    model_used: result.model,
    used_fallback: result.usedFallback,
  })
})

async function callGeminiEmbed(args: {
  apiKey: string
  modelName: string
  input: string
}): Promise<Response> {
  const modelId = normalizeGeminiModelId(args.modelName)
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${
      encodeURIComponent(modelId)
    }:embedContent?key=${encodeURIComponent(args.apiKey)}`

  return await fetchWithTimeout(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: `models/${modelId}`,
      content: {
        parts: [{ text: args.input }],
      },
    }),
  })
}

function extractEmbeddingValues(
  json: Record<string, unknown>,
): number[] | null {
  const embedding = json.embedding as { values?: number[] } | undefined
  if (Array.isArray(embedding?.values)) {
    return embedding.values
  }
  // Some responses nest under embeddings[]
  const embeddings = json.embeddings as
    | Array<{ values?: number[] }>
    | undefined
  if (Array.isArray(embeddings?.[0]?.values)) {
    return embeddings[0].values
  }
  return null
}
