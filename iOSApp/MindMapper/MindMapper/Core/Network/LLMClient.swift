import Foundation
import Supabase

/// Model capability tier. Use cases pass a tier — never raw model name strings.
enum LLMModelTier: String, Sendable {
    case nano
    case mini
    case full
    case embed

    var primary: String { LLMModelConfig.shared.primary(for: self) }
    var fallback: String { LLMModelConfig.shared.fallback(for: self) }
}

/// Single place to swap Gemini (dev) ↔ OpenAI (prod) model names.
struct LLMModelConfig: Sendable {
    static let shared = LLMModelConfig()

    func primary(for tier: LLMModelTier) -> String {
        switch tier {
        // Free-tier quotas for this project (AI Studio, 2026-07):
        //   gemini-3.5-flash-lite  500 RPD  ← prefer for nano/mini
        //   gemini-2.5-flash         20 RPD
        //   gemini-2.5-flash-lite    20 RPD
        //   gemini-3.6-flash         20 RPD
        // Do not use aliases (`*-latest`) or 2.0 models (free-tier limit: 0).
        case .nano: return "gemini-3.5-flash-lite"
        case .mini: return "gemini-3.5-flash-lite"
        case .full: return "gemini-3.6-flash"
        case .embed: return "gemini-embedding-001"
        }
    }

    func fallback(for tier: LLMModelTier) -> String {
        switch tier {
        case .nano: return "gemini-2.5-flash-lite"
        case .mini: return "gemini-3.6-flash"
        case .full: return "gemini-2.5-flash"
        case .embed: return "gemini-embedding-001"
        }
    }
}

struct LLMMessage: Codable, Sendable {
    let role: String
    let content: String
}

