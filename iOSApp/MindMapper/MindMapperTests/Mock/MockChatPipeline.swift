import Foundation
@testable import MindMapper

nonisolated final class MockClassifyIntentUseCase: ClassifyIntentUseCaseProtocol, @unchecked Sendable {
    var intent: Intent = .chat
    var error: Error?
    private(set) var executeCallCount = 0
    private(set) var lastInput: String?

    func execute(_ input: String) async throws -> Intent {
        executeCallCount += 1
        lastInput = input
        if let error { throw error }
        return intent
    }
}

nonisolated final class MockSaveMemoryUseCase: SaveMemoryUseCaseProtocol, @unchecked Sendable {
    var result = "Got it — saved."
    var error: Error?
    private(set) var executeCallCount = 0
    private(set) var lastText: String?

    func execute(text: String, sessionId: String, userId: String) async throws -> String {
        executeCallCount += 1
        lastText = text
        if let error { throw error }
        return result
    }
}

nonisolated final class MockQueryMemoryUseCase: QueryMemoryUseCaseProtocol, @unchecked Sendable {
    var result = RAGAnswer(text: "Keys are on the table.", representedSessionIds: ["s1"])
    var error: Error?
    private(set) var executeCallCount = 0

    func execute(
        question: String,
        sessionId: String,
        userId: String
    ) async throws -> RAGAnswer {
        executeCallCount += 1
        if let error { throw error }
        return result
    }
}

nonisolated final class MockMixedQueryUseCase: MixedQueryUseCaseProtocol, @unchecked Sendable {
    var result = RAGAnswer(
        text: "You liked the blue dress; also consider navy.",
        representedSessionIds: ["s1", "s2"]
    )
    var error: Error?
    private(set) var executeCallCount = 0

    func execute(
        question: String,
        sessionId: String,
        userId: String
    ) async throws -> RAGAnswer {
        executeCallCount += 1
        if let error { throw error }
        return result
    }
}

nonisolated final class MockScopeGuard: ScopeGuardProtocol, @unchecked Sendable {
    var result: ScopeResult = .inScope
    var error: Error?
    private(set) var checkCallCount = 0

    func check(_ input: String) async throws -> ScopeResult {
        checkCallCount += 1
        if let error { throw error }
        return result
    }
}

nonisolated final class MockRateLimiter: RateLimiterProtocol, @unchecked Sendable {
    var checkResult: RateResult = .allowed
    private(set) var recordBlockedCallCount = 0
    private(set) var recordAllowedCallCount = 0

    func check() -> RateResult { checkResult }

    func recordBlocked() {
        recordBlockedCallCount += 1
    }

    func recordAllowed() {
        recordAllowedCallCount += 1
    }
}

nonisolated final class MockMessageRepository: MessageRepositoryProtocol, @unchecked Sendable {
    var messages: [Message] = []
    var saveError: Error?
    var fetchError: Error?
    private(set) var saved: [Message] = []

    func save(_ message: Message) async throws {
        if let saveError { throw saveError }
        saved.append(message)
        messages.append(message)
    }

    func fetchAll(for sessionId: String) async throws -> [Message] {
        if let fetchError { throw fetchError }
        return messages.filter { $0.sessionId == sessionId }
            .sorted { $0.createdAt < $1.createdAt }
    }
}

nonisolated final class MockSessionRepository: SessionRepositoryProtocol, @unchecked Sendable {
    var sessions: [Session] = []
    var saveError: Error?
    var fetchError: Error?

    func save(_ session: Session) async throws {
        if let saveError { throw saveError }
        sessions.append(session)
    }

    func fetch(id: String) async throws -> Session? {
        if let fetchError { throw fetchError }
        return sessions.first { $0.id == id }
    }

    func fetchAll(for userId: String) async throws -> [Session] {
        if let fetchError { throw fetchError }
        return sessions.filter { $0.userId == userId }
    }
}

nonisolated final class MockRAGAnswerService: RAGAnswerServiceProtocol, @unchecked Sendable {
    var result = RAGAnswer(text: "From memory: blue dress.", representedSessionIds: ["s1"])
    var error: Error?
    private(set) var answerCallCount = 0

    func answer(
        question: String,
        sessionId: String,
        userId: String
    ) async throws -> RAGAnswer {
        answerCallCount += 1
        if let error { throw error }
        return result
    }
}
