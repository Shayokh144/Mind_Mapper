import Foundation
import GRDB

nonisolated struct MessageRepository: MessageRepositoryProtocol {
    private let database: DatabaseManager

    init(database: DatabaseManager) {
        self.database = database
    }

    func save(_ message: Message) async throws {
        do {
            try await database.dbQueue.write { db in
                try MessageRecord(from: message).insert(db)
            }
        } catch {
            AppLogger.error("Failed to save message \(message.id)", error: error)
            throw AppError.saveFailed(underlying: error)
        }
    }

    func fetchAll(for sessionId: String) async throws -> [Message] {
        do {
            return try await database.dbQueue.read { db in
                try MessageRecord
                    .filter(Column("session_id") == sessionId)
                    .order(Column("created_at").asc)
                    .fetchAll(db)
                    .map(\.domainModel)
            }
        } catch {
            AppLogger.error("Failed to fetch messages for session \(sessionId)", error: error)
            throw AppError.loadFailed(underlying: error)
        }
    }
}
