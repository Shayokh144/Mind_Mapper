import Foundation

struct ExtractionResult: Decodable, Equatable, Sendable {
    let cleanText: String
    let entities: [EntityItem]
    let supersedesHint: String?

    struct EntityItem: Decodable, Equatable, Sendable {
        let type: String
        let value: String
    }

    enum CodingKeys: String, CodingKey {
        case cleanText = "clean_text"
        case entities
        case supersedesHint = "supersedes_hint"
    }
}

protocol MemoryExtractorProtocol {
    func extract(
        from rawText: String,
        conversationContext: [LLMMessage]
    ) async throws -> ExtractionResult
}

/// Pulls a normalised fact + entities from a STORE message via `tier: .mini`.
nonisolated struct MemoryExtractor: MemoryExtractorProtocol, @unchecked Sendable {
    private let llmClient: LLMClientProtocol

    init(llmClient: LLMClientProtocol) {
        self.llmClient = llmClient
    }

    func extract(
        from rawText: String,
        conversationContext: [LLMMessage] = []
    ) async throws -> ExtractionResult {
        do {
            return try await requestExtraction(rawText, conversationContext: conversationContext)
        } catch {
            // Don't immediately retry quota/rate-limit — Google asks to wait ~30–60s.
            if Self.isQuotaOrRateLimited(error) {
                throw error
            }
            // One retry — Gemini Flash sometimes returns truncated / empty JSON.
            AppLogger.error("Memory extraction decode failed; retrying once", error: error)
            return try await requestExtraction(rawText, conversationContext: conversationContext)
        }
    }

    private static func isQuotaOrRateLimited(_ error: Error) -> Bool {
        if let appError = error as? AppError {
            switch appError {
            case .rateLimitExceeded:
                return true
            case let .llmCallFailed(underlying):
                let text = String(describing: underlying).lowercased()
                return text.contains("429")
                    || text.contains("quota")
                    || text.contains("resource_exhausted")
            default:
                break
            }
        }
        let text = String(describing: error).lowercased()
        return text.contains("429") || text.contains("quota")
    }

    private func requestExtraction(
        _ rawText: String,
        conversationContext: [LLMMessage]
    ) async throws -> ExtractionResult {
        let systemPrompt = """
        You are a personal memory extraction assistant.
        Extract structured information from the latest user message.
        Prior conversation turns (if any) are only for resolving pronouns and incomplete \
        references (e.g. "it" → the passport mentioned earlier). Do NOT merge the whole \
        thread into one memory — output one clean_text for the NEW fact only.
        Reply ONLY with valid JSON, no other text. Keep the JSON compact.

        JSON format:
        {
          "clean_text": "normalised fact in standalone form",
          "entities": [
            { "type": "person|category|topic_id|product|location", "value": "the value" }
          ],
          "supersedes_hint": "word or phrase suggesting this replaces an older decision, or null"
        }

        Rules:
        - clean_text must be a complete standalone fact (no pronouns like "it" or "there")
        - Extract ALL meaningful entities (typically 1–5)
        - topic_id should be a snake_case stable identifier (e.g. "gift_wife_anniversary")
        - supersedes_hint: look for words like "instead", "actually", "changed my mind", "no longer"
        """

        var messages: [LLMMessage] = [
            LLMMessage(role: "system", content: systemPrompt),
        ]
        messages.append(contentsOf: conversationContext)
        messages.append(LLMMessage(role: "user", content: rawText))

        let json = try await llmClient.complete(
            tier: .mini,
            messages: messages,
            // Compact JSON; proxy also sets responseMimeType=application/json when temp=0.
            maxTokens: 512,
            temperature: 0
        )

        return try Self.decode(json)
    }

    static func decode(_ raw: String) throws -> ExtractionResult {
        let cleaned = extractJSONObject(from: stripCodeFences(raw))
        guard let data = cleaned.data(using: .utf8), !cleaned.isEmpty else {
            AppLogger.error("Memory extraction JSON empty after cleanup. raw=\(raw.prefix(300))")
            throw AppError.llmResponseInvalid
        }
        do {
            return try JSONDecoder().decode(ExtractionResult.self, from: data)
        } catch {
            AppLogger.error(
                "Failed to decode memory extraction JSON. raw=\(cleaned.prefix(500))",
                error: error
            )
            throw AppError.llmResponseInvalid
        }
    }

    /// Pull the outermost `{ ... }` so preamble / trailing prose does not break decoding.
    static func extractJSONObject(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = trimmed.firstIndex(of: "{"),
              let end = trimmed.lastIndex(of: "}"),
              start < end
        else {
            return trimmed
        }
        return String(trimmed[start...end])
    }

    static func stripCodeFences(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.hasPrefix("```") else { return result }

        if let firstNewline = result.firstIndex(of: "\n") {
            result = String(result[result.index(after: firstNewline)...])
        }
        if let fence = result.range(of: "```", options: .backwards) {
            result = String(result[..<fence.lowerBound])
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
