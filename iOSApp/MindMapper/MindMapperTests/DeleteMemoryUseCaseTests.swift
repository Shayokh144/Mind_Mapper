import XCTest
import GRDB
@testable import MindMapper

final class DeleteMemoryUseCaseTests: XCTestCase {
    private var database: DatabaseManager!
    private var memoryRepository: MemoryRepository!
    private var sut: DeleteMemoryUseCase!
    private var user: User!
    private var session: Session!

    override func setUpWithError() throws {
        try super.setUpWithError()
        database = try DatabaseManager(dbQueue: DatabaseQueue())
        memoryRepository = MemoryRepository(database: database)
        sut = DeleteMemoryUseCase(
            memoryRepository: memoryRepository,
            reminderRepository: ReminderRepository(database: database),
            notificationService: MockLocalNotificationService()
        )
        user = User(email: "delete-memory@example.com")
        session = Session(userId: user.id, title: "Gifts")
        try database.dbQueue.write { db in
            try UserRecord(from: user).insert(db)
            try SessionRecord(from: session).insert(db)
        }
    }

    override func tearDownWithError() throws {
        sut = nil
        memoryRepository = nil
        database = nil
        user = nil
        session = nil
        try super.tearDownWithError()
    }

    func test_execute_restoresSupersededOlderMemory() async throws {
        let older = Memory(
            sessionId: session.id,
            userId: user.id,
            rawText: "Perfume for wife",
            cleanText: "Perfume is the gift plan",
            isSuperseded: true
        )
        let newer = Memory(
            sessionId: session.id,
            userId: user.id,
            rawText: "Watch instead",
            cleanText: "Watch is the gift plan",
            supersedesId: older.id,
            isSuperseded: false
        )
        let entity = MemoryEntity(
            memoryId: newer.id,
            entityType: "product",
            entityValue: "watch"
        )
        let embedding = Data(repeating: 2, count: 6_144)

        try await database.dbQueue.write { db in
            try MemoryRecord(from: older).insert(db)
            try MemoryRecord(from: newer).insert(db)
            try MemoryEntityRecord(from: entity).insert(db)
            try VectorRecord(
                from: Vector(memoryId: newer.id, embedding: embedding)
            ).insert(db)
        }

        try await sut.execute(memoryId: newer.id)

        let restored = try await memoryRepository.fetch(id: older.id)
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.isSuperseded, false)

        let deleted = try await memoryRepository.fetch(id: newer.id)
        XCTAssertNil(deleted)

        let leftoverChildren = try await database.dbQueue.read { db -> (Int, Int) in
            let entities = try MemoryEntityRecord
                .filter(Column("memory_id") == newer.id)
                .fetchCount(db)
            let vectors = try VectorRecord
                .filter(Column("memory_id") == newer.id)
                .fetchCount(db)
            return (entities, vectors)
        }
        XCTAssertEqual(leftoverChildren.0, 0)
        XCTAssertEqual(leftoverChildren.1, 0)
    }
}
