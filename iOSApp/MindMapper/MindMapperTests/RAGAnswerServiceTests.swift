import XCTest
import GRDB
@testable import MindMapper

final class RAGAnswerServiceTests: XCTestCase {
    private var database: DatabaseManager!
    private var mockLLM: MockLLMService!
    private var user: User!

    override func setUpWithError() throws {
        try super.setUpWithError()
        database = try DatabaseManager(dbQueue: DatabaseQueue())
        mockLLM = MockLLMService()
        user = User(email: "rag-answer@example.com")
        try database.dbQueue.write { db in
            try UserRecord(from: user).insert(db)
        }
    }

    override func tearDownWithError() throws {
        mockLLM = nil
        database = nil
        user = nil
        try super.tearDownWithError()
    }

    // MARK: - Stage 3 unit

    func test_resolveTemporalOrder_annotatesSupersededAndSortsOldestFirst() {
        let older = makeChunk(
            memoryId: "old",
            cleanText: "Passport is in the top drawer",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            supersedesId: nil,
            sessionId: "s1"
        )
        let newer = makeChunk(
            memoryId: "new",
            cleanText: "Passport is in the safe",
            createdAt: Date(timeIntervalSince1970: 1_700_100_000),
            supersedesId: "old",
            sessionId: "s2"
        )

        let resolved = RAGRetriever.resolveTemporalOrder([newer, older])

        XCTAssertEqual(resolved.map(\.memoryId), ["old", "new"])
        XCTAssertTrue(resolved[0].isSuperseded)
        XCTAssertTrue(resolved[0].cleanText.hasPrefix("[OUTDATED → replaced by: Passport is in the safe]"))
        XCTAssertEqual(resolved[1].cleanText, "Passport is in the safe")
        XCTAssertFalse(resolved[1].isSuperseded)
    }

    func test_formatMemories_usesNumberedDatePrefix() {
        let chunk = makeChunk(
            memoryId: "m1",
            cleanText: "Blue T-shirt is in the 3rd drawer",
            createdAt: Date(timeIntervalSince1970: 1_709_424_000), // ~Mar 3 2024 UTC
            supersedesId: nil,
            sessionId: "s1"
        )
        let formatted = RAGAnswerService.formatMemories([chunk])
        XCTAssertTrue(formatted.hasPrefix("[1] ["))
        XCTAssertTrue(formatted.contains("] Blue T-shirt is in the 3rd drawer"))
        XCTAssertTrue(formatted.contains("Mar"))
    }

    // MARK: - Empty / no memory

    func test_answer_noMemories_returnsGracefulReply() async throws {
        let session = try await insertSession(title: "Empty")
        mockLLM.completeResultsQueue = [
            "[]", // entity extraction
            "I don't have anything stored about that.",
        ]
        mockLLM.embedResult = makeUnitEmbedding(seed: 1)

        let result = try await makeSUT().answer(
            question: "Where is my yacht?",
            sessionId: session.id,
            userId: user.id
        )

        XCTAssertTrue(result.text.lowercased().contains("don't have anything stored"))
        XCTAssertTrue(result.representedSessionIds.isEmpty)
        XCTAssertEqual(mockLLM.lastTier, .mini)
        XCTAssertEqual(mockLLM.lastMaxTokens, 150)
    }

    // MARK: - Cross-session integration

