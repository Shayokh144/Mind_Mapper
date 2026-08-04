import Foundation

protocol UpdateChatSessionUseCaseProtocol {
    /// Persists title and/or topic tag. Does not call the LLM.
    func updateMetadata(sessionId: String, title: String?, topicTag: Session.Topic?) async throws
    /// Pins or unpins a session. Multiple sessions may be pinned.
    func setPinned(sessionId: String, isPinned: Bool) async throws
}

nonisolated final class UpdateChatSessionUseCase: UpdateChatSessionUseCaseProtocol, @unchecked Sendable {
    private let sessionRepository: SessionRepositoryProtocol

    init(sessionRepository: SessionRepositoryProtocol) {
        self.sessionRepository = sessionRepository
    }

    func updateMetadata(sessionId: String, title: String?, topicTag: Session.Topic?) async throws {
        guard var session = try await sessionRepository.fetch(id: sessionId) else {
            throw AppError.notFound(entityType: "session", id: sessionId)
        }
        session.title = title
        session.topicTag = topicTag
        session.updatedAt = Date()
        try await sessionRepository.update(session)
    }

    func setPinned(sessionId: String, isPinned: Bool) async throws {
        guard var session = try await sessionRepository.fetch(id: sessionId) else {
            throw AppError.notFound(entityType: "session", id: sessionId)
        }
        session.isPinned = isPinned
        session.updatedAt = Date()
        try await sessionRepository.update(session)
    }
}
