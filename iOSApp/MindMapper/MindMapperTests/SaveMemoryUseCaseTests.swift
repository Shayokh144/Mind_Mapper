import XCTest
import GRDB
@testable import MindMapper

final class SaveMemoryUseCaseTests: XCTestCase {
    private var database: DatabaseManager!
    private var memoryRepository: MemoryRepository!
    private var vectorRepository: VectorRepository!
    private var mockLLM: MockLLMService!
    private var user: User!
    private var session: Session!

    override func setUpWithError() throws {
        try super.setUpWithError()
        database = try DatabaseManager(dbQueue: DatabaseQueue())
        memoryRepository = MemoryRepository(database: database)
        vectorRepository = VectorRepository(database: database)
        mockLLM = MockLLMService()
        user = User(email: "save@example.com")
        session = Session(userId: user.id, title: "Wardrobe")
        try database.dbQueue.write { db in
            try UserRecord(from: user).insert(db)
            try SessionRecord(from: session).insert(db)
        }
    }

    override func tearDownWithError() throws {
        mockLLM = nil
        vectorRepository = nil
        memoryRepository = nil
        database = nil
        user = nil
        session = nil
        try super.tearDownWithError()
    }

    func test_execute_savesMemoryEntitiesAnd6144ByteVector() async throws {
        let extraction = ExtractionResult(
            cleanText: "Blue T-shirt is in the 3rd drawer",
            entities: [
                .init(type: "location", value: "3rd drawer"),
                .init(type: "category", value: "clothing"),
            ],
            supersedesHint: nil
        )
        mockLLM.completeResult = "Got it — I've noted where your blue T-shirt is."
        mockLLM.embedResult = Self.makeEmbedding(seed: 1)

        let sut = SaveMemoryUseCase(
            memoryRepository: memoryRepository,
            vectorRepository: vectorRepository,
            memoryExtractor: MockMemoryExtractor(result: extraction),
            llmClient: mockLLM
        )

        let ack = try await sut.execute(
            text: "I put my blue T-shirt in the 3rd drawer",
            sessionId: session.id,
            userId: user.id
        )

        XCTAssertFalse(ack.contains("{"))
        XCTAssertTrue(ack.lowercased().contains("got it") || ack.lowercased().contains("noted"))

        let memories = try await memoryRepository.fetchAll(for: user.id)
        XCTAssertEqual(memories.count, 1)
        XCTAssertEqual(memories[0].cleanText, "Blue T-shirt is in the 3rd drawer")
        XCTAssertNil(memories[0].supersedesId)
        XCTAssertFalse(memories[0].isSuperseded)

        let entities = try await memoryRepository.fetchEntities(for: memories[0].id)
        XCTAssertEqual(entities.count, 2)
        XCTAssertTrue(entities.contains { $0.entityType == "location" && $0.entityValue == "3rd drawer" })
        XCTAssertTrue(entities.contains { $0.entityType == "category" && $0.entityValue == "clothing" })

        let vectorBlob = try await database.dbQueue.read { db in
            try VectorRecord
                .filter(Column("memory_id") == memories[0].id)
                .fetchOne(db)?
                .embedding
        }
        XCTAssertEqual(vectorBlob?.count, 6_144)
        XCTAssertEqual(mockLLM.embedCallCount, 1)
    }

    func test_execute_withInsteadOfLanguage_marksOldMemorySuperseded() async throws {
        let perfumeEmbedding = Self.makeEmbedding(seed: 42)
        let perfume = Memory(
            sessionId: session.id,
            userId: user.id,
            rawText: "Buying perfume for my wife",
            cleanText: "Perfume is the gift plan for wife"
        )
        try await memoryRepository.save(perfume)
        try await vectorRepository.save(embedding: perfumeEmbedding, memoryId: perfume.id)

        let extraction = ExtractionResult(
            cleanText: "Watch is now the gift plan for wife",
            entities: [
                .init(type: "product", value: "watch"),
                .init(type: "topic_id", value: "gift_wife"),
            ],
            supersedesHint: "perfume"
        )
        // Hint embed matches perfume vector → search finds it (threshold 0.80).
        mockLLM.embedResultsQueue = [perfumeEmbedding, Self.makeEmbedding(seed: 7)]
        mockLLM.completeResult = "Got it, updated — watch is now the plan."

        let sut = SaveMemoryUseCase(
            memoryRepository: memoryRepository,
            vectorRepository: vectorRepository,
            memoryExtractor: MockMemoryExtractor(result: extraction),
            llmClient: mockLLM
        )

        _ = try await sut.execute(
            text: "Actually, going with a watch instead of the perfume",
            sessionId: session.id,
            userId: user.id
        )

        let old = try await memoryRepository.fetch(id: perfume.id)
        XCTAssertEqual(old?.isSuperseded, true)

        let memories = try await memoryRepository.fetchAll(for: user.id)
        let newer = memories.first { $0.id != perfume.id }
        XCTAssertEqual(newer?.supersedesId, perfume.id)
        XCTAssertEqual(newer?.cleanText, "Watch is now the gift plan for wife")
        XCTAssertEqual(mockLLM.embedCallCount, 2)
    }

    private static func makeEmbedding(seed: Int) -> [Float] {
        (0..<1_536).map { index in
            Float((index + seed) % 97) / 97.0
        }
    }
}
