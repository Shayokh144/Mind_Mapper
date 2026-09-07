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
            Prior turns (if any) resolve follow-ups like "what about that?" \
            or "try again and find the link". Treat those as QUERY when the \
            thread was recalling stored notes. Treat new to-dos as STORE in a \
            planning thread. Treat plan-research questions (timing, weather, \
            packing, budget destinations, gift ideas, project next steps) as MIXED.

            STORE — sharing a fact, decision, note, trip or project plan, to-do, or file path
            ("I put my passport in the drawer", "We decided on Bali", \
            "Need to visit the outlet for a dress", \
            "We decided the project ships in October", \
            "Also this shop for a sharee: https://example.com/shop")

            QUERY — asking only about something previously stored. Do not use MIXED \
            just because the question mentions a trip or project.
            ("Where is my passport?", "What did we decide about the trip?", \
            "What do I need to do in Bangladesh?", \
            "What things I planned to do when I visit Bangladesh next year", \
            "What did we decide about the project deadline?", \
            "Do you know the link of that facebook page?", \
            "Try again and check if you can find the link")

            MIXED — user asks for stored memory AND/OR new suggestions or general knowledge
            ("What dress ideas did we discuss, and can you suggest more options?", \
            "What's the best time to visit Bangladesh?", \
            "What should I pack for the trip?", \
            "What's a sensible order for the remaining project tasks?", \
            "Suggest me some good birthday gift", \
            "Which ASEAN country is good for a budget friendly tour?")

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
