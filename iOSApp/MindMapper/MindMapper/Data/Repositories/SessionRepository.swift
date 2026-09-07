import Foundation
import GRDB

nonisolated struct SessionRepository: SessionRepositoryProtocol {
    private let database: DatabaseManager

    init(database: DatabaseManager) {
        self.database = database
    }

    func save(_ session: Session) async throws {
        do {
            try await database.dbQueue.write { db in
                try SessionRecord(from: session).insert(db)
            }
        } catch {
            AppLogger.error("Failed to save session \(session.id)", error: error)
            throw AppError.saveFailed(underlying: error)
        }
    }

    func update(_ session: Session) async throws {
        do {
            try await database.dbQueue.write { db in
                try SessionRecord(from: session).update(db)
            }
        } catch {
            AppLogger.error("Failed to update session \(session.id)", error: error)
            throw AppError.saveFailed(underlying: error)
        }
    }

    func fetch(id: String) async throws -> Session? {
        do {
            return try await database.dbQueue.read { db in
                try SessionRecord.fetchOne(db, key: id)?.domainModel
            }
        } catch {
            AppLogger.error("Failed to fetch session \(id)", error: error)
            throw AppError.loadFailed(underlying: error)
        }
    }

    func fetchAll(for userId: String) async throws -> [Session] {
        do {
            return try await database.dbQueue.read { db in
                try SessionRecord
                    .filter(Column("user_id") == userId)
                    .order(Column("is_pinned").desc, Column("updated_at").desc)
                    .fetchAll(db)
                    .map(\.domainModel)
            }
        } catch {
            AppLogger.error("Failed to fetch sessions for user \(userId)", error: error)
            throw AppError.loadFailed(underlying: error)
        }
    }

    func fetchAllWithMessages(for userId: String) async throws -> [Session] {
        do {
            return try await database.dbQueue.read { db in
                let sql = """
                    SELECT sessions.* FROM sessions
                    WHERE sessions.user_id = ?
                      AND EXISTS (
                        SELECT 1 FROM messages WHERE messages.session_id = sessions.id
                      )
                    ORDER BY sessions.is_pinned DESC, sessions.updated_at DESC
                    """
                return try SessionRecord
                    .fetchAll(db, sql: sql, arguments: [userId])
                    .map(\.domainModel)
            }
        } catch {
            AppLogger.error("Failed to fetch non-empty sessions for user \(userId)", error: error)
            throw AppError.loadFailed(underlying: error)
        }
    }

    func deleteCascade(id: String) async throws {
        do {
            try await database.dbQueue.write { db in
                try ReminderRecord
                    .filter(Column("session_id") == id)
                    .deleteAll(db)

                let memoryIds = try MemoryRecord
                    .filter(Column("session_id") == id)
                    .fetchAll(db)
                    .map(\.id)

                if !memoryIds.isEmpty {
                    try ReminderRecord
                        .filter(memoryIds.contains(Column("memory_id")))
                        .deleteAll(db)
                    try MemoryEntityRecord
                        .filter(memoryIds.contains(Column("memory_id")))
                        .deleteAll(db)
                    try VectorRecord
                        .filter(memoryIds.contains(Column("memory_id")))
                        .deleteAll(db)
                    try MemoryRecord
                        .filter(Column("session_id") == id)
                        .deleteAll(db)
                }

                try MessageRecord
                    .filter(Column("session_id") == id)
                    .deleteAll(db)

                _ = try SessionRecord.deleteOne(db, key: id)
            }
        } catch {
            AppLogger.error("Failed to delete session \(id)", error: error)
            throw AppError.saveFailed(underlying: error)
        }
    }

    func purgeEmptySessions(for userId: String) async throws {
        do {
            try await database.dbQueue.write { db in
                try db.execute(
                    sql: """
                        DELETE FROM sessions
                        WHERE user_id = ?
                          AND NOT EXISTS (
                            SELECT 1 FROM messages WHERE messages.session_id = sessions.id
                          )
                        """,
                    arguments: [userId]
                )
            }
        } catch {
            AppLogger.error("Failed to purge empty sessions for user \(userId)", error: error)
            throw AppError.saveFailed(underlying: error)
        }
    }
}
