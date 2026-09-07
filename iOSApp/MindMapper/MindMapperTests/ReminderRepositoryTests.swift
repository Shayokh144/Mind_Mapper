import XCTest
import GRDB
@testable import MindMapper

final class ReminderRepositoryTests: XCTestCase {
    private var database: DatabaseManager!
    private var sut: ReminderRepository!
    private var user: User!

    override func setUpWithError() throws {
        try super.setUpWithError()
        database = try DatabaseManager(dbQueue: DatabaseQueue())
        sut = ReminderRepository(database: database)
        user = User(email: "remind@example.com")
        try database.dbQueue.write { db in
            try UserRecord(from: user).insert(db)
        }
    }

    override func tearDownWithError() throws {
        sut = nil
        database = nil
        user = nil
        try super.tearDownWithError()
    }

    func test_saveFetchUpdateDelete() async throws {
        let reminder = Reminder(
            userId: user.id,
            title: "Take medicine",
            body: "Evening dose",
            fireAt: Date().addingTimeInterval(3_600),
            recurrence: .daily
        )
        try await sut.save(reminder)

        let fetched = try await sut.fetch(id: reminder.id)
        XCTAssertEqual(fetched?.title, "Take medicine")
        XCTAssertEqual(fetched?.recurrence, .daily)

        var updated = reminder
        updated.title = "Take vitamins"
        try await sut.update(updated)
        let afterUpdate = try await sut.fetch(id: reminder.id)
        XCTAssertEqual(afterUpdate?.title, "Take vitamins")

        try await sut.delete(id: reminder.id)
        let afterDelete = try await sut.fetch(id: reminder.id)
        XCTAssertNil(afterDelete)
    }

    func test_fetchAll_ordersByFireAt() async throws {
        let later = Reminder(
            userId: user.id,
            title: "Later",
            body: "b",
            fireAt: Date().addingTimeInterval(7_200),
            recurrence: .once
        )
        let sooner = Reminder(
            userId: user.id,
            title: "Sooner",
            body: "b",
            fireAt: Date().addingTimeInterval(1_800),
            recurrence: .once
        )
        try await sut.save(later)
        try await sut.save(sooner)
        let all = try await sut.fetchAll(for: user.id)
        XCTAssertEqual(all.map(\.title), ["Sooner", "Later"])
    }
}
