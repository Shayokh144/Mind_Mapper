import Foundation

/// MIXED intent: personal memories + general knowledge, merged into one reply.
nonisolated struct MixedQueryService: @unchecked Sendable {
    private let ragAnswerService: RAGAnswerServiceProtocol
    private let llmClient: LLMClientProtocol

    init(
        ragAnswerService: RAGAnswerServiceProtocol,
        llmClient: LLMClientProtocol
    ) {
        self.ragAnswerService = ragAnswerService
        self.llmClient = llmClient
    }

    func answer(
        question: String,
        sessionId: String,
        userId: String,
        conversationContext: [LLMMessage] = []
    ) async throws -> RAGAnswer {
        async let memoryTask = ragAnswerService.answer(
            question: question,
            sessionId: sessionId,
            userId: userId
        )
        async let generalTask = llmClient.complete(
            tier: .full,
            messages: [
                LLMMessage(
                    role: "system",
                    content: """
                    You are a knowledgeable assistant. Answer with general knowledge only. \
                    Be concise. Do not invent the user's personal facts or constraints \
                    (who a gift is for, budget amount, dates, group size, etc.). \
                    If a personal detail would change the answer and is missing, \
                    say which detail is unknown — do not invent it.
                    """
                ),
                LLMMessage(role: "user", content: question),
            ],
            maxTokens: 300,
            temperature: 0.6
        )

        let memoryAnswer = try await memoryTask
        let general = try await generalTask
        let mergePrompt = Self.mergePrompt(
            question: question,
            memoryText: memoryAnswer.text,
            general: general,
            conversationContext: conversationContext
        )

        let merged = try await llmClient.complete(
            tier: .mini,
            messages: [LLMMessage(role: "user", content: mergePrompt)],
            maxTokens: 280,
            temperature: 0.2
        )
        let trimmed = merged.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AppError.llmResponseInvalid }

        return RAGAnswer(
            text: trimmed,
            representedSessionIds: memoryAnswer.representedSessionIds
        )
    }

    private static func mergePrompt(
        question: String,
        memoryText: String,
        general: String,
        conversationContext: [LLMMessage]
    ) -> String {
        let prior = conversationContext
            .map { "\($0.role): \($0.content)" }
            .joined(separator: "\n")
        let priorBlock = prior.isEmpty ? "(none)" : prior

        return """
        The user asked: "\(question)"

        Prior turns:
        \(priorBlock)

        Here is what was found in their personal memories:
        \(memoryText)

        Here is general knowledge on the topic:
        \(general)

        Rules:
        - If they asked what they already planned, decided, or stored: answer from \
        memories only. Ignore general knowledge. Use a short lead-in and a bullet list. \
        Do not suggest extra destinations or ideas.
        - If they asked for help choosing or planning (gifts, destinations, budget \
        trips, packing, project next steps, etc.): use memories and prior turns first, \
        then general knowledge.
        - Give a useful answer when the question already has enough to go on \
        (e.g. a budget-friendly ASEAN tour). Do not refuse just because extra \
        details would be nice.
        - Ask short clarifying questions only for missing facts that would \
        change the answer a lot. Ask only what that question needs \
        (gift → who / age / gender / preferences; trip → dates / budget / \
        group size / interests). Do not mix those checklists.
        - Do not dump a long generic list when the request is too vague to answer well.
        - Keep names, places, and URLs from memories exactly. Copy full URLs; \
        never replace a stored link with a paraphrase.
        - Keep the reply short. No travel-brochure prose.
        """
    }
}
