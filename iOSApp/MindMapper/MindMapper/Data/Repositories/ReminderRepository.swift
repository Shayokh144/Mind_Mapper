import Foundation
import GRDB

nonisolated struct ReminderRepository: ReminderRepositoryProtocol {
    private let database: DatabaseManager

    init(database: DatabaseManager) {
        self.database = database
    }

    func save(_ reminder: Reminder) async throws {
        do {
            try await database.dbQueue.write { db in
                try ReminderRecord(from: reminder).insert(db)
            }
        } catch {
            AppLogger.error("Failed to save reminder \(reminder.id)", error: error)
            throw AppError.saveFailed(underlying: error)
        }
    }

    func update(_ reminder: Reminder) async throws {
        do {
            try await database.dbQueue.write { db in
                try ReminderRecord(from: reminder).update(db)
            }
        } catch {
            AppLogger.error("Failed to update reminder \(reminder.id)", error: error)
            throw AppError.saveFailed(underlying: error)
        }
    }

    func fetch(id: String) async throws -> Reminder? {
        do {
            return try await database.dbQueue.read { db in
                try ReminderRecord.fetchOne(db, key: id)?.domainModel
            }
        } catch {
            AppLogger.error("Failed to fetch reminder \(id)", error: error)
            throw AppError.loadFailed(underlying: error)
        }
    }

    func fetchAll(for userId: String) async throws -> [Reminder] {
        do {
            return try await database.dbQueue.read { db in
                try ReminderRecord
                    .filter(Column("user_id") == userId)
                    .order(Column("fire_at").asc)
                    .fetchAll(db)
                    .map(\.domainModel)
            }
        } catch {
            AppLogger.error("Failed to fetch reminders for user \(userId)", error: error)
            throw AppError.loadFailed(underlying: error)
        }
    }

    func fetchAll(sessionId: String) async throws -> [Reminder] {
        do {
            return try await database.dbQueue.read { db in
                try ReminderRecord
                    .filter(Column("session_id") == sessionId)
                    .fetchAll(db)
                    .map(\.domainModel)
            }
        } catch {
            AppLogger.error("Failed to fetch reminders for session \(sessionId)", error: error)
            throw AppError.loadFailed(underlying: error)
        }
    }

    func fetchAll(memoryId: String) async throws -> [Reminder] {
        do {
            return try await database.dbQueue.read { db in
                try ReminderRecord
                    .filter(Column("memory_id") == memoryId)
                    .fetchAll(db)
                    .map(\.domainModel)
            }
        } catch {
            AppLogger.error("Failed to fetch reminders for memory \(memoryId)", error: error)
            throw AppError.loadFailed(underlying: error)
        }
    }

    func delete(id: String) async throws {
        do {
            try await database.dbQueue.write { db in
                _ = try ReminderRecord.deleteOne(db, key: id)
            }
        } catch {
            AppLogger.error("Failed to delete reminder \(id)", error: error)
            throw AppError.saveFailed(underlying: error)
        }
    }

    func deleteAll(sessionId: String) async throws {
        do {
            try await database.dbQueue.write { db in
                try ReminderRecord.filter(Column("session_id") == sessionId).deleteAll(db)
            }
        } catch {
            AppLogger.error("Failed to delete reminders for session \(sessionId)", error: error)
            throw AppError.saveFailed(underlying: error)
        }
    }

    func deleteAll(memoryId: String) async throws {
        do {
            try await database.dbQueue.write { db in
                try ReminderRecord.filter(Column("memory_id") == memoryId).deleteAll(db)
            }
        } catch {
            AppLogger.error("Failed to delete reminders for memory \(memoryId)", error: error)
            throw AppError.saveFailed(underlying: error)
        }
    }
}
