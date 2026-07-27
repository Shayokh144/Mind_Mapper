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
    func extract(from rawText: String) async throws -> ExtractionResult
}

/// Pulls a normalised fact + entities from a STORE message via `tier: .mini`.
nonisolated struct MemoryExtractor: MemoryExtractorProtocol, @unchecked Sendable {
    private let llmClient: LLMClientProtocol

    init(llmClient: LLMClientProtocol) {
        self.llmClient = llmClient
    }

    func extract(from rawText: String) async throws -> ExtractionResult {
        let systemPrompt = """
        You are a personal memory extraction assistant.
        Extract structured information from the user message.
        Reply ONLY with valid JSON, no other text.

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
        - Extract ALL meaningful entities
        - topic_id should be a snake_case stable identifier (e.g. "gift_wife_anniversary")
        - supersedes_hint: look for words like "instead", "actually", "changed my mind", "no longer"
        """

        let json = try await llmClient.complete(
            tier: .mini,
            messages: [
                LLMMessage(role: "system", content: systemPrompt),
                LLMMessage(role: "user", content: rawText),
            ],
            maxTokens: 300,
            temperature: 0
        )

        return try Self.decode(json)
    }

    static func decode(_ raw: String) throws -> ExtractionResult {
        let cleaned = stripCodeFences(raw)
        guard let data = cleaned.data(using: .utf8) else {
            throw AppError.llmResponseInvalid
        }
        do {
            return try JSONDecoder().decode(ExtractionResult.self, from: data)
        } catch {
            AppLogger.error("Failed to decode memory extraction JSON", error: error)
            throw AppError.llmResponseInvalid
        }
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
