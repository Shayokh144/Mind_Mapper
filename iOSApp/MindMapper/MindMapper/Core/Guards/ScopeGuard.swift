import Foundation

/// Layer 2 — LLM scope classification (`.nano`). Call only after `InputSanitiser`.
nonisolated struct ScopeGuard: ScopeGuardProtocol {
    private let llmClient: LLMClient

    init(llmClient: LLMClient) {
        self.llmClient = llmClient
    }

    func check(_ input: String) async throws -> ScopeResult {
        if let local = LocalMessageClassifier.scopeVerdict(for: input) {
            switch local {
            case .inScope:
                AppLogger.debug("ScopeGuard local verdict=inScope")
            case .outOfScope:
                AppLogger.debug("ScopeGuard local verdict=outOfScope")
            }
            return local
        }

        let systemPrompt = """
        You are a strict scope guard for a personal memory app.
        The app ONLY handles: personal facts, personal memories, personal plans, \
        personal decisions, and personal discussions.

        OUT OF SCOPE → reply BLOCKED:
        - Code debugging or writing
        - Homework, essays, translations
        - General trivia or world knowledge questions
        - Medical, legal, or financial advice
        - Anything not about the user's own personal life and memories

        IN SCOPE → reply ALLOWED:
        - "I put my keys on the kitchen table"
        - "Where is my blue T-shirt?"
        - "We decided to go to Bali in June"
        - "What dress should I wear for my presentation"
        - "I want to get my wife a gift"

        Reply with exactly one word: ALLOWED or BLOCKED
        """

        let result = try await llmClient.complete(
            tier: .nano,
            messages: [
                LLMMessage(role: "system", content: systemPrompt),
                LLMMessage(role: "user", content: input),
            ],
            maxTokens: 16,
            temperature: 0
        )

        let verdict = result.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if verdict.contains("ALLOWED") {
            return .inScope
        }
        return .outOfScope(L10n.Guard.scopeBlocked)
    }
}
