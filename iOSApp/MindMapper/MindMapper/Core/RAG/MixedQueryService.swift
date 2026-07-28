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
        userId: String
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
                    You are a knowledgeable assistant. Answer this question with general \
                    knowledge only. Be concise. Do not invent the user's personal facts.
                    """
                ),
                LLMMessage(role: "user", content: question),
            ],
            maxTokens: 300,
            temperature: 0.6
        )

        let memoryAnswer = try await memoryTask
        let general = try await generalTask

        let mergePrompt = """
        The user asked: "\(question)"

        Here is what was found in their personal memories:
        \(memoryAnswer.text)

        Here is general knowledge on the topic:
        \(general)

        Write a single, natural response that:
        1. Starts with what the user has already discussed or decided (from their memories)
        2. Then adds new general suggestions or information
        3. Keeps it conversational, not a list unless natural
        """

        let merged = try await llmClient.complete(
            tier: .mini,
            messages: [LLMMessage(role: "user", content: mergePrompt)],
            maxTokens: 400,
            temperature: 0.5
        )
        let trimmed = merged.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AppError.llmResponseInvalid }

        return RAGAnswer(
            text: trimmed,
            representedSessionIds: memoryAnswer.representedSessionIds
        )
    }
}
