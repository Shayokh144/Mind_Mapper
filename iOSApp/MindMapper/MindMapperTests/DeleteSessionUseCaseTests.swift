import XCTest
import GRDB
@testable import MindMapper

final class DeleteSessionUseCaseTests: XCTestCase {
    private var database: DatabaseManager!
    private var sessionRepository: SessionRepository!
    private var sut: DeleteSessionUseCase!
    private var user: User!
    private var session: Session!

    override func setUpWithError() throws {
        try super.setUpWithError()
        database = try DatabaseManager(dbQueue: DatabaseQueue())
        sessionRepository = SessionRepository(database: database)
        sut = DeleteSessionUseCase(sessionRepository: sessionRepository)
        user = User(email: "delete-session@example.com")
        session = Session(userId: user.id, title: "Gift plans")
        try database.dbQueue.write { db in
            try UserRecord(from: user).insert(db)
            try SessionRecord(from: session).insert(db)
        }
    }

    override func tearDownWithError() throws {
        sut = nil
        sessionRepository = nil
        database = nil
        user = nil
        session = nil
        try super.tearDownWithError()
    }

    func test_execute_deletesChildrenBeforeSession() async throws {
        let memory = Memory(
            sessionId: session.id,
            userId: user.id,
            rawText: "Watch for wife",
            cleanText: "Watch is the gift plan"
        )
        let entity = MemoryEntity(
            memoryId: memory.id,
            entityType: "product",
            entityValue: "watch"
        )
        let embedding = Data(repeating: 1, count: 6_144)
        let message = Message(sessionId: session.id, role: "user", content: "Buying a watch")

        try await database.dbQueue.write { db in
            try MemoryRecord(from: memory).insert(db)
            try MemoryEntityRecord(from: entity).insert(db)
            try VectorRecord(
                from: Vector(memoryId: memory.id, embedding: embedding)
            ).insert(db)
            try MessageRecord(from: message).insert(db)
        }

        try await sut.execute(sessionId: session.id)

        let sessionId = session.id
        let memoryId = memory.id

        let counts = try await database.dbQueue.read { db -> (Int, Int, Int, Int, Int) in
            let entities = try MemoryEntityRecord
                .filter(Column("memory_id") == memoryId)
                .fetchCount(db)
            let vectors = try VectorRecord
                .filter(Column("memory_id") == memoryId)
                .fetchCount(db)
            let memories = try MemoryRecord
                .filter(Column("session_id") == sessionId)
                .fetchCount(db)
            let messages = try MessageRecord
                .filter(Column("session_id") == sessionId)
                .fetchCount(db)
            let sessions = try SessionRecord
                .filter(Column("id") == sessionId)
                .fetchCount(db)
            return (entities, vectors, memories, messages, sessions)
        }

        XCTAssertEqual(counts.0, 0, "memory_entities should be empty")
        XCTAssertEqual(counts.1, 0, "vectors should be empty")
        XCTAssertEqual(counts.2, 0, "memories should be empty")
        XCTAssertEqual(counts.3, 0, "messages should be empty")
        XCTAssertEqual(counts.4, 0, "session row should be deleted last")
    }
}
