import Foundation

/// Layer 2 — LLM scope classification (`.nano`). Call only after `InputSanitiser`.
nonisolated struct ScopeGuard: ScopeGuardProtocol {
    private let llmClient: LLMClient

    private static let systemPrompt = """
        You are a scope guard for a personal memory app.
        The app handles: personal facts, memories, plans, to-dos, decisions, \
        personal or work projects, and questions that help the user plan.

        Prior turns (if any) judge follow-ups in an ongoing personal plan, \
        project, or memory thread. A new errand, task, milestone, link, \
        file path, or plan question in that thread is IN SCOPE.

        OUT OF SCOPE → reply BLOCKED:
        - Asking you to write, debug, or explain source code
        - Homework, essays, translations
        - Trivia unrelated to the user's own plans \
        (sports scores, random quiz facts with no trip, project, or to-do)
        - Medical, legal, or financial advice
        - Asking you to open, fetch live data from, or browse a website \
        the user did not already save

        IN SCOPE → reply ALLOWED:
        - "I put my keys on the kitchen table"
        - "Where is my blue T-shirt?"
        - "We decided to go to Bali in June"
        - "Need to visit the Dhaka outlet for a dress"
        - "Also this shop for a sharee: https://example.com/shop"
        - "Visa PDF is at /Users/me/Documents/visa.pdf"
        - "What's the best time to visit Bangladesh?"
        - "What should I pack for the trip?"
        - "We decided the project ships in October"
        - "Need to finish onboarding for the project"
        - "What did we decide about the project deadline?"
        - "I want to get my wife a gift"
        - "Suggest me some good birthday gift"
        - "Which ASEAN country is good for a budget friendly tour?"
        - "Do you know the link of that facebook page?"
        - "Try again and check if you can find the link"

        URLs and local file paths the user wants to remember are ALLOWED.
        Recalling a stored URL is ALLOWED ("Do you know the link of that facebook page?").
        Retrying a memory question is ALLOWED \
        ("Try again and check if you can find the link").
        "Find the link" means search saved notes, not browse the live web.
        Travel, gift, budget-tour, and project planning questions are ALLOWED.
        Recalling those notes is ALLOWED.
        If a personal detail is missing (who a gift is for, budget, dates), \
        that is still IN SCOPE — the chat may ask, then help.
        Research that helps THEIR plan is ALLOWED even if it needs general knowledge.
        Reply with exactly one word: ALLOWED or BLOCKED
        """

    init(llmClient: LLMClient) {
        self.llmClient = llmClient
    }

    func check(
        _ input: String,
        conversationContext: [LLMMessage] = []
    ) async throws -> ScopeResult {
        if let local = LocalMessageClassifier.scopeVerdict(for: input) {
            switch local {
            case .inScope:
                AppLogger.debug("ScopeGuard local verdict=inScope")
            case .outOfScope:
                AppLogger.debug("ScopeGuard local verdict=outOfScope")
            }
            return local
        }

        var messages: [LLMMessage] = [
            LLMMessage(role: "system", content: Self.systemPrompt),
        ]
        messages.append(contentsOf: conversationContext)
        messages.append(LLMMessage(role: "user", content: input))

        let result = try await llmClient.complete(
            tier: .nano,
            messages: messages,
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
