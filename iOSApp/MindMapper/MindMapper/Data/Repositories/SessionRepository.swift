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
                    .order(Column("updated_at").desc)
                    .fetchAll(db)
                    .map(\.domainModel)
            }
        } catch {
            AppLogger.error("Failed to fetch sessions for user \(userId)", error: error)
            throw AppError.loadFailed(underlying: error)
        }
    }
}
