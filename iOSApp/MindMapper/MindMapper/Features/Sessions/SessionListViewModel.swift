import Foundation
import Combine

/// Minimal session list until task 17 ships display models, search, and row styling.
@MainActor
final class SessionListViewModel: ObservableObject {
    @Published private(set) var sessions: [Session] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let sessionRepository: SessionRepositoryProtocol
    private let router: AppRouter
    private let userId: String

    init(
        userId: String,
        sessionRepository: SessionRepositoryProtocol,
        router: AppRouter
    ) {
        self.userId = userId
        self.sessionRepository = sessionRepository
        self.router = router
    }

    func loadSessions() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            sessions = try await sessionRepository.fetchAll(for: userId)
        } catch {
            errorMessage = (error as? AppError)?.errorDescription
                ?? L10n.Sessions.loadFailed
        }
    }

    func openSession(_ session: Session) {
        router.navigate(to: .chat(sessionId: session.id))
    }

    func startNewSession() async {
        errorMessage = nil
        let session = Session(userId: userId)
        do {
            try await sessionRepository.save(session)
            sessions.insert(session, at: 0)
            router.navigate(to: .chat(sessionId: session.id))
        } catch {
            errorMessage = (error as? AppError)?.errorDescription
                ?? L10n.Sessions.startFailed
        }
    }
}
