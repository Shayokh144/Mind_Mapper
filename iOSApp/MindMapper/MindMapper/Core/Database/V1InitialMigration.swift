import Foundation
import GRDB

/// V1 schema: local profile + sessions/messages/memories/vectors.
nonisolated enum V1InitialMigration {
    static func run(_ db: Database) throws {
        try createUsersTable(db)
        try createSessionsTable(db)
        try createMessagesTable(db)
        try createMemoriesTable(db)
        try createMemoryEntitiesTable(db)
        try createVectorsTable(db)
        try createIndexes(db)
    }

    private static func createUsersTable(_ db: Database) throws {
        try db.create(table: "users") { t in
            t.column("id", .text).primaryKey()
            t.column("email", .text).notNull()
            t.column("display_name", .text)
            t.column("created_at", .datetime).notNull()
        }
    }

    private static func createSessionsTable(_ db: Database) throws {
        try db.create(table: "sessions") { t in
            t.column("id", .text).primaryKey()
            t.column("user_id", .text).notNull().references("users")
            t.column("title", .text)
            t.column("topic_tag", .text)
            t.column("summary", .text)
            t.column("created_at", .datetime).notNull()
            t.column("updated_at", .datetime).notNull()
        }
    }

    private static func createMessagesTable(_ db: Database) throws {
        try db.create(table: "messages") { t in
            t.column("id", .text).primaryKey()
            t.column("session_id", .text).notNull().references("sessions")
            t.column("role", .text).notNull()
            t.column("content", .text).notNull()
            t.column("created_at", .datetime).notNull()
        }
    }

    private static func createMemoriesTable(_ db: Database) throws {
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
    }

    private static func createMemoryEntitiesTable(_ db: Database) throws {
        try db.create(table: "memory_entities") { t in
            t.column("id", .text).primaryKey()
            t.column("memory_id", .text).notNull().references("memories")
            t.column("entity_type", .text).notNull()
            t.column("entity_value", .text).notNull()
        }
    }

    private static func createVectorsTable(_ db: Database) throws {
        try db.create(table: "vectors") { t in
            t.column("id", .text).primaryKey()
            t.column("memory_id", .text).notNull().unique().references("memories")
            t.column("embedding", .blob).notNull()
            t.column("created_at", .datetime).notNull()
        }
    }

    private static func createIndexes(_ db: Database) throws {
        try db.create(index: "idx_messages_session", on: "messages", columns: ["session_id"])
        try db.create(index: "idx_memories_user", on: "memories", columns: ["user_id"])
        try db.create(
            index: "idx_entities_lookup",
            on: "memory_entities",
            columns: ["entity_type", "entity_value"]
        )
    }
}
