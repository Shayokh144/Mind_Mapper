import Foundation
import GRDB

nonisolated struct AuthRepository: AuthRepositoryProtocol {
    private let database: DatabaseManager

    init(database: DatabaseManager) {
        self.database = database
    }

    func upsert(_ user: User) async throws {
        do {
            try await database.dbQueue.write { db in
                try UserRecord(from: user).save(db)
            }
        } catch {
            AppLogger.error("Failed to upsert local user", error: error)
            throw AppError.saveFailed(underlying: error)
        }
    }

    func fetch(id: String) async throws -> User? {
        do {
            return try await database.dbQueue.read { db in
                try UserRecord.fetchOne(db, key: id)?.domainModel
            }
        } catch {
            AppLogger.error("Failed to fetch local user", error: error)
            throw AppError.loadFailed(underlying: error)
        }
    }
}
