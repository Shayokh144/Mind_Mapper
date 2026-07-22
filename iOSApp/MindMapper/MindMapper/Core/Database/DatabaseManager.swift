import Foundation
import GRDB

/// Owns the on-device SQLite database (`memory.db`) and runs migrations.
///
/// Opted out of the project's default MainActor isolation so GRDB's `DatabaseQueue`
/// can run work off the main thread.
nonisolated final class DatabaseManager: Sendable {
    /// Documents/`memory.db` singleton. `nil` if open/migrate failed (see console / AppLogger).
    static let shared: DatabaseManager? = {
        do {
            let manager = try DatabaseManager()
            AppLogger.info("Database opened at \(documentsDatabasePath)")
            return manager
        } catch {
            AppLogger.error("Failed to open or migrate memory.db", error: error)
            return nil
        }
    }()

    let dbQueue: DatabaseQueue

    /// Opens (or creates) `memory.db` in the app Documents directory and migrates.
    init() throws {
        guard let documentsURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first
        else {
            throw DatabaseManagerError.documentsDirectoryUnavailable
        }
        let path = documentsURL.appendingPathComponent("memory.db").path
        dbQueue = try DatabaseQueue(path: path)
        try migrate()
    }

    /// Injected queue for unit tests (typically an in-memory `DatabaseQueue`).
    init(dbQueue: DatabaseQueue) throws {
        self.dbQueue = dbQueue
        try migrate()
    }

    /// Absolute path to Documents/`memory.db`.
    static var documentsDatabasePath: String {
        let documents = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first
        return documents?
            .appendingPathComponent("memory.db")
            .path ?? "(documents unavailable)/memory.db"
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_initial") { db in
            // USERS — local profile only (auth handled by Supabase)
            try db.create(table: "users") { t in
                t.column("id", .text).primaryKey()
                t.column("email", .text).notNull()
                t.column("display_name", .text)
                t.column("created_at", .datetime).notNull()
            }

            // SESSIONS — each conversation is a session
            try db.create(table: "sessions") { t in
                t.column("id", .text).primaryKey()
                t.column("user_id", .text).notNull().references("users")
                t.column("title", .text)
                t.column("topic_tag", .text)
                t.column("summary", .text)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }

            // MESSAGES — every chat turn
            try db.create(table: "messages") { t in
                t.column("id", .text).primaryKey()
                t.column("session_id", .text).notNull().references("sessions")
                t.column("role", .text).notNull()
                t.column("content", .text).notNull()
                t.column("created_at", .datetime).notNull()
            }

            // MEMORIES — extracted, normalised facts
            try db.create(table: "memories") { t in
                t.column("id", .text).primaryKey()
                t.column("session_id", .text).notNull().references("sessions")
                t.column("user_id", .text).notNull()
                t.column("raw_text", .text).notNull()
                t.column("clean_text", .text).notNull()
                t.column("supersedes_id", .text)
                t.column("is_superseded", .boolean).notNull().defaults(to: false)
                t.column("created_at", .datetime).notNull()
            }

            // MEMORY_ENTITIES — structured tags per memory
            try db.create(table: "memory_entities") { t in
                t.column("id", .text).primaryKey()
                t.column("memory_id", .text).notNull().references("memories")
                t.column("entity_type", .text).notNull()
                t.column("entity_value", .text).notNull()
            }

            // VECTORS — float embeddings per memory (binary blob)
            try db.create(table: "vectors") { t in
                t.column("id", .text).primaryKey()
                t.column("memory_id", .text).notNull().unique().references("memories")
                t.column("embedding", .blob).notNull()
                t.column("created_at", .datetime).notNull()
            }

            try db.create(index: "idx_messages_session", on: "messages", columns: ["session_id"])
            try db.create(index: "idx_memories_user", on: "memories", columns: ["user_id"])
            try db.create(
                index: "idx_entities_lookup",
                on: "memory_entities",
                columns: ["entity_type", "entity_value"]
            )
        }

        try migrator.migrate(dbQueue)
    }
}

enum DatabaseManagerError: LocalizedError {
    case documentsDirectoryUnavailable

    var errorDescription: String? {
        switch self {
        case .documentsDirectoryUnavailable:
            return "Could not resolve the app Documents directory."
        }
    }
}
