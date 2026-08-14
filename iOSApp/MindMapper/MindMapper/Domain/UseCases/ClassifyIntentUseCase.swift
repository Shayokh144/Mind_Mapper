import Foundation

protocol ClassifyIntentUseCaseProtocol {
    func execute(
        _ input: String,
        conversationContext: [LLMMessage]
    ) async throws -> Intent
}

/// Labels a sanitised, in-scope message for Chat Orchestrator routing.
/// Never touches `DatabaseManager` or vector storage — pure LLM classification.
nonisolated final class ClassifyIntentUseCase: ClassifyIntentUseCaseProtocol, @unchecked Sendable {
    private let llmClient: LLMClientProtocol

    init(llmClient: LLMClientProtocol) {
        self.llmClient = llmClient
    }

    func execute(
        _ input: String,
        conversationContext: [LLMMessage] = []
    ) async throws -> Intent {
        if let local = LocalMessageClassifier.intentVerdict(for: input) {
            AppLogger.debug("ClassifyIntent local verdict=\(local.rawValue)")
            return local
        }

        let systemPrompt = """
            Classify this personal memory app message. Reply with exactly one word.
            Prior turns (if any) are only for resolving follow-ups like "what about that?".

            STORE — user is sharing a fact, decision, or personal note
            ("I put my passport in the drawer", "We decided on Bali", "I keep my keys on the shelf")

            QUERY — user is asking about something previously stored
            ("Where is my passport?", "What did we decide about the trip?", "Let me know about the trip details")

            MIXED — user asks something needing both stored memory AND general knowledge
            ("What dress ideas did we discuss, and can you suggest more options?")

            CHAT — casual talk, no fact to store or find
            ("Thanks!", "That's helpful", "Good morning")

            Reply with exactly one word: STORE, QUERY, MIXED, or CHAT
            """

        var messages: [LLMMessage] = [
            LLMMessage(role: "system", content: systemPrompt),
        ]
        messages.append(contentsOf: conversationContext)
        messages.append(LLMMessage(role: "user", content: input))

        let result = try await llmClient.complete(
            tier: .nano,
            messages: messages,
            maxTokens: 16,
            temperature: 0
        )

        return Self.parseIntent(result)
    }

    /// Single-word parse; unrecognised → `.chat` (safe default).
    static func parseIntent(_ raw: String) -> Intent {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let token =
            trimmed
            .split(whereSeparator: { $0.isWhitespace || !$0.isLetter })
            .first
            .map(String.init) ?? trimmed
        return Intent(rawValue: token) ?? .chat
    }
}
