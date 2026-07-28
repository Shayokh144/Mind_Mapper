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

    private let dependencies: ChatDependencies
    private let router: AppRouter
    private var sessionId: String
    private let userId: String

    /// Exposed for UI that needs to push related screens (task 16+).
    var appRouter: AppRouter { router }

    init(
        sessionId: String,
        userId: String,
        dependencies: ChatDependencies,
        router: AppRouter
    ) {
        self.sessionId = sessionId
        self.userId = userId
        self.dependencies = dependencies
        self.router = router
    }

    // MARK: - Session lifecycle

    func loadSession() async {
        errorMessage = nil
        do {
            if let session = try await dependencies.sessionRepository.fetch(id: sessionId) {
                currentSession = session
            }
            let stored = try await dependencies.messageRepository.fetchAll(for: sessionId)
            messages = stored.map(MessageDisplayModel.init(from:))
        } catch {
            errorMessage = mapError(error)
        }
    }

    func loadSession(_ session: Session) async {
        sessionId = session.id
        currentSession = session
        await loadSession()
    }

    @discardableResult
    func startNewSession(userId: String) async throws -> Session {
        let session = Session(userId: userId)
        try await dependencies.sessionRepository.save(session)
        sessionId = session.id
        currentSession = session
        messages = []
        lastAnswerSessionCount = 0
        errorMessage = nil
        return session
    }

    // MARK: - Send

    func sendMessage(_ rawInput: String? = nil) async {
        let raw = (rawInput ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }

        if rawInput == nil {
            inputText = ""
        }
        isLoading = true
        errorMessage = nil
        lastAnswerSessionCount = 0
        defer { isLoading = false }

        // 1. Rate limit
        if case .throttled(let message) = dependencies.rateLimiter.check() {
            errorMessage = message
            return
        }

        // 2. Sanitise
        let sanitiseResult = InputSanitiser.process(raw)
        guard case .allowed(let sanitised) = sanitiseResult else {
            if case .blocked(let reason) = sanitiseResult {
                dependencies.rateLimiter.recordBlocked()
                errorMessage = reason
            }
            return
        }

        // 3. Persist + show user message
        let userMessage = Message(sessionId: sessionId, role: "user", content: raw)
        do {
            try await dependencies.messageRepository.save(userMessage)
            messages.append(MessageDisplayModel(from: userMessage))
        } catch {
            errorMessage = mapError(error)
            return
        }

        // 4. Scope guard
        do {
            let scope = try await dependencies.scopeGuard.check(sanitised)
            if case .outOfScope(let reason) = scope {
                dependencies.rateLimiter.recordBlocked()
                errorMessage = reason
                await appendAssistant(content: reason)
                return
            }
        } catch {
            errorMessage = mapError(error)
            return
        }

        dependencies.rateLimiter.recordAllowed()

        // 5–6. Intent → pipeline
        do {
            let intent = try await dependencies.classifyIntentUseCase.execute(sanitised)
            let reply = try await route(intent: intent, text: sanitised)
            await appendAssistant(content: reply)
        } catch {
            errorMessage = mapError(error)
        }
    }

    // MARK: - Private

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

    private func appendAssistant(content: String) async {
        let message = Message(sessionId: sessionId, role: "assistant", content: content)
        do {
            try await dependencies.messageRepository.save(message)
            messages.append(MessageDisplayModel(from: message))
        } catch {
            // Still show the bubble if persistence fails
            messages.append(MessageDisplayModel(from: message))
            if errorMessage == nil {
                errorMessage = mapError(error)
            }
        }
    }

    private func mapError(_ error: Error) -> String {
        if let appError = error as? AppError {
            return appError.errorDescription ?? "Something went wrong. Please try again."
        }
        return AppError.llmCallFailed(underlying: error).errorDescription
            ?? "Something went wrong. Please try again."
    }
}