/// Invokes Supabase Edge Functions (`llm-proxy`, `embed`). API keys stay server-side.
/// `nonisolated` — network I/O must not hop through MainActor (nonisolated use cases
/// calling a MainActor `LLMClient` can hang after the first successful call).
nonisolated final class LLMClient: LLMClientProtocol, @unchecked Sendable {
    /// Set once from `AppContainer` at launch. Use cases may call `LLMClient.shared`.
    static private(set) var shared: LLMClient!

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    static func configure(client: SupabaseClient) {
        shared = LLMClient(client: client)
    }

    // MARK: - Complete

    func complete(
        tier: LLMModelTier,
        messages: [LLMMessage],
        maxTokens: Int = 500,
        temperature: Double = 0.3
    ) async throws -> String {
        precondition(tier != .embed, "Use embed(text:) for embedding tier")

        let body = CompleteRequestBody(
            model: tier.primary,
            fallback_model: tier.fallback,
            messages: messages,
            max_tokens: maxTokens,
            temperature: temperature
        )

        Self.logCompleteRequest(
            tier: tier,
            maxTokens: maxTokens,
            temperature: temperature,
            messages: messages
        )

        do {
            let response: CompleteResponse = try await client.functions.invoke(
                "llm-proxy",
                options: FunctionInvokeOptions(body: body)
            )
            guard let content = response.choices.first?.message.content,
                  !content.isEmpty
            else {
                Self.logCompleteResponse(
                    tier: tier,
                    modelUsed: response.model_used,
                    usedFallback: response.used_fallback,
                    content: nil,
                    note: "empty_or_missing_content"
                )
                throw AppError.llmResponseInvalid
            }
            Self.logCompleteResponse(
                tier: tier,
                modelUsed: response.model_used,
                usedFallback: response.used_fallback,
                content: content,
                note: nil
            )
            return content
        } catch let error as AppError {
            AppLogger.debug("LLM complete FAILED tier=\(tier.rawValue) error=\(error)")
            throw error
        } catch {
            let mapped = mapInvokeError(error)
            AppLogger.debug("LLM complete FAILED tier=\(tier.rawValue) error=\(mapped)")
            throw mapped
        }
    }

    // MARK: - Embed

    func embed(text: String, tier: LLMModelTier = .embed) async throws -> [Float] {
        let body = EmbedRequestBody(
            input: text,
            model: tier.primary,
            fallback_model: tier.fallback
        )

        AppLogger.debug(
            """
            LLM embed REQUEST model=\(tier.primary) fallback=\(tier.fallback) \
            inputChars=\(text.count) input=\(Self.truncate(text))
            """
        )

        do {
            let response: EmbedResponse = try await client.functions.invoke(
                "embed",
                options: FunctionInvokeOptions(body: body)
            )
            guard let embedding = response.data.first?.embedding, !embedding.isEmpty else {
                AppLogger.debug(
                    """
                    LLM embed RESPONSE empty model=\(response.model_used ?? tier.primary) \
                    used_fallback=\(response.used_fallback ?? false)
                    """
                )
                throw AppError.embeddingFailed
            }
            AppLogger.debug(
                """
                LLM embed RESPONSE model=\(response.model_used ?? tier.primary) \
                used_fallback=\(response.used_fallback ?? false) dims=\(embedding.count)
                """
            )
            return embedding
        } catch let error as AppError {
            AppLogger.debug("LLM embed FAILED error=\(error)")
            throw error
        } catch {
            let mapped = mapInvokeError(error, embedding: true)
            AppLogger.debug("LLM embed FAILED error=\(mapped)")
            throw mapped
        }
    }

    // MARK: - Retryable detection (client-side helper; Edge Function also retries once)

    static func isRetryableLLMError(_ error: Error) -> Bool {
        if let appError = error as? AppError {
            switch appError {
            case .llmCallFailed, .embeddingFailed, .rateLimitExceeded, .noInternet:
                return true
            default:
                return false
            }
        }

        if let functionsError = error as? FunctionsError {
            switch functionsError {
            case let .httpError(code, data):
                return isRetryableHTTPStatus(code) || isRetryableProviderPayload(data)
            case .relayError:
                return true
            }
        }

        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            return true
        }

        return isRetryableProviderPayload(
            String(describing: error).data(using: .utf8) ?? Data()
        )
    }

    static func isRetryableHTTPStatus(_ status: Int) -> Bool {
        status == 429 || status == 402 || status == 403 || status == 404 || status == 504
    }

    static func isRetryableProviderPayload(_ data: Data) -> Bool {
        guard let text = String(data: data, encoding: .utf8)?.lowercased() else {
            return false
        }
        return text.contains("resource_exhausted")
            || text.contains("insufficient_quota")
            || text.contains("quota exceeded")
            || text.contains("rate limit")
            || text.contains("timed out")
            || text.contains("timeout")
            || text.contains("not_found")
            || text.contains("is not found")
            || text.contains("no longer available")
            || text.contains("\"code\":\"llm_unavailable\"")
    }

    // MARK: - Private

    private func mapInvokeError(_ error: Error, embedding: Bool = false) -> AppError {
        if let functionsError = error as? FunctionsError {
            switch functionsError {
            case let .httpError(code, data):
                let body = String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
                AppLogger.error("Edge Function HTTP \(code): \(body)")
                if code == 401 {
                    return .notAuthenticated
                }
                if Self.isRetryableHTTPStatus(code) || Self.isRetryableProviderPayload(data) {
                    return embedding
                        ? .embeddingFailed
                        : .llmCallFailed(underlying: error)
                }
                return embedding
                    ? .embeddingFailed
                    : .llmCallFailed(underlying: error)
            case .relayError:
                return embedding
                    ? .embeddingFailed
                    : .llmCallFailed(underlying: error)
            }
        }

        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            return .noInternet
        }

        return embedding
            ? .embeddingFailed
            : .llmCallFailed(underlying: error)
    }

    // MARK: - DEBUG request / response logging

    private static let debugPreviewLimit = 800

    private static func logCompleteRequest(
        tier: LLMModelTier,
        maxTokens: Int,
        temperature: Double,
        messages: [LLMMessage]
    ) {
        let messageSummaries = messages.map { message in
            "\(message.role):\(truncate(message.content))"
        }.joined(separator: " | ")
        AppLogger.debug(
            """
            LLM complete REQUEST tier=\(tier.rawValue) model=\(tier.primary) \
            fallback=\(tier.fallback) maxTokens=\(maxTokens) temperature=\(temperature) \
            messages=[\(messageSummaries)]
            """
        )
    }

    private static func logCompleteResponse(
        tier: LLMModelTier,
        modelUsed: String?,
        usedFallback: Bool?,
        content: String?,
        note: String?
    ) {
        let noteSuffix = note.map { " note=\($0)" } ?? ""
        AppLogger.debug(
            """
            LLM complete RESPONSE tier=\(tier.rawValue) model=\(modelUsed ?? tier.primary) \
            used_fallback=\(usedFallback ?? false) chars=\(content?.count ?? 0) \
            content=\(truncate(content ?? ""))\(noteSuffix)
            """
        )
    }

    private static func truncate(_ text: String, limit: Int = debugPreviewLimit) -> String {
        guard text.count > limit else { return text }
        let end = text.index(text.startIndex, offsetBy: limit)
        return "\(text[..<end])…(+\(text.count - limit) chars)"
    }
}

// MARK: - Request / response DTOs

private struct CompleteRequestBody: Encodable {
    let model: String
    let fallback_model: String
    let messages: [LLMMessage]
    let max_tokens: Int
    let temperature: Double
}

private struct CompleteResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
    let model_used: String?
    let used_fallback: Bool?
}

private struct EmbedRequestBody: Encodable {
    let input: String
    let model: String
    let fallback_model: String
}

private struct EmbedResponse: Decodable {
    struct EmbedData: Decodable {
        let embedding: [Float]
    }

    let data: [EmbedData]
    let model_used: String?
    let used_fallback: Bool?
}
