import XCTest
@testable import MindMapper

@MainActor
final class ChatViewModelTests: XCTestCase {
    private var classify: MockClassifyIntentUseCase!
    private var saveMemory: MockSaveMemoryUseCase!
    private var queryMemory: MockQueryMemoryUseCase!
    private var mixedQuery: MockMixedQueryUseCase!
    private var scopeGuard: MockScopeGuard!
    private var rateLimiter: MockRateLimiter!
    private var messages: MockMessageRepository!
    private var sessions: MockSessionRepository!
    private var llm: MockLLMService!
    private var router: AppRouter!
    private var session: Session!
    private var sut: ChatViewModel!

    override func setUp() async throws {
        try await super.setUp()
        classify = MockClassifyIntentUseCase()
        saveMemory = MockSaveMemoryUseCase()
        queryMemory = MockQueryMemoryUseCase()
        mixedQuery = MockMixedQueryUseCase()
        scopeGuard = MockScopeGuard()
        rateLimiter = MockRateLimiter()
        messages = MockMessageRepository()
        sessions = MockSessionRepository()
        llm = MockLLMService()
        router = AppRouter()
        session = Session(userId: "user-1", title: "Test")
        sessions.sessions = [session]
        sut = makeSUT()
    }

    override func tearDown() async throws {
        sut = nil
        router = nil
        session = nil
        classify = nil
        saveMemory = nil
        queryMemory = nil
        mixedQuery = nil
        scopeGuard = nil
        rateLimiter = nil
        messages = nil
        sessions = nil
        llm = nil
        try await super.tearDown()
    }

    func test_sendMessage_storeIntent_callsSaveMemoryAndAppendsAck() async {
        classify.intent = .store
        saveMemory.result = "Got it — keys noted."

        await sut.sendMessage("I put my keys on the table")

        XCTAssertEqual(saveMemory.executeCallCount, 1)
        XCTAssertEqual(queryMemory.executeCallCount, 0)
        XCTAssertEqual(mixedQuery.executeCallCount, 0)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(sut.messages.count, 2)
        XCTAssertEqual(sut.messages[0].role, "user")
        XCTAssertEqual(sut.messages[1].content, "Got it — keys noted.")
        XCTAssertEqual(rateLimiter.recordAllowedCallCount, 1)
    }

    func test_sendMessage_queryIntent_callsQueryMemoryAndSetsSessionCount() async {
        classify.intent = .query
        queryMemory.result = RAGAnswer(
            text: "Keys are on the table.",
            representedSessionIds: ["a", "b"]
        )

        await sut.sendMessage("Where are my keys?")

        XCTAssertEqual(queryMemory.executeCallCount, 1)
        XCTAssertEqual(saveMemory.executeCallCount, 0)
        XCTAssertEqual(sut.lastAnswerSessionCount, 2)
        XCTAssertEqual(sut.messages.last?.content, "Keys are on the table.")
        XCTAssertFalse(sut.isLoading)
    }

    func test_sendMessage_mixedIntent_callsMixedQuery() async {
        classify.intent = .mixed

        await sut.sendMessage("What dress ideas did we discuss and suggest more?")

        XCTAssertEqual(mixedQuery.executeCallCount, 1)
        XCTAssertEqual(queryMemory.executeCallCount, 0)
        XCTAssertEqual(sut.lastAnswerSessionCount, 2)
        XCTAssertEqual(sut.messages.last?.content, mixedQuery.result.text)
        XCTAssertFalse(sut.isLoading)
    }

