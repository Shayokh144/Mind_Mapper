import Foundation
import GRDB

nonisolated struct MemoryRepository: MemoryRepositoryProtocol {
    private let database: DatabaseManager

    init(database: DatabaseManager) {
        self.database = database
    }

    func save(_ memory: Memory) async throws {
        try await save(memory, entities: [], superseding: nil)
    }

    func save(
        _ memory: Memory,
        entities: [MemoryEntity],
        superseding supersededId: String?
    ) async throws {
        do {
            try await database.dbQueue.write { db in
                try MemoryRecord(from: memory).insert(db)

                if let supersededId {
                    try db.execute(
                        sql: "UPDATE memories SET is_superseded = 1 WHERE id = ?",
                        arguments: [supersededId]
                    )
                }

                for entity in entities {
                    try MemoryEntityRecord(from: entity).insert(db)
                }
            }
        } catch {
            AppLogger.error("Failed to save memory \(memory.id)", error: error)
            throw AppError.saveFailed(underlying: error)
        }
    }

    func fetchAll(for userId: String) async throws -> [Memory] {
        do {
            return try await database.dbQueue.read { db in
                try MemoryRecord
                    .filter(Column("user_id") == userId)
                    .order(Column("created_at").desc)
                    .fetchAll(db)
                    .map(\.domainModel)
            }
        } catch {
            AppLogger.error("Failed to fetch memories for user \(userId)", error: error)
            throw AppError.loadFailed(underlying: error)
        }
    }

    func fetch(id: String) async throws -> Memory? {
        do {
            return try await database.dbQueue.read { db in
                try MemoryRecord.fetchOne(db, key: id)?.domainModel
            }
        } catch {
            AppLogger.error("Failed to fetch memory \(id)", error: error)
            throw AppError.loadFailed(underlying: error)
        }
    }

    func fetchEntities(for memoryId: String) async throws -> [MemoryEntity] {
        do {
            return try await database.dbQueue.read { db in
                try MemoryEntityRecord
                    .filter(Column("memory_id") == memoryId)
                    .fetchAll(db)
                    .map(\.domainModel)
            }
        } catch {
            AppLogger.error("Failed to fetch entities for memory \(memoryId)", error: error)
            throw AppError.loadFailed(underlying: error)
        }
    }

    func delete(_ memoryId: String) async throws {
        do {
            try await database.dbQueue.write { db in
                // If this memory replaced an older fact, restore the older one to RAG
                // visibility — otherwise deleting the replacement would leave the user
                // with no answer for that topic.
                let supersededId = try String.fetchOne(
                    db,
                    sql: "SELECT supersedes_id FROM memories WHERE id = ?",
                    arguments: [memoryId]
                )

                try MemoryEntityRecord
                    .filter(Column("memory_id") == memoryId)
                    .deleteAll(db)
                try VectorRecord
                    .filter(Column("memory_id") == memoryId)
                    .deleteAll(db)

                if let olderId = supersededId {
                    try db.execute(
                        sql: "UPDATE memories SET is_superseded = 0 WHERE id = ?",
                        arguments: [olderId]
                    )
                }

                _ = try MemoryRecord.deleteOne(db, key: memoryId)
            }
        } catch {
            AppLogger.error("Failed to delete memory \(memoryId)", error: error)
            throw AppError.saveFailed(underlying: error)
        }
    }

    func markSuperseded(_ memoryId: String) async throws {
        do {
            try await database.dbQueue.write { db in
                try db.execute(
                    sql: "UPDATE memories SET is_superseded = 1 WHERE id = ?",
                    arguments: [memoryId]
                )
            }
        } catch {
            AppLogger.error("Failed to mark memory \(memoryId) superseded", error: error)
            throw AppError.saveFailed(underlying: error)
        }
    }
}
