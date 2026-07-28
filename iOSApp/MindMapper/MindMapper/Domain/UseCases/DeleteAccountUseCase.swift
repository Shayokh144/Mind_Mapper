import Foundation

@MainActor
protocol DeleteAccountUseCaseProtocol: AnyObject {
    func execute(userId: String) async throws
}

/// GDPR-style erasure: every session (cascade) → local user row → sign out.
@MainActor
final class DeleteAccountUseCase: DeleteAccountUseCaseProtocol {
    private let sessionRepository: SessionRepositoryProtocol
    private let deleteSessionUseCase: DeleteSessionUseCaseProtocol
    private let authRepository: AuthRepositoryProtocol
    private let authManager: AuthManagerProtocol

    init(
        sessionRepository: SessionRepositoryProtocol,
        deleteSessionUseCase: DeleteSessionUseCaseProtocol,
        authRepository: AuthRepositoryProtocol,
        authManager: AuthManagerProtocol
    ) {
        self.sessionRepository = sessionRepository
        self.deleteSessionUseCase = deleteSessionUseCase
        self.authRepository = authRepository
        self.authManager = authManager
    }

    func execute(userId: String) async throws {
        let sessions = try await sessionRepository.fetchAll(for: userId)
        for session in sessions {
            try await deleteSessionUseCase.execute(sessionId: session.id)
        }
        try await sessionRepository.purgeEmptySessions(for: userId)
        try await authRepository.delete(id: userId)
        try await authManager.signOut()
    }
}
