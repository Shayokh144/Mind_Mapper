import Foundation

protocol QueryMemoryUseCaseProtocol {
    func execute(
        question: String,
        sessionId: String,
        userId: String
    ) async throws -> RAGAnswer
}

/// QUERY pipeline: hybrid retrieve → confidence filter → temporal resolve → LLM synthesis.
nonisolated final class QueryMemoryUseCase: QueryMemoryUseCaseProtocol, @unchecked Sendable {
    private let answerService: RAGAnswerServiceProtocol

    init(answerService: RAGAnswerServiceProtocol) {
        self.answerService = answerService
    }

    func execute(
        question: String,
        sessionId: String,
        userId: String
    ) async throws -> RAGAnswer {
        try await answerService.answer(
            question: question,
            sessionId: sessionId,
            userId: userId
        )
    }
}
