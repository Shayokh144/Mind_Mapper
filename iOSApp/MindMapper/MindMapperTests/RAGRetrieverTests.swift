import XCTest
import GRDB
@testable import MindMapper

final class RAGRetrieverTests: XCTestCase {
    // MARK: - Merge / de-duplication

    func test_merge_duplicateMemoryId_keepsHigherSimilarity() {
        let lower = makeChunk(
            memoryId: "m1",
            similarity: 0.55,
            source: "vector",
            sessionId: "s1"
        )
        let higher = makeChunk(
            memoryId: "m1",
            similarity: 0.70,
            source: "entity",
            sessionId: "s1"
        )
        let other = makeChunk(
            memoryId: "m2",
            similarity: 0.80,
            source: "vector",
            sessionId: "s2"
        )

        let merged = RAGRetriever.merge([lower, higher, other])

        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged[0].memoryId, "m2")
        XCTAssertEqual(merged[0].similarity, 0.80, accuracy: 0.0001)
        XCTAssertEqual(merged[1].memoryId, "m1")
        XCTAssertEqual(merged[1].similarity, 0.70, accuracy: 0.0001)
        XCTAssertEqual(merged[1].source, "entity")
    }

    func test_merge_vectorHigherThanEntity_keepsVectorScore() {
        let entity = makeChunk(memoryId: "m1", similarity: 0.70, source: "entity")
        let vector = makeChunk(memoryId: "m1", similarity: 0.92, source: "vector")

        let merged = RAGRetriever.merge([entity, vector])

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].similarity, 0.92, accuracy: 0.0001)
        XCTAssertEqual(merged[0].source, "vector")
    }

    // MARK: - Stage 2 confidence filter

    func test_filterConfident_removesLowScoringVector_keepsEntity() {
        let weakVector = makeChunk(memoryId: "v-low", similarity: 0.45, source: "vector")
        let strongVector = makeChunk(memoryId: "v-high", similarity: 0.80, source: "vector")
        let weakEntity = makeChunk(memoryId: "e-low", similarity: 0.40, source: "entity")

        let filtered = RAGRetriever.filterConfident(
            [weakVector, strongVector, weakEntity],
            threshold: 0.62
        )

        XCTAssertEqual(filtered.map(\.memoryId).sorted(), ["e-low", "v-high"])
    }

    // MARK: - Session badge helper

    func test_representedSessionIds_returnsDistinctSorted() {
        let chunks = [
            makeChunk(memoryId: "a", similarity: 0.9, source: "vector", sessionId: "s-b"),
            makeChunk(memoryId: "b", similarity: 0.8, source: "entity", sessionId: "s-a"),
            makeChunk(memoryId: "c", similarity: 0.7, source: "vector", sessionId: "s-b"),
        ]
        XCTAssertEqual(
            RetrievedChunk.representedSessionIds(in: chunks),
            ["s-a", "s-b"]
        )
    }

    // MARK: - Entity extraction + hybrid retrieve (mocked LLM)

    func test_extractEntitiesFromQuestion_usesNanoTierAndParsesJSON() async throws {
        let database = try DatabaseManager(dbQueue: DatabaseQueue())
        let mock = MockLLMService()
        mock.completeResult = #"["wife", "gift"]"#
        let sut = RAGRetriever(
            llmClient: mock,
            vectorStore: VectorStore(database: database),
            database: database
        )

        let entities = await sut.extractEntitiesFromQuestion("What did I decide for my wife?")

        XCTAssertEqual(entities, ["wife", "gift"])
        XCTAssertEqual(mock.lastTier, .nano)
        XCTAssertEqual(mock.lastMaxTokens, 60)
        XCTAssertEqual(mock.lastTemperature, 0)
    }

    func test_extractEntitiesFromQuestion_onLLMFailure_returnsEmpty() async throws {
        let database = try DatabaseManager(dbQueue: DatabaseQueue())
        let mock = MockLLMService()
        mock.completeError = AppError.llmCallFailed(
            underlying: NSError(domain: "RAGRetrieverTests", code: 1)
        )
        let sut = RAGRetriever(
            llmClient: mock,
            vectorStore: VectorStore(database: database),
            database: database
        )

        let entities = await sut.extractEntitiesFromQuestion("Where is my passport?")
        XCTAssertTrue(entities.isEmpty)
    }

    func test_retrieve_entityFilter_findsWifeMemories() async throws {
        let database = try DatabaseManager(dbQueue: DatabaseQueue())
        let user = User(email: "rag@example.com")
        let sessionA = Session(userId: user.id, title: "Gifts")
        let sessionB = Session(userId: user.id, title: "Later")
        let perfume = Memory(
            sessionId: sessionA.id,
            userId: user.id,
            rawText: "Buying perfume for my wife",
            cleanText: "Perfume is the gift plan for wife"
        )
        let watch = Memory(
            sessionId: sessionB.id,
            userId: user.id,
            rawText: "Watch for wife instead",
            cleanText: "Watch is now the gift plan for wife"
        )

        try await database.dbQueue.write { db in
            try UserRecord(from: user).insert(db)
            try SessionRecord(from: sessionA).insert(db)
            try SessionRecord(from: sessionB).insert(db)
            try MemoryRecord(from: perfume).insert(db)
            try MemoryRecord(from: watch).insert(db)
            try MemoryEntityRecord(
                from: MemoryEntity(memoryId: perfume.id, entityType: "person", entityValue: "wife")
            ).insert(db)
            try MemoryEntityRecord(
                from: MemoryEntity(memoryId: watch.id, entityType: "person", entityValue: "wife")
            ).insert(db)
        }

        // No vectors saved — retrieval must succeed via entity path alone.
        let mock = MockLLMService()
        mock.completeResult = #"["wife"]"#
        mock.embedResult = Array(repeating: 0.01, count: 1_536)

        let sut = RAGRetriever(
            llmClient: mock,
            vectorStore: VectorStore(database: database),
            database: database
        )

        let chunks = try await sut.retrieve(
            question: "What did I decide for my wife?",
            userId: user.id
        )
        let confident = RAGRetriever.filterConfident(chunks)

        XCTAssertEqual(Set(confident.map(\.memoryId)), [perfume.id, watch.id])
        XCTAssertTrue(confident.allSatisfy { $0.source == "entity" })
        XCTAssertEqual(
            RetrievedChunk.representedSessionIds(in: confident).count,
            2
        )
    }

    func test_retrieve_vectorSearch_returnsHighSimilarityMemory() async throws {
        let database = try DatabaseManager(dbQueue: DatabaseQueue())
        let user = User(email: "vector@example.com")
        let session = Session(userId: user.id, title: "Wardrobe")
        let tshirt = Memory(
            sessionId: session.id,
            userId: user.id,
            rawText: "Blue T-shirt in 3rd drawer",
            cleanText: "Blue T-shirt is in the 3rd drawer"
        )
        let embedding = makeUnitEmbedding(seed: 3)

        try await database.dbQueue.write { db in
            try UserRecord(from: user).insert(db)
            try SessionRecord(from: session).insert(db)
            try MemoryRecord(from: tshirt).insert(db)
        }
        try await VectorStore(database: database).save(embedding: embedding, memoryId: tshirt.id)

        let mock = MockLLMService()
        mock.completeResult = "[]"
        mock.embedResult = embedding

        let sut = RAGRetriever(
            llmClient: mock,
            vectorStore: VectorStore(database: database),
            database: database
        )

        let chunks = try await sut.retrieve(
            question: "Where is my blue T-shirt?",
            userId: user.id
        )
        let confident = RAGRetriever.filterConfident(chunks)

        XCTAssertEqual(confident.count, 1)
        XCTAssertEqual(confident[0].memoryId, tshirt.id)
        XCTAssertEqual(confident[0].source, "vector")
        XCTAssertGreaterThanOrEqual(confident[0].similarity, 0.99)
    }

    // MARK: - Helpers

    private func makeChunk(
        memoryId: String,
        similarity: Float,
        source: String,
        sessionId: String = "s1"
    ) -> RetrievedChunk {
        RetrievedChunk(
            memoryId: memoryId,
            cleanText: "text-\(memoryId)",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            isSuperseded: false,
            supersedesId: nil,
            sessionId: sessionId,
            similarity: similarity,
            source: source
        )
    }

    /// Deterministic non-zero embedding so cosine self-similarity is 1.0.
    private func makeUnitEmbedding(seed: Float) -> [Float] {
        var values = (0..<1_536).map { Float($0) * 0.001 + seed }
        let magnitude = sqrt(values.reduce(Float(0)) { $0 + $1 * $1 })
        values = values.map { $0 / magnitude }
        return values
    }
}