    func test_answer_crossSessionWifeGifts_promptHasChronologyAndOutdated() async throws {
        let sessionPerfume = try await insertSession(title: "Perfume")
        let sessionWatch = try await insertSession(title: "Watch")
        let sessionScarf = try await insertSession(title: "Scarf")
        let querySession = try await insertSession(title: "Ask")

        let perfume = Memory(
            sessionId: sessionPerfume.id,
            userId: user.id,
            rawText: "Chanel perfume for wife",
            cleanText: "Perfume is the gift plan for wife",
            isSuperseded: true,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let watch = Memory(
            sessionId: sessionWatch.id,
            userId: user.id,
            rawText: "Watch instead of perfume",
            cleanText: "Watch is now the gift plan for wife",
            supersedesId: perfume.id,
            createdAt: Date(timeIntervalSince1970: 1_700_086_400)
        )
        let scarf = Memory(
            sessionId: sessionScarf.id,
            userId: user.id,
            rawText: "Also a scarf",
            cleanText: "Scarf is an extra gift for wife",
            createdAt: Date(timeIntervalSince1970: 1_700_172_800)
        )

        try await insertMemory(perfume, entities: [
            .init(memoryId: perfume.id, entityType: "person", entityValue: "wife"),
            .init(memoryId: perfume.id, entityType: "product", entityValue: "perfume"),
        ])
        try await insertMemory(watch, entities: [
            .init(memoryId: watch.id, entityType: "person", entityValue: "wife"),
            .init(memoryId: watch.id, entityType: "product", entityValue: "watch"),
        ])
        try await insertMemory(scarf, entities: [
            .init(memoryId: scarf.id, entityType: "person", entityValue: "wife"),
            .init(memoryId: scarf.id, entityType: "product", entityValue: "scarf"),
        ])

        // Recent chat context in the query session
        try await database.dbQueue.write { db in
            try MessageRecord(from: Message(
                sessionId: querySession.id,
                role: "user",
                content: "Remind me about gifts later"
            )).insert(db)
            try MessageRecord(from: Message(
                sessionId: querySession.id,
                role: "assistant",
                content: "Sure — ask whenever you're ready."
            )).insert(db)
        }

        let expectedAnswer = """
        You originally considered perfume, then switched to a watch, \
        and more recently added a scarf as an extra gift.
        """
        mockLLM.completeResultsQueue = [
            #"["wife"]"#, // entity extraction
            expectedAnswer, // Stage 4 synthesis
        ]
        mockLLM.embedResult = makeUnitEmbedding(seed: 9)

        let result = try await makeSUT().answer(
            question: "What did I decide to get my wife?",
            sessionId: querySession.id,
            userId: user.id
        )

        XCTAssertEqual(result.text, expectedAnswer.trimmingCharacters(in: .whitespacesAndNewlines))
        XCTAssertEqual(Set(result.representedSessionIds).count, 3)

        let prompt = mockLLM.lastMessages ?? []
        let joined = prompt.map(\.content).joined(separator: "\n")
        XCTAssertEqual(mockLLM.lastTier, .mini)
        XCTAssertEqual(mockLLM.lastMaxTokens, 400)
        XCTAssertEqual(mockLLM.lastTemperature, 0.4)
        XCTAssertTrue(joined.contains("[1]"))
        XCTAssertTrue(joined.contains("[2]"))
        XCTAssertTrue(joined.contains("[3]"))
        XCTAssertTrue(joined.contains("OUTDATED"))
        XCTAssertTrue(joined.contains(
            "[OUTDATED → replaced by: Watch is now the gift plan for wife] Perfume is the gift plan for wife"
        ))
        XCTAssertTrue(joined.contains("Watch is now the gift plan for wife"))
        XCTAssertTrue(joined.contains("Scarf is an extra gift for wife"))
        XCTAssertTrue(joined.contains("Remind me about gifts later"))
        XCTAssertTrue(joined.contains("What did I decide to get my wife?"))

        // Numbered memory lines are chronological (perfume → watch → scarf).
        let memoryLines = joined
            .components(separatedBy: .newlines)
            .filter { $0.hasPrefix("[1]") || $0.hasPrefix("[2]") || $0.hasPrefix("[3]") }
        XCTAssertEqual(memoryLines.count, 3)
        XCTAssertTrue(memoryLines[0].contains("Perfume"))
        XCTAssertTrue(memoryLines[1].contains("Watch is now"))
        XCTAssertTrue(memoryLines[2].contains("Scarf"))
    }

    func test_answer_passportSupersede_annotatesDrawerAsOutdated() async throws {
        let session = try await insertSession(title: "Travel")
        let drawer = Memory(
            sessionId: session.id,
            userId: user.id,
            rawText: "Passport in top drawer",
            cleanText: "Passport is in the top drawer",
            isSuperseded: true,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let safe = Memory(
            sessionId: session.id,
            userId: user.id,
            rawText: "Moved passport to safe",
            cleanText: "Passport is in the safe",
            supersedesId: drawer.id,
            createdAt: Date(timeIntervalSince1970: 1_700_050_000)
        )
        try await insertMemory(drawer, entities: [
            .init(memoryId: drawer.id, entityType: "product", entityValue: "passport"),
        ])
        try await insertMemory(safe, entities: [
            .init(memoryId: safe.id, entityType: "product", entityValue: "passport"),
        ])

        mockLLM.completeResultsQueue = [
            #"["passport"]"#,
            "You originally kept it in the drawer but moved it to the safe.",
        ]
        mockLLM.embedResult = makeUnitEmbedding(seed: 2)

        let result = try await makeSUT().answer(
            question: "Where is my passport?",
            sessionId: session.id,
            userId: user.id
        )

        XCTAssertTrue(result.text.lowercased().contains("safe"))
        let joined = (mockLLM.lastMessages ?? []).map(\.content).joined(separator: "\n")
        XCTAssertTrue(joined.contains("OUTDATED"))
        XCTAssertTrue(joined.contains("Passport is in the top drawer"))
        XCTAssertTrue(joined.contains("Passport is in the safe"))
    }

    func test_queryMemoryUseCase_delegatesToAnswerService() async throws {
        let session = try await insertSession(title: "Wrap")
        mockLLM.completeResultsQueue = ["[]", "I don't have anything stored about that."]
        mockLLM.embedResult = makeUnitEmbedding(seed: 3)

        let useCase = QueryMemoryUseCase(answerService: makeSUT())
        let result = try await useCase.execute(
            question: "Anything about Mars?",
            sessionId: session.id,
            userId: user.id
        )
        XCTAssertFalse(result.text.isEmpty)
    }

    // MARK: - Helpers

    private func makeSUT() -> RAGAnswerService {
        RAGAnswerService(
            retriever: RAGRetriever(
                llmClient: mockLLM,
                vectorStore: VectorStore(database: database),
                database: database
            ),
            llmClient: mockLLM,
            database: database
        )
    }

    private func insertSession(title: String) async throws -> Session {
        let session = Session(userId: user.id, title: title)
        try await database.dbQueue.write { db in
            try SessionRecord(from: session).insert(db)
        }
        return session
    }

    private func insertMemory(_ memory: Memory, entities: [MemoryEntity]) async throws {
        try await database.dbQueue.write { db in
            try MemoryRecord(from: memory).insert(db)
            for entity in entities {
                try MemoryEntityRecord(from: entity).insert(db)
            }
        }
    }

    private func makeChunk(
        memoryId: String,
        cleanText: String,
        createdAt: Date,
        supersedesId: String?,
        sessionId: String
    ) -> RetrievedChunk {
        RetrievedChunk(
            memoryId: memoryId,
            cleanText: cleanText,
            createdAt: createdAt,
            isSuperseded: false,
            supersedesId: supersedesId,
            sessionId: sessionId,
            similarity: 0.8,
            source: "entity"
        )
    }

    private func makeUnitEmbedding(seed: Float) -> [Float] {
        var values = (0..<1_536).map { Float($0) * 0.001 + seed }
        let magnitude = sqrt(values.reduce(Float(0)) { $0 + $1 * $1 })
        return values.map { $0 / magnitude }
    }
}
