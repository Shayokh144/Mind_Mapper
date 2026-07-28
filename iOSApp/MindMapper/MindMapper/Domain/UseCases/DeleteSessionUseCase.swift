import Foundation

protocol DeleteSessionUseCaseProtocol: Sendable {
    func execute(sessionId: String) async throws
}

/// Deletes a session and all dependent rows in FK-safe order (single write transaction).
nonisolated struct DeleteSessionUseCase: DeleteSessionUseCaseProtocol {
    private let sessionRepository: SessionRepositoryProtocol

    init(sessionRepository: SessionRepositoryProtocol) {
        self.sessionRepository = sessionRepository
    }

    func execute(sessionId: String) async throws {
        try await sessionRepository.deleteCascade(id: sessionId)
    }
}
