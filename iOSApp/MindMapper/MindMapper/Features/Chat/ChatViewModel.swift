import Combine
import Foundation

/// Chat orchestrator — guards → intent → STORE / QUERY / MIXED / CHAT pipelines.
@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [MessageDisplayModel] = []
    @Published private(set) var currentSession: Session?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var inputText = ""
    /// Distinct sessions represented in the last QUERY/MIXED answer (ThemeBadge when > 1).
    @Published private(set) var lastAnswerSessionCount = 0
    @Published var isDeleteConfirmationPresented = false
    /// True while the input bar is editing the incomplete last user turn.
    @Published private(set) var isEditingFailedTurn = false

    private let dependencies: ChatDependencies
    private let deleteSessionUseCase: DeleteSessionUseCaseProtocol
    private let router: AppRouter
    private var sessionId: String
    private let userId: String
    private let inactivityInterval: TimeInterval
    private let inputMaxLength = 500

    private var inactivityTask: Task<Void, Never>?
    private var pipelineTask: Task<Void, Never>?
    private var isClosingSession = false
    /// Bumped when a send/retry starts so an in-flight close abandons before applying results.
    private var closeGeneration = 0
    /// Bumped on each send/retry/stop so late pipeline results are ignored after cancel.
    private var pipelineGeneration = 0
    /// True after new turns until a successful close (avoids duplicate summary embeddings).
    private var needsSessionClose = false

    /// Exposed for UI that needs to push related screens (task 16+).
    var appRouter: AppRouter { router }

    var charactersRemaining: Int {
        max(0, inputMaxLength - inputText.count)
    }

    var isCharacterCountWarning: Bool {
        charactersRemaining < 50
    }

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    var showsCrossSessionBadge: Bool {
        lastAnswerSessionCount > 1
    }

    /// Last bubble is a user turn with no assistant reply yet (failed / interrupted).
    /// Survives leaving and reopening the chat because it is derived from message history.
    var canRetryLastTurn: Bool {
        guard !isLoading, !isEditingFailedTurn else { return false }
        return messages.last?.isUser == true
    }

    var lastFailedUserMessage: MessageDisplayModel? {
        guard canRetryLastTurn else { return nil }
        return messages.last
    }

    init(
        sessionId: String,
        userId: String,
        dependencies: ChatDependencies,
        deleteSessionUseCase: DeleteSessionUseCaseProtocol,
        router: AppRouter,
        inactivityInterval: TimeInterval = 120
    ) {
        self.sessionId = sessionId
        self.userId = userId
        self.dependencies = dependencies
        self.deleteSessionUseCase = deleteSessionUseCase
        self.router = router
        self.inactivityInterval = inactivityInterval
    }

    deinit {
        inactivityTask?.cancel()
        pipelineTask?.cancel()
    }

    // MARK: - Session lifecycle

    func loadSession() async {
        errorMessage = nil
        isEditingFailedTurn = false
        do {
            if let session = try await dependencies.sessionRepository.fetch(id: sessionId) {
                currentSession = session
            }
            let stored = try await dependencies.messageRepository.fetchAll(for: sessionId)
            messages = stored.map { MessageDisplayModel(from: $0) }
            // Unclosed sessions with history should still close on leave / background.
            if currentSession?.title == nil, !stored.isEmpty {
                needsSessionClose = true
            }
            if messages.last?.isUser == true {
                errorMessage = L10n.Chat.incompleteTurn
            }
        } catch {
            errorMessage = mapError(error)
        }
    }

    func loadSession(_ session: Session) async {
        inactivityTask?.cancel()
        sessionId = session.id
        currentSession = session
        needsSessionClose = false
        await loadSession()
    }

    @discardableResult
    func startNewSession(userId: String) async throws -> Session {
        inactivityTask?.cancel()
        let session = Session(userId: userId)
        try await dependencies.sessionRepository.save(session)
        sessionId = session.id
        currentSession = session
        messages = []
        lastAnswerSessionCount = 0
        errorMessage = nil
        isEditingFailedTurn = false
        needsSessionClose = false
        return session
    }

    /// Triggered by ChatView `.onDisappear`.
    func onLeaveChat() async {
        if await isEmptyDraft() {
            await discardEmptySession()
            return
        }
        await closeSession()
    }

    /// Triggered by ChatView `.onDisappear`, app background, or inactivity.
    func closeSession() async {
        // Never run close (LLM + DB) while send/retry is in flight — concurrent
        // Edge Function calls and cancelled DB reads leave the UI stuck loading.
        guard !isLoading else { return }
        guard needsSessionClose, !isClosingSession else { return }
        isClosingSession = true
        let generation = closeGeneration
        inactivityTask?.cancel()
        inactivityTask = nil
        defer { isClosingSession = false }

        do {
            try await dependencies.closeSessionUseCase.execute(sessionId: sessionId)
            guard generation == closeGeneration, !isLoading else { return }
            needsSessionClose = false
            currentSession = try await dependencies.sessionRepository.fetch(id: sessionId)
        } catch {
            if Self.isCancellation(error) { return }
            AppLogger.error("Session close failed for \(sessionId)", error: error)
        }
    }

    func openMemories() {
        router.navigate(to: .memoryList(sessionId: sessionId))
    }

    func requestDeleteConversation() {
        isDeleteConfirmationPresented = true
    }

    func confirmDeleteConversation() async {
        isDeleteConfirmationPresented = false
        inactivityTask?.cancel()
        needsSessionClose = false
        errorMessage = nil

        do {
            try await deleteSessionUseCase.execute(sessionId: sessionId)
            router.navigateBack()
        } catch {
            errorMessage = (error as? AppError)?.errorDescription
                ?? L10n.Sessions.deleteFailed
        }
    }

    // MARK: - Send / retry / stop

    func sendMessage(_ rawInput: String? = nil) async {
        guard !isLoading else { return }
        let task = Task { await self.performSend(rawInput) }
        pipelineTask = task
        await task.value
        if pipelineTask == task {
            pipelineTask = nil
        }
    }

    /// Cancels the in-flight reply and ignores any late result. Prefills the last
    /// user message so the user can edit and send again.
    func stopGenerating() {
        guard isLoading else { return }
        invalidatePipeline()
        isLoading = false
        errorMessage = nil
        if let last = messages.last, last.isUser {
            inputText = last.content
            isEditingFailedTurn = true
        }
    }

    func retryLastTurn() async {
        guard let last = messages.last, last.isUser, !isLoading else { return }
        isEditingFailedTurn = false
        let task = Task { await self.performRetry(content: last.content) }
        pipelineTask = task
        await task.value
        if pipelineTask == task {
            pipelineTask = nil
        }
    }

    func beginEditFailedTurn() {
        guard let last = messages.last, last.isUser, !isLoading else { return }
        inputText = last.content
        isEditingFailedTurn = true
        errorMessage = nil
    }

    func cancelEditFailedTurn() {
        isEditingFailedTurn = false
        inputText = ""
        if messages.last?.isUser == true {
            errorMessage = L10n.Chat.incompleteTurn
        }
    }

    // MARK: - Private send helpers

    private func performSend(_ rawInput: String?) async {
        if isEditingFailedTurn {
            await submitEditedFailedTurn(rawInput)
            return
        }

        let raw = (rawInput ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }

        if rawInput == nil {
            inputText = ""
        }
        let generation = beginPipeline()
        defer { endPipelineIfCurrent(generation) }

        guard let sanitised = prepareSanitisedInput(raw) else { return }

        let userMessage = Message(sessionId: sessionId, role: "user", content: raw)
        do {
            try await dependencies.messageRepository.save(userMessage)
            guard isPipelineActive(generation) else { return }
            messages.append(MessageDisplayModel(from: userMessage))
            markActivityForSessionClose()
        } catch {
            if isPipelineActive(generation) {
                errorMessage = mapError(error)
            }
            return
        }

        await runPipeline(sanitised: sanitised, generation: generation)
    }

    private func performRetry(content: String) async {
        let generation = beginPipeline()
        defer { endPipelineIfCurrent(generation) }

        guard let sanitised = prepareSanitisedInput(content) else { return }
        markActivityForSessionClose()
        await runPipeline(sanitised: sanitised, generation: generation)
    }

    private func submitEditedFailedTurn(_ rawInput: String?) async {
        guard let last = messages.last, last.isUser else {
            isEditingFailedTurn = false
            await performSend(rawInput)
            return
        }

        let raw = (rawInput ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }

        let generation = beginPipeline()
        defer { endPipelineIfCurrent(generation) }

        guard let sanitised = prepareSanitisedInput(raw) else { return }

        let updated = Message(
            id: last.id,
            sessionId: sessionId,
            role: "user",
            content: raw,
            createdAt: last.createdAt
        )
        do {
            try await dependencies.messageRepository.update(updated)
            guard isPipelineActive(generation) else { return }
            messages[messages.count - 1] = MessageDisplayModel(from: updated)
            inputText = ""
            isEditingFailedTurn = false
            markActivityForSessionClose()
        } catch {
            if isPipelineActive(generation) {
                errorMessage = mapError(error)
            }
            return
        }

        await runPipeline(sanitised: sanitised, generation: generation)
    }

    /// Marks the chat busy and bumps the close generation so an in-flight
    /// `closeSession` will not finish / steal LLM capacity.
    private func beginPipeline() -> Int {
        closeGeneration += 1
        pipelineGeneration += 1
        isLoading = true
        errorMessage = nil
        lastAnswerSessionCount = 0
        return pipelineGeneration
    }

    private func endPipelineIfCurrent(_ generation: Int) {
        if generation == pipelineGeneration {
            isLoading = false
        }
    }

    private func invalidatePipeline() {
        pipelineGeneration += 1
        pipelineTask?.cancel()
        pipelineTask = nil
    }

    private func isPipelineActive(_ generation: Int) -> Bool {
        generation == pipelineGeneration && !Task.isCancelled
    }

    /// Rate limit + sanitise. Sets `errorMessage` and returns `nil` on block.
    private func prepareSanitisedInput(_ raw: String) -> String? {
        if case .throttled(let message) = dependencies.rateLimiter.check() {
            errorMessage = message
            return nil
        }

        let sanitiseResult = InputSanitiser.process(raw)
        guard case .allowed(let sanitised) = sanitiseResult else {
            if case .blocked(let reason) = sanitiseResult {
                dependencies.rateLimiter.recordBlocked()
                errorMessage = reason
            }
            return nil
        }
        return sanitised
    }

    private func runPipeline(sanitised: String, generation: Int) async {
        do {
            let scope = try await dependencies.scopeGuard.check(sanitised)
            guard isPipelineActive(generation) else { return }
            if case .outOfScope(let reason) = scope {
                dependencies.rateLimiter.recordBlocked()
                await appendAssistant(content: reason, isWarning: true, generation: generation)
                return
            }
        } catch {
            guard isPipelineActive(generation) else { return }
            if !Self.isCancellation(error) {
                errorMessage = mapError(error)
            }
            return
        }

        dependencies.rateLimiter.recordAllowed()

        do {
            let intent = try await dependencies.classifyIntentUseCase.execute(sanitised)
            guard isPipelineActive(generation) else { return }
            let reply = try await route(intent: intent, text: sanitised)
            guard isPipelineActive(generation) else { return }
            await appendAssistant(content: reply, generation: generation)
        } catch {
            guard isPipelineActive(generation) else { return }
            if Self.isCancellation(error) {
                errorMessage = L10n.Chat.incompleteTurn
            } else {
                errorMessage = mapError(error)
            }
        }
    }

    private func isEmptyDraft() async -> Bool {
        if !messages.isEmpty { return false }
        do {
            let stored = try await dependencies.messageRepository.fetchAll(for: sessionId)
            return stored.isEmpty
        } catch {
            return true
        }
    }

    private func discardEmptySession() async {
        inactivityTask?.cancel()
        needsSessionClose = false
        do {
            try await deleteSessionUseCase.execute(sessionId: sessionId)
        } catch {
            AppLogger.error("Failed to discard empty session \(sessionId)", error: error)
        }
    }

    private func markActivityForSessionClose() {
        needsSessionClose = true
        resetInactivityTimer()
    }

    private func resetInactivityTimer() {
        inactivityTask?.cancel()
        let interval = inactivityInterval
        inactivityTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            // Drop the timer reference before close so closeSession's cancel
            // does not cancel this task mid-execute (self-cancellation bug).
            await self?.fireInactivityClose()
        }
    }

    private func fireInactivityClose() async {
        inactivityTask = nil
        await closeSession()
    }

    private func route(intent: Intent, text: String) async throws -> String {
        switch intent {
        case .store:
            return try await dependencies.saveMemoryUseCase.execute(
                text: text,
                sessionId: sessionId,
                userId: userId
            )
        case .query:
            let answer = try await dependencies.queryMemoryUseCase.execute(
                question: text,
                sessionId: sessionId,
                userId: userId
            )
            lastAnswerSessionCount = answer.representedSessionIds.count
            return answer.text
        case .mixed:
            let answer = try await dependencies.mixedQueryUseCase.execute(
                question: text,
                sessionId: sessionId,
                userId: userId
            )
            lastAnswerSessionCount = answer.representedSessionIds.count
            return answer.text
        case .chat:
            return try await dependencies.llmClient.complete(
                tier: .mini,
                messages: [
                    LLMMessage(
                        role: "system",
                        content: """
                            You are a friendly personal memory assistant. Keep casual replies brief.
                            """
                    ),
                    LLMMessage(role: "user", content: text),
                ],
                maxTokens: 200,
                temperature: 0.7
            )
        }
    }

    private func appendAssistant(
        content: String,
        isWarning: Bool = false,
        generation: Int
    ) async {
        guard isPipelineActive(generation) else { return }
        let message = Message(sessionId: sessionId, role: "assistant", content: content)
        let display = MessageDisplayModel(from: message, isWarning: isWarning)
        do {
            try await dependencies.messageRepository.save(message)
            guard isPipelineActive(generation) else { return }
            messages.append(display)
        } catch {
            guard isPipelineActive(generation) else { return }
            // Still show the bubble if persistence fails
            messages.append(display)
            if errorMessage == nil {
                errorMessage = mapError(error)
            }
        }
    }

    private func mapError(_ error: Error) -> String {
        if let appError = error as? AppError {
            return appError.errorDescription ?? L10n.Error.generic
        }
        return AppError.llmCallFailed(underlying: error).errorDescription
            ?? L10n.Error.generic
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let appError = error as? AppError {
            switch appError {
            case let .loadFailed(underlying),
                 let .saveFailed(underlying),
                 let .llmCallFailed(underlying):
                return underlying is CancellationError
            default:
                return false
            }
        }
        return false
    }
}
