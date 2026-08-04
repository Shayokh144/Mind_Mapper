import XCTest
@testable import MindMapper

final class CloseSessionUseCaseTests: XCTestCase {
    private var messages: MockMessageRepository!
    private var sessions: MockSessionRepository!
    private var memories: MockMemoryRepository!
    private var vectors: MockVectorRepository!
    private var llm: MockLLMService!
    private var sut: CloseSessionUseCase!
    private var session: Session!

    override func setUp() async throws {
        try await super.setUp()
        messages = MockMessageRepository()
        sessions = MockSessionRepository()
        memories = MockMemoryRepository()
        vectors = MockVectorRepository()
        llm = MockLLMService()
        session = Session(userId: "user-1")
        sessions.sessions = [session]
        sut = CloseSessionUseCase(
            messageRepository: messages,
            sessionRepository: sessions,
            memoryRepository: memories,
            vectorRepository: vectors,
            llmClient: llm
        )
    }

    override func tearDown() async throws {
        sut = nil
        session = nil
        messages = nil
        sessions = nil
        memories = nil
        vectors = nil
        llm = nil
        try await super.tearDown()
    }

    func test_execute_emptyMessages_isNoOp() async throws {
        try await sut.execute(sessionId: session.id)

        XCTAssertEqual(llm.completeCallCount, 0)
        XCTAssertEqual(sessions.updateCallCount, 0)
        XCTAssertTrue(memories.saved.isEmpty)
    }

    func test_execute_generatesTitleSummaryAndEmbedsBullets() async throws {
        messages.messages = [
            Message(sessionId: session.id, role: "user", content: "Gift ideas for anniversary"),
            Message(sessionId: session.id, role: "assistant", content: "How about a weekend trip?"),
        ]
        llm.completeResultByTier = [
            .nano: #"{"title": "Anniversary Gift Ideas", "topic": "gifts"}"#,
            .mini: """
                - They want anniversary gift ideas.
                - A weekend trip was suggested.
                - Budget was not discussed yet.
                """,
        ]

        try await sut.execute(sessionId: session.id)

        XCTAssertEqual(llm.completeCallCount, 2)
        XCTAssertEqual(sessions.updateCallCount, 1)
        let updated = sessions.sessions.first { $0.id == session.id }
        XCTAssertEqual(updated?.title, "Anniversary Gift Ideas")
        XCTAssertEqual(updated?.topicTag, .builtIn(.gifts))
        XCTAssertTrue(updated?.summary?.contains("anniversary gift") == true)
        XCTAssertEqual(memories.saved.count, 3)
        XCTAssertEqual(vectors.savedMemoryIds.count, 3)
        XCTAssertTrue(memories.saved.allSatisfy { $0.rawText.hasPrefix("[Session summary]") })
        XCTAssertEqual(llm.embedCallCount, 3)
    }

    func test_execute_replacesPriorSummaryMemories() async throws {
        messages.messages = [
            Message(sessionId: session.id, role: "user", content: "Bali plans"),
        ]
        let old = Memory(
            sessionId: session.id,
            userId: "user-1",
            rawText: "[Session summary] Old bullet",
            cleanText: "Old bullet"
        )
        memories.memories = [old]
        llm.completeResultByTier = [
            .nano: #"{"title": "Bali Trip Plans", "topic": "plans"}"#,
            .mini: "- Planning a Bali trip.",
        ]

        try await sut.execute(sessionId: session.id)

        XCTAssertEqual(memories.deletedIds, [old.id])
        XCTAssertEqual(memories.saved.count, 1)
        XCTAssertEqual(memories.saved.first?.cleanText, "Planning a Bali trip.")
    }

    func test_parseBullets_stripsMarkers() {
        let bullets = CloseSessionUseCase.parseBullets("""
            - First fact.
            • Second fact.
            * Third fact.
            """)
        XCTAssertEqual(bullets, ["First fact.", "Second fact.", "Third fact."])
    }

    func test_topicTags_coverMockSessionThemes() {
        let rawValues = Set(Session.TopicTag.allCases.map(\.rawValue))
        XCTAssertTrue(rawValues.contains("gifts"))
        XCTAssertTrue(rawValues.contains("plans"))
        XCTAssertTrue(rawValues.contains("wardrobe"))
        XCTAssertTrue(rawValues.contains("ideas"))
    }
}
