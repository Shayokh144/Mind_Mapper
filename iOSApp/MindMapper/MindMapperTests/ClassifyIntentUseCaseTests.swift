import XCTest
@testable import MindMapper

final class ClassifyIntentUseCaseTests: XCTestCase {
    private var mockLLM: MockLLMService!
    private var sut: ClassifyIntentUseCase!

    override func setUp() {
        super.setUp()
        mockLLM = MockLLMService()
        sut = ClassifyIntentUseCase(llmClient: mockLLM)
    }

    override func tearDown() {
        sut = nil
        mockLLM = nil
        super.tearDown()
    }

    func test_execute_storePath() async throws {
        mockLLM.completeResult = "STORE"
        let intent = try await sut.execute("I put my blue T-shirt in the 3rd drawer")
        XCTAssertEqual(intent, .store)
        assertNanoClassificationCall()
    }

    func test_execute_queryPath() async throws {
        mockLLM.completeResult = "QUERY"
        let intent = try await sut.execute("Where is my blue T-shirt?")
        XCTAssertEqual(intent, .query)
        assertNanoClassificationCall()
    }

    func test_execute_mixedPath() async throws {
        mockLLM.completeResult = "MIXED"
        let intent = try await sut.execute(
            "What gift ideas did we discuss, and suggest some more?"
        )
        XCTAssertEqual(intent, .mixed)
        assertNanoClassificationCall()
    }

    func test_execute_chatPath() async throws {
        mockLLM.completeResult = "CHAT"
        let intent = try await sut.execute("Thanks!")
        XCTAssertEqual(intent, .chat)
        assertNanoClassificationCall()
    }

    func test_execute_unrecognisedResponse_defaultsToChat() async throws {
        mockLLM.completeResult = "MAYBE_SOMETHING"
        let intent = try await sut.execute("Hmm not sure")
        XCTAssertEqual(intent, .chat)
    }

    func test_parseIntent_trimsAndTakesFirstWord() {
        XCTAssertEqual(ClassifyIntentUseCase.parseIntent("  store\n"), .store)
        XCTAssertEqual(ClassifyIntentUseCase.parseIntent("QUERY."), .query)
        XCTAssertEqual(ClassifyIntentUseCase.parseIntent("mixed please"), .mixed)
        XCTAssertEqual(ClassifyIntentUseCase.parseIntent(""), .chat)
    }

    private func assertNanoClassificationCall() {
        XCTAssertEqual(mockLLM.completeCallCount, 1)
        XCTAssertEqual(mockLLM.lastTier, .nano)
        XCTAssertEqual(mockLLM.lastMaxTokens, 5)
        XCTAssertEqual(mockLLM.lastTemperature, 0)
        XCTAssertEqual(mockLLM.lastMessages?.count, 2)
        XCTAssertEqual(mockLLM.lastMessages?.first?.role, "system")
        XCTAssertEqual(mockLLM.lastMessages?.last?.role, "user")
    }
}
