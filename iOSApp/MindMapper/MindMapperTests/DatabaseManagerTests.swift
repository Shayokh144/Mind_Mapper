import XCTest
import GRDB
@testable import MindMapper

final class DatabaseManagerTests: XCTestCase {

    private var database: DatabaseManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        database = try DatabaseManager(dbQueue: DatabaseQueue())
    }

    override func tearDownWithError() throws {
        database = nil
        try super.tearDownWithError()
    }

    // MARK: - Schema

    func test_migration_createsAllTablesAndIndexes() throws {
        let tableNames = try database.dbQueue.read { db in
            try String.fetchAll(
                db,
                sql: """
                SELECT name FROM sqlite_master
                WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'grdb_%'
                ORDER BY name
                """
            )
        }
        XCTAssertEqual(
            tableNames,
            ["memories", "memory_entities", "messages", "sessions", "users", "vectors"]
        )

        let indexNames = try database.dbQueue.read { db in
            try String.fetchAll(
                db,
                sql: """
                SELECT name FROM sqlite_master
                WHERE type = 'index' AND name LIKE 'idx_%'
                ORDER BY name
                """
            )
        }
        XCTAssertEqual(
            indexNames,
            ["idx_entities_lookup", "idx_memories_user", "idx_messages_session"]
        )
    }

    // MARK: - Session insert / fetch

    func test_insertAndFetchSession() throws {
        let user = User(email: "test@example.com", displayName: "Tester")
        let session = Session(
            userId: user.id,
            title: "Gift ideas",
            topicTag: .builtIn(.gifts)
        )

        try database.dbQueue.write { db in
            try UserRecord(from: user).insert(db)
            try SessionRecord(from: session).insert(db)
        }

        let fetched = try database.dbQueue.read { db in
            try SessionRecord.fetchOne(db, key: session.id)?.domainModel
        }

        XCTAssertEqual(fetched?.id, session.id)
        XCTAssertEqual(fetched?.userId, session.userId)
        XCTAssertEqual(fetched?.title, session.title)
        XCTAssertEqual(fetched?.topicTag, .builtIn(.gifts))
        XCTAssertEqual(fetched?.summary, session.summary)
        XCTAssertEqual(
            fetched?.createdAt.timeIntervalSince1970 ?? 0,
            session.createdAt.timeIntervalSince1970,
            accuracy: 1.0
        )
        XCTAssertEqual(
            fetched?.updatedAt.timeIntervalSince1970 ?? 0,
            session.updatedAt.timeIntervalSince1970,
            accuracy: 1.0
        )
    }

    // MARK: - Memory + entities + FK integrity

    func test_insertMemoryWithEntities_andForeignKeyIntegrity() throws {
        let user = User(email: "fk@example.com")
        let session = Session(userId: user.id, topicTag: .builtIn(.wardrobe))
        let memory = Memory(
            sessionId: session.id,
            userId: user.id,
            rawText: "Blue T-shirt in the 3rd drawer",
            cleanText: "Blue T-shirt is in the 3rd drawer"
        )
        let entity = MemoryEntity(
            memoryId: memory.id,
            entityType: "category",
            entityValue: "clothing"
        )

        try database.dbQueue.write { db in
            try UserRecord(from: user).insert(db)
            try SessionRecord(from: session).insert(db)
            try MemoryRecord(from: memory).insert(db)
            try MemoryEntityRecord(from: entity).insert(db)
        }

        let entities = try database.dbQueue.read { db in
            try MemoryEntityRecord
                .filter(Column("memory_id") == memory.id)
                .fetchAll(db)
                .map(\.domainModel)
        }
        XCTAssertEqual(entities, [entity])

        // Orphan entity (unknown memory_id) must fail while foreign keys are enforced.
        let orphan = MemoryEntity(
            memoryId: "missing-memory-id",
            entityType: "person",
            entityValue: "wife"
        )
        XCTAssertThrowsError(
            try database.dbQueue.write { db in
                try MemoryEntityRecord(from: orphan).insert(db)
            }
        )
    }

    // MARK: - Vector blob round-trip

    func test_vectorEmbedding_floatArrayRoundTrips() throws {
        let floats: [Float] = [0.1, -0.25, 0.5, 1.0, -1.0, 42.0]
        let encoded = EmbeddingCodec.encode(floats)
        let decoded = EmbeddingCodec.decode(encoded)
        XCTAssertEqual(decoded, floats)

        let user = User(email: "vector@example.com")
        let session = Session(userId: user.id)
        let memory = Memory(
            sessionId: session.id,
            userId: user.id,
            rawText: "raw",
            cleanText: "clean"
        )
        let vector = Vector(memoryId: memory.id, embedding: encoded)

        try database.dbQueue.write { db in
            try UserRecord(from: user).insert(db)
            try SessionRecord(from: session).insert(db)
            try MemoryRecord(from: memory).insert(db)
            try VectorRecord(from: vector).insert(db)
        }

        let fetched = try database.dbQueue.read { db in
            try VectorRecord.fetchOne(db, key: vector.id)?.domainModel
        }

        XCTAssertNotNil(fetched)
        XCTAssertEqual(EmbeddingCodec.decode(fetched!.embedding), floats)
    }
}
