import Foundation
import GRDB

/// Local reminders tied to optional memory/session for notification tap routing.
nonisolated enum V3RemindersMigration {
    static func run(_ db: Database) throws {
        try db.create(table: "reminders") { t in
            t.column("id", .text).primaryKey()
            t.column("user_id", .text).notNull().references("users")
            t.column("memory_id", .text).references("memories")
            t.column("session_id", .text).references("sessions")
            t.column("title", .text).notNull()
            t.column("body", .text).notNull()
            t.column("fire_at", .datetime).notNull()
            t.column("recurrence", .text).notNull()
            t.column("notification_id", .text).notNull()
            t.column("is_enabled", .boolean).notNull().defaults(to: true)
            t.column("created_at", .datetime).notNull()
            t.column("updated_at", .datetime).notNull()
        }
        try db.create(index: "idx_reminders_user", on: "reminders", columns: ["user_id"])
        try db.create(index: "idx_reminders_session", on: "reminders", columns: ["session_id"])
        try db.create(index: "idx_reminders_memory", on: "reminders", columns: ["memory_id"])
    }
}
