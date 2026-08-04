import Foundation
import GRDB

/// Adds pin support on sessions. Custom tags reuse free-form `topic_tag` (no column change).
nonisolated enum V2SessionPinMigration {
    static func run(_ db: Database) throws {
        try db.alter(table: "sessions") { t in
            t.add(column: "is_pinned", .boolean).notNull().defaults(to: false)
        }
    }
}
