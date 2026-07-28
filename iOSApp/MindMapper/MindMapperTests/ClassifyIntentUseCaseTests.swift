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

    func test_execute_localStore_skipsLLM() async throws {
        let intent = try await sut.execute("I put my blue T-shirt in the 3rd drawer")
        XCTAssertEqual(intent, .store)
        XCTAssertEqual(mockLLM.completeCallCount, 0)
    }

    func test_execute_localQuery_skipsLLM() async throws {
        let intent = try await sut.execute("Where is my blue T-shirt?")
        XCTAssertEqual(intent, .query)
        XCTAssertEqual(mockLLM.completeCallCount, 0)
    }

    func test_execute_localChat_skipsLLM() async throws {
        let intent = try await sut.execute("Thanks!")
        XCTAssertEqual(intent, .chat)
        XCTAssertEqual(mockLLM.completeCallCount, 0)
    }

    func test_execute_ambiguous_usesLLM() async throws {
        mockLLM.completeResult = "MIXED"
        // No ?, store verbs, memory nouns, or chat exact → falls through to LLM.
        let intent = try await sut.execute("Could you expand on earlier thoughts with extras")
        XCTAssertEqual(intent, .mixed)
        assertNanoClassificationCall()
    }

    func test_execute_unrecognisedResponse_defaultsToChat() async throws {
        mockLLM.completeResult = "MAYBE_SOMETHING"
        let intent = try await sut.execute("Hmm not sure about that situation")
        XCTAssertEqual(intent, .chat)
        assertNanoClassificationCall()
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
        XCTAssertEqual(mockLLM.lastMaxTokens, 16)
        XCTAssertEqual(mockLLM.lastTemperature, 0)
        XCTAssertEqual(mockLLM.lastMessages?.count, 2)
        XCTAssertEqual(mockLLM.lastMessages?.first?.role, "system")
        XCTAssertEqual(mockLLM.lastMessages?.last?.role, "user")
    }
}
