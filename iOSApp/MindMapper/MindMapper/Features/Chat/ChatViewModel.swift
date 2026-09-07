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
    @Published var pendingReminderOffer: ReminderOfferDisplayModel?
    @Published var showReminderPermissionPrePrompt = false
    @Published var showNotificationDeniedHelp = false

    let dependencies: ChatDependencies
    private let deleteSessionUseCase: DeleteSessionUseCaseProtocol
    let router: AppRouter
    var sessionId: String
    private let userId: String
    private let inactivityInterval: TimeInterval
    private let inputMaxLength = ChatLimits.maxCharactersPerMessage

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
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isLoading
            && !isSessionAtMessageLimit
    }

    /// True when the next user+assistant pair would exceed `ChatLimits.maxMessagesPerSession`.
    var isSessionAtMessageLimit: Bool {
        ChatLimits.isAtMessageLimit(currentCount: messages.count)
    }

    var sessionMessageUsedCount: Int { messages.count }

    var sessionMessageRemainingCount: Int {
        ChatLimits.remainingMessageSlots(currentCount: messages.count)
    }

    var showsCrossSessionBadge: Bool {
        lastAnswerSessionCount > 1
    }

    /// Last bubble is a failed user turn: no assistant reply, or a scope-block warning.
    /// Survives leaving and reopening the chat because it is derived from message history.
    var canRetryLastTurn: Bool {
        guard !isLoading, !isEditingFailedTurn else { return false }
        return failedTurnUserMessage() != nil
    }

    var lastFailedUserMessage: MessageDisplayModel? {
        guard canRetryLastTurn else { return nil }
        return failedTurnUserMessage()
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
            } else if ChatLimits.isAtMessageLimit(currentCount: messages.count) {
                errorMessage = L10n.Chat.sessionFull
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
        guard let user = failedTurnUserMessage(), !isLoading else { return }
        isEditingFailedTurn = false
        let content = user.content
        await removeTrailingScopeWarning()
        let task = Task { await self.performRetry(content: content) }
        pipelineTask = task
        await task.value
        if pipelineTask == task {
            pipelineTask = nil
        }
    }

    func beginEditFailedTurn() {
        guard let user = failedTurnUserMessage(), !isLoading else { return }
        inputText = user.content
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

        let fromComposer = rawInput == nil
        let raw = (rawInput ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }

        if isSessionAtMessageLimit {
            errorMessage = L10n.Chat.sessionFull
            return
        }

        let generation = beginPipeline()
        defer { endPipelineIfCurrent(generation) }

        guard let sanitised = prepareSanitisedInput(raw) else { return }

        if fromComposer {
            inputText = ""
        }

        let userMessage = Message(sessionId: sessionId, role: "user", content: raw)
        do {
            try await dependencies.messageRepository.save(userMessage)
            guard isPipelineActive(generation) else { return }
            messages.append(MessageDisplayModel(from: userMessage))
            markActivityForSessionClose()
        } catch {
            if isPipelineActive(generation) {
                if fromComposer {
                    inputText = raw
                }
                errorMessage = mapError(error)
            }
            return
        }

        await runPipeline(sanitised: sanitised, generation: generation)
    }

    private func performRetry(content: String) async {
        // Incomplete user row already exists — only need one slot for the assistant reply.
        if messages.count >= ChatLimits.maxMessagesPerSession {
            errorMessage = L10n.Chat.sessionFull
            return
        }

        let generation = beginPipeline()
        defer { endPipelineIfCurrent(generation) }

        guard let sanitised = prepareSanitisedInput(content) else { return }
        markActivityForSessionClose()
        await runPipeline(sanitised: sanitised, generation: generation)
    }

    private func submitEditedFailedTurn(_ rawInput: String?) async {
        guard let user = failedTurnUserMessage() else {
            isEditingFailedTurn = false
            await performSend(rawInput)
            return
        }

        let raw = (rawInput ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }

        // Editing replaces an existing user row — does not add a new slot.
        let generation = beginPipeline()
        defer { endPipelineIfCurrent(generation) }

        guard let sanitised = prepareSanitisedInput(raw) else { return }

        await removeTrailingScopeWarning()

        let updated = Message(
            id: user.id,
            sessionId: sessionId,
            role: "user",
            content: raw,
            createdAt: user.createdAt
        )
        do {
            try await dependencies.messageRepository.update(updated)
            guard isPipelineActive(generation) else { return }
            if let index = messages.firstIndex(where: { $0.id == user.id }) {
                messages[index] = MessageDisplayModel(from: updated)
            }
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
        pendingReminderOffer = nil
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
        let classifyContext = rollingLLMContext(
            limit: ChatLimits.intentContextMessageCount,
            excludingCurrentText: sanitised
        )
        do {
            let scope = try await dependencies.scopeGuard.check(
                sanitised,
                conversationContext: classifyContext
            )
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
            let intent = try await dependencies.classifyIntentUseCase.execute(
                sanitised,
                conversationContext: classifyContext
            )
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
        let storeContext = rollingLLMContext(
            limit: ChatLimits.rollingContextMessageCount,
            excludingCurrentText: text
        )

        switch intent {
        case .store:
            let result = try await dependencies.saveMemoryUseCase.execute(
                text: text,
                sessionId: sessionId,
                userId: userId,
                conversationContext: storeContext
            )
            applyReminderProposal(result.reminderProposal, memoryId: result.memoryId)
            return result.ackText
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
                userId: userId,
                conversationContext: storeContext
            )
            lastAnswerSessionCount = answer.representedSessionIds.count
            return answer.text
        case .chat:
            var llmMessages: [LLMMessage] = [
                LLMMessage(
                    role: "system",
                    content: """
                        You are a friendly personal memory assistant. Keep casual replies brief.
                        Use prior turns for coherence when the user refers to earlier messages.
                        """
                ),
            ]
            llmMessages.append(contentsOf: storeContext)
            llmMessages.append(LLMMessage(role: "user", content: text))
            return try await dependencies.llmClient.complete(
                tier: .mini,
                messages: llmMessages,
                maxTokens: 200,
                temperature: 0.7
            )
        }
    }

    /// Domain messages for the current session UI list (same order as bubbles).
    private func domainMessages() -> [Message] {
        messages.map {
            Message(
                id: $0.id,
                sessionId: sessionId,
                role: $0.role,
                content: $0.content,
                createdAt: $0.createdAt
            )
        }
    }

    /// Rolling LLM history without duplicating the current user turn.
    private func rollingLLMContext(
        limit: Int,
        excludingCurrentText: String
    ) -> [LLMMessage] {
        let rolling = ChatLimits.rollingContext(from: domainMessages(), limit: limit)
        return ChatLimits.llmMessagesExcludingTrailingUser(
            from: rolling,
            currentText: excludingCurrentText
        )
    }

    /// User bubble to retry: last user turn, or the user turn before a scope warning.
    private func failedTurnUserMessage() -> MessageDisplayModel? {
        if let last = messages.last, last.isUser { return last }
        guard messages.count >= 2,
              let last = messages.last, last.isWarning, last.isAssistant,
              messages[messages.count - 2].isUser
        else { return nil }
        return messages[messages.count - 2]
    }

    private var hasTrailingScopeWarning: Bool {
        failedTurnUserMessage() != nil && messages.last?.isWarning == true
    }

    private func removeTrailingScopeWarning() async {
        guard hasTrailingScopeWarning, let warning = messages.last else { return }
        messages.removeLast()
        do {
            try await dependencies.messageRepository.delete(id: warning.id)
        } catch {
            AppLogger.error("Failed to delete scope-warning message \(warning.id)", error: error)
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
