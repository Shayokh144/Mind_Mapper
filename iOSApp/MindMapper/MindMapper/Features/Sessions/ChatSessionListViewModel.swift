import Foundation
import Combine

@MainActor
final class ChatSessionListViewModel: ObservableObject {
    static let maxTitleLength = 100
    static let maxTagLength = 32

    @Published private(set) var sessions: [ChatSessionDisplayModel] = []
    @Published var searchText = ""
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var sessionPendingDeletion: ChatSessionDisplayModel?
    @Published var isDeleteConfirmationPresented = false

    /// Bottom sheet for title + tag (opened from rename or update-tag menu).
    @Published var isEditSheetPresented = false
    @Published var editTitleText = ""
    @Published var editTagText = ""
    @Published private(set) var sessionPendingEdit: ChatSessionDisplayModel?
    @Published private(set) var isSavingEdit = false

    private let sessionRepository: SessionRepositoryProtocol
    private let deleteSessionUseCase: DeleteSessionUseCaseProtocol
    private let updateChatSessionUseCase: UpdateChatSessionUseCaseProtocol
    private let router: AppRouter
    private let userId: String

    /// Local title filter — no LLM / network.
    var filteredSessions: [ChatSessionDisplayModel] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sessions }
        return sessions.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || ($0.topicTag?.localizedCaseInsensitiveContains(query) == true)
        }
    }

    /// Save enabled when at least one field has content.
    var canSaveEdit: Bool {
        let title = editTitleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let tag = editTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !title.isEmpty || !tag.isEmpty
    }

    init(
        userId: String,
        sessionRepository: SessionRepositoryProtocol,
        deleteSessionUseCase: DeleteSessionUseCaseProtocol,
        updateChatSessionUseCase: UpdateChatSessionUseCaseProtocol,
        router: AppRouter
    ) {
        self.userId = userId
        self.sessionRepository = sessionRepository
        self.deleteSessionUseCase = deleteSessionUseCase
        self.updateChatSessionUseCase = updateChatSessionUseCase
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
            sessions = fetched.map(ChatSessionDisplayModel.init(from:))
        } catch {
            errorMessage = (error as? AppError)?.errorDescription
                ?? L10n.Sessions.loadFailed
        }
    }

    func openSession(_ session: ChatSessionDisplayModel) {
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

    // MARK: - Delete

    func requestDelete(_ session: ChatSessionDisplayModel) {
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

    // MARK: - Edit title / tag (no LLM)

    func presentEditSheet(for session: ChatSessionDisplayModel) {
        sessionPendingEdit = session
        editTitleText = session.editableTitle
        editTagText = session.topicTag ?? ""
        isEditSheetPresented = true
    }

    func cancelEdit() {
        isEditSheetPresented = false
        clearEditState()
    }

    func clearEditState() {
        sessionPendingEdit = nil
        editTitleText = ""
        editTagText = ""
    }

    func saveEdit() async {
        guard let session = sessionPendingEdit else { return }
        let trimmedTitle = editTitleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTag = editTagText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Both empty → do not save.
        guard !trimmedTitle.isEmpty || !trimmedTag.isEmpty else {
            errorMessage = L10n.Sessions.editEmptyError
            return
        }

        isSavingEdit = true
        errorMessage = nil
        defer { isSavingEdit = false }

        let titleToStore: String? = trimmedTitle.isEmpty ? nil : trimmedTitle
        let topic: Session.Topic? = Session.Topic(stored: trimmedTag)

        do {
            try await updateChatSessionUseCase.updateMetadata(
                sessionId: session.id,
                title: titleToStore,
                topicTag: topic
            )
            isEditSheetPresented = false
            clearEditState()
            await loadSessions()
        } catch {
            errorMessage = (error as? AppError)?.errorDescription
                ?? L10n.Sessions.editSaveFailed
        }
    }

    // MARK: - Pin

    func togglePin(_ session: ChatSessionDisplayModel) async {
        errorMessage = nil
        do {
            try await updateChatSessionUseCase.setPinned(
                sessionId: session.id,
                isPinned: !session.isPinned
            )
            await loadSessions()
        } catch {
            errorMessage = (error as? AppError)?.errorDescription
                ?? L10n.Sessions.pinFailed
        }
    }
}