    func test_sendMessage_scopeBlocked_setsErrorAndSkipsUseCases() async {
        scopeGuard.result = .outOfScope("I can only help with your personal memories and plans.")
        classify.intent = .store

        // Passes InputSanitiser ("debug this" is a code signal) but fails ScopeGuard.
        await sut.sendMessage("What is the capital of France?")

        XCTAssertEqual(scopeGuard.checkCallCount, 1)
        XCTAssertEqual(classify.executeCallCount, 0)
        XCTAssertEqual(saveMemory.executeCallCount, 0)
        XCTAssertEqual(queryMemory.executeCallCount, 0)
        XCTAssertEqual(mixedQuery.executeCallCount, 0)
        XCTAssertEqual(
            sut.errorMessage,
            "I can only help with your personal memories and plans."
        )
        XCTAssertEqual(sut.messages.last?.role, "assistant")
        XCTAssertEqual(rateLimiter.recordBlockedCallCount, 1)
        XCTAssertFalse(sut.isLoading)
    }

    func test_sendMessage_sanitiserBlocksCode_skipsScopeAndUseCases() async {
        await sut.sendMessage("```swift\nfunc foo() {}\n```")

        XCTAssertEqual(scopeGuard.checkCallCount, 0)
        XCTAssertEqual(classify.executeCallCount, 0)
        XCTAssertEqual(saveMemory.executeCallCount, 0)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.messages.isEmpty)
        XCTAssertEqual(rateLimiter.recordBlockedCallCount, 1)
        XCTAssertFalse(sut.isLoading)
    }

    func test_sendMessage_rateLimited_setsErrorAndSkipsEverything() async {
        rateLimiter.checkResult = .throttled("Please wait 60 seconds before sending another message.")

        await sut.sendMessage("I put my keys on the table")

        XCTAssertEqual(scopeGuard.checkCallCount, 0)
        XCTAssertEqual(classify.executeCallCount, 0)
        XCTAssertEqual(saveMemory.executeCallCount, 0)
        XCTAssertEqual(
            sut.errorMessage,
            "Please wait 60 seconds before sending another message."
        )
        XCTAssertTrue(sut.messages.isEmpty)
        XCTAssertFalse(sut.isLoading)
    }

    func test_sendMessage_pipelineError_setsAppErrorMessageAndClearsLoading() async {
        classify.intent = .query
        queryMemory.error = AppError.llmCallFailed(
            underlying: NSError(domain: "test", code: 1)
        )

        await sut.sendMessage("Where are my keys?")

        XCTAssertEqual(
            sut.errorMessage,
            "Couldn't reach the AI. Check your connection and try again."
        )
        XCTAssertFalse(sut.isLoading)
        // User message was saved before the failure
        XCTAssertEqual(sut.messages.count, 1)
        XCTAssertEqual(sut.messages[0].role, "user")
    }

    func test_loadSession_populatesMessages() async {
        messages.messages = [
            Message(sessionId: session.id, role: "user", content: "Hi"),
            Message(sessionId: session.id, role: "assistant", content: "Hello"),
        ]

        await sut.loadSession()

        XCTAssertEqual(sut.messages.count, 2)
        XCTAssertEqual(sut.currentSession?.id, session.id)
        XCTAssertFalse(sut.isLoading)
    }

    func test_startNewSession_resetsMessages() async throws {
        messages.messages = [
            Message(sessionId: session.id, role: "user", content: "Old"),
        ]
        await sut.loadSession()
        XCTAssertEqual(sut.messages.count, 1)

        let created = try await sut.startNewSession(userId: "user-1")

        XCTAssertTrue(sut.messages.isEmpty)
        XCTAssertEqual(sut.currentSession?.id, created.id)
        XCTAssertEqual(sessions.sessions.count, 2)
    }

    // MARK: - Helpers

    private func makeSUT() -> ChatViewModel {
        ChatViewModel(
            sessionId: session.id,
            userId: "user-1",
            dependencies: ChatDependencies(
                rateLimiter: rateLimiter,
                scopeGuard: scopeGuard,
                classifyIntentUseCase: classify,
                saveMemoryUseCase: saveMemory,
                queryMemoryUseCase: queryMemory,
                mixedQueryUseCase: mixedQuery,
                llmClient: llm,
                messageRepository: messages,
                sessionRepository: sessions
            ),
            router: router
        )
    }
}
