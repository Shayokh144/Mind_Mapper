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
        // Gemini free-tier model IDs change; prefer *-latest / current Flash family.
        // Verified working against this project's API key (2026-07): flash-lite-latest, flash-latest, 3.6-flash.
        case .nano: return "gemini-flash-lite-latest"
        case .mini: return "gemini-flash-latest"
        case .full: return "gemini-3.6-flash"
        case .embed: return "gemini-embedding-001"
        }
    }

    func fallback(for tier: LLMModelTier) -> String {
        switch tier {
        case .nano: return "gemini-3.5-flash-lite"
        case .mini: return "gemini-flash-lite-latest"
        case .full: return "gemini-flash-latest"
        case .embed: return "gemini-embedding-001"
        }
    }
}

struct LLMMessage: Codable, Sendable {
    let role: String
    let content: String
}

/// Invokes Supabase Edge Functions (`llm-proxy`, `embed`). API keys stay server-side.
final class LLMClient: LLMClientProtocol {
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

        do {
            let response: CompleteResponse = try await client.functions.invoke(
                "llm-proxy",
                options: FunctionInvokeOptions(body: body)
            )
            #if DEBUG
            AppLogger.info(
                "LLM complete tier=\(tier.rawValue) model=\(response.model_used ?? tier.primary) used_fallback=\(response.used_fallback ?? false)"
            )
            #endif
            guard let content = response.choices.first?.message.content,
                  !content.isEmpty
            else {
                throw AppError.llmResponseInvalid
            }
            return content
        } catch let error as AppError {
            throw error
        } catch {
            throw mapInvokeError(error)
        }
    }

    // MARK: - Embed

    func embed(text: String, tier: LLMModelTier = .embed) async throws -> [Float] {
        let body = EmbedRequestBody(
            input: text,
            model: tier.primary,
            fallback_model: tier.fallback
        )

        do {
            let response: EmbedResponse = try await client.functions.invoke(
                "embed",
                options: FunctionInvokeOptions(body: body)
            )
            #if DEBUG
            AppLogger.info(
                "LLM embed model=\(response.model_used ?? tier.primary) used_fallback=\(response.used_fallback ?? false) dims=\(response.data.first?.embedding.count ?? 0)"
            )
            #endif
            guard let embedding = response.data.first?.embedding, !embedding.isEmpty else {
                throw AppError.embeddingFailed
            }
            return embedding
        } catch let error as AppError {
            throw error
        } catch {
            throw mapInvokeError(error, embedding: true)
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
        status == 429 || status == 402 || status == 403 || status == 404
    }

    static func isRetryableProviderPayload(_ data: Data) -> Bool {
        guard let text = String(data: data, encoding: .utf8)?.lowercased() else {
            return false
        }
        return text.contains("resource_exhausted")
            || text.contains("insufficient_quota")
            || text.contains("quota exceeded")
            || text.contains("rate limit")
            || text.contains("not_found")
            || text.contains("is not found")
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
