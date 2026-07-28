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

nonisolated final class MockCloseSessionUseCase: CloseSessionUseCaseProtocol, @unchecked Sendable {
    var error: Error?
    private(set) var executeCallCount = 0
    private(set) var lastSessionId: String?

    func execute(sessionId: String) async throws {
        executeCallCount += 1
        lastSessionId = sessionId
        if let error { throw error }
    }
}

nonisolated final class MockDeleteSessionUseCase: DeleteSessionUseCaseProtocol, @unchecked Sendable {
    var error: Error?
    private(set) var executeCallCount = 0
    private(set) var lastSessionId: String?

    func execute(sessionId: String) async throws {
        executeCallCount += 1
        lastSessionId = sessionId
        if let error { throw error }
    }
}

nonisolated final class MockScopeGuard: ScopeGuardProtocol, @unchecked Sendable {
    var result: ScopeResult = .inScope
    var error: Error?
    /// When set, `check` sleeps before returning (keeps ChatViewModel.isLoading true).
    var checkDelayNanoseconds: UInt64 = 0
    private(set) var checkCallCount = 0

    func check(_ input: String) async throws -> ScopeResult {
        checkCallCount += 1
        if checkDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: checkDelayNanoseconds)
        }
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

    func update(_ message: Message) async throws {
        if let saveError { throw saveError }
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index] = message
        } else {
            messages.append(message)
        }
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
    var updateError: Error?
    var fetchError: Error?
    private(set) var updateCallCount = 0

    func save(_ session: Session) async throws {
        if let saveError { throw saveError }
        sessions.append(session)
    }

    func update(_ session: Session) async throws {
        updateCallCount += 1
        if let updateError { throw updateError }
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
    }

    func fetch(id: String) async throws -> Session? {
        if let fetchError { throw fetchError }
        return sessions.first { $0.id == id }
    }

    func fetchAll(for userId: String) async throws -> [Session] {
        if let fetchError { throw fetchError }
        return sessions.filter { $0.userId == userId }
    }

    func fetchAllWithMessages(for userId: String) async throws -> [Session] {
        if let fetchError { throw fetchError }
        return sessions.filter { $0.userId == userId }
    }

    func deleteCascade(id: String) async throws {
        if let fetchError { throw fetchError }
        sessions.removeAll { $0.id == id }
    }

    func purgeEmptySessions(for userId: String) async throws {
        if let fetchError { throw fetchError }
        _ = userId
        // Tests that need message-aware purge can override; default is a no-op.
    }
}

nonisolated final class MockMemoryRepository: MemoryRepositoryProtocol, @unchecked Sendable {
    var memories: [Memory] = []
    var saveError: Error?
    var fetchError: Error?
    private(set) var saved: [Memory] = []
    private(set) var deletedIds: [String] = []

    func save(_ memory: Memory) async throws {
        try await save(memory, entities: [], superseding: nil)
    }

    func save(
        _ memory: Memory,
        entities: [MemoryEntity],
        superseding supersededId: String?
    ) async throws {
        if let saveError { throw saveError }
        saved.append(memory)
        memories.append(memory)
        _ = entities
        _ = supersededId
    }

    func fetchAll(for userId: String) async throws -> [Memory] {
        if let fetchError { throw fetchError }
        return memories.filter { $0.userId == userId }
    }

    func fetch(id: String) async throws -> Memory? {
        if let fetchError { throw fetchError }
        return memories.first { $0.id == id }
    }

    func fetchEntities(for memoryId: String) async throws -> [MemoryEntity] {
        _ = memoryId
        return []
    }

    func delete(_ memoryId: String) async throws {
        deletedIds.append(memoryId)
        memories.removeAll { $0.id == memoryId }
    }

    func markSuperseded(_ memoryId: String) async throws {
        if let index = memories.firstIndex(where: { $0.id == memoryId }) {
            memories[index].isSuperseded = true
        }
    }
}

nonisolated final class MockVectorRepository: VectorRepositoryProtocol, @unchecked Sendable {
    private(set) var savedMemoryIds: [String] = []
    var saveError: Error?

    func save(embedding: [Float], memoryId: String) async throws {
        _ = embedding
        if let saveError { throw saveError }
        savedMemoryIds.append(memoryId)
    }

    func search(
        queryEmbedding: [Float],
        topK: Int,
        threshold: Float
    ) async throws -> [VectorSearchResult] {
        _ = queryEmbedding
        _ = topK
        _ = threshold
        return []
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
