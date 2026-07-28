import Foundation

protocol MixedQueryUseCaseProtocol {
    func execute(
        question: String,
        sessionId: String,
        userId: String
    ) async throws -> RAGAnswer
}

/// MIXED pipeline: parallel memory RAG + general knowledge → merged reply.
nonisolated final class MixedQueryUseCase: MixedQueryUseCaseProtocol, @unchecked Sendable {
    private let service: MixedQueryService

    init(service: MixedQueryService) {
        self.service = service
    }

    func execute(
        question: String,
        sessionId: String,
        userId: String
    ) async throws -> RAGAnswer {
        try await service.answer(
            question: question,
            sessionId: sessionId,
            userId: userId
        )
    }
}
