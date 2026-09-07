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

    func test_execute_tripPlanWithURL_isLocalStore() async throws {
        let intent = try await sut.execute(
            """
            Need to visit vougue by prince outlet for Moushumy’s dress

            Also need to visit this online store for Sharee : https://www.facebook.com/share/r/1drnm7bd4K/?mibextid=wwXIfr
            """
        )
        XCTAssertEqual(intent, .store)
        XCTAssertEqual(mockLLM.completeCallCount, 0)
    }

    func test_execute_bestTimeToVisit_isLocalMixed() async throws {
        let intent = try await sut.execute("What is the best time to visit Bangladesh?")
        XCTAssertEqual(intent, .mixed)
        XCTAssertEqual(mockLLM.completeCallCount, 0)
    }

    func test_execute_projectPlan_isLocalStore() async throws {
        let intent = try await sut.execute("We decided the project ships in October")
        XCTAssertEqual(intent, .store)
        XCTAssertEqual(mockLLM.completeCallCount, 0)
    }

    func test_execute_projectRecall_isLocalQuery() async throws {
        let intent = try await sut.execute("What did we decide about the project deadline?")
        XCTAssertEqual(intent, .query)
        XCTAssertEqual(mockLLM.completeCallCount, 0)
    }

    func test_execute_whatIPlanned_isLocalQuery() async throws {
        let intent = try await sut.execute(
            "What things I planned to do when I will visit Bangladesh next year"
        )
        XCTAssertEqual(intent, .query)
        XCTAssertEqual(mockLLM.completeCallCount, 0)
    }

    func test_execute_birthdayGiftSuggestion_isLocalMixed() async throws {
        let intent = try await sut.execute("Suggests me some good birthday gift")
        XCTAssertEqual(intent, .mixed)
        XCTAssertEqual(mockLLM.completeCallCount, 0)
    }

    func test_execute_aseanBudgetTour_isLocalMixed() async throws {
        let intent = try await sut.execute(
            "which Asean country good for budget friendly tour?"
        )
        XCTAssertEqual(intent, .mixed)
        XCTAssertEqual(mockLLM.completeCallCount, 0)
    }

    func test_execute_facebookLinkRecall_isLocalQuery() async throws {
        let intent = try await sut.execute("Do you know the link of that facebook page?")
        XCTAssertEqual(intent, .query)
        XCTAssertEqual(mockLLM.completeCallCount, 0)
    }

    func test_execute_tryAgainFindTheLink_isLocalQuery() async throws {
        let intent = try await sut.execute("Try again and check if you can find the link")
        XCTAssertEqual(intent, .query)
        XCTAssertEqual(mockLLM.completeCallCount, 0)
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
