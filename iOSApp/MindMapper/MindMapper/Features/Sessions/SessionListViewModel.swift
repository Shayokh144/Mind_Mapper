import Foundation
import Combine

@MainActor
final class SessionListViewModel: ObservableObject {
    @Published private(set) var sessions: [SessionDisplayModel] = []
    @Published var searchText = ""
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var sessionPendingDeletion: SessionDisplayModel?
    @Published var isDeleteConfirmationPresented = false

    private let sessionRepository: SessionRepositoryProtocol
    private let deleteSessionUseCase: DeleteSessionUseCaseProtocol
    private let router: AppRouter
    private let userId: String

    /// Local title filter — no LLM / network.
    var filteredSessions: [SessionDisplayModel] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sessions }
        return sessions.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    init(
        userId: String,
        sessionRepository: SessionRepositoryProtocol,
        deleteSessionUseCase: DeleteSessionUseCaseProtocol,
        router: AppRouter
    ) {
        self.userId = userId
        self.sessionRepository = sessionRepository
        self.deleteSessionUseCase = deleteSessionUseCase
        self.router = router
    }

    func loadSessions() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Drop abandoned drafts (+ then back with no messages).
            try await sessionRepository.purgeEmptySessions(for: userId)
            let fetched = try await sessionRepository.fetchAllWithMessages(for: userId)
            sessions = fetched.map(SessionDisplayModel.init(from:))
        } catch {
            errorMessage = (error as? AppError)?.errorDescription
                ?? L10n.Sessions.loadFailed
        }
    }

    func openSession(_ session: SessionDisplayModel) {
        router.navigate(to: .chat(sessionId: session.id))
    }

    func startNewSession() async {
        errorMessage = nil
        let session = Session(userId: userId)
        do {
            // Persist so messages can FK to this session; list only shows chats with messages.
            try await sessionRepository.save(session)
            router.navigate(to: .chat(sessionId: session.id))
        } catch {
            errorMessage = (error as? AppError)?.errorDescription
                ?? L10n.Sessions.startFailed
        }
    }

    func requestDelete(_ session: SessionDisplayModel) {
        sessionPendingDeletion = session
        isDeleteConfirmationPresented = true
    }

    func confirmDelete() async {
        // Capture before the dialog dismisses — do not clear pending in the
        // `isPresented` setter or confirm runs with a nil session.
        guard let session = sessionPendingDeletion else { return }
        sessionPendingDeletion = nil
        isDeleteConfirmationPresented = false
        errorMessage = nil

        do {
            try await deleteSessionUseCase.execute(sessionId: session.id)
            sessions.removeAll { $0.id == session.id }
        } catch {
            errorMessage = (error as? AppError)?.errorDescription
                ?? L10n.Sessions.deleteFailed
            await loadSessions()
        }
    }

    func cancelDelete() {
        sessionPendingDeletion = nil
        isDeleteConfirmationPresented = false
    }
}
