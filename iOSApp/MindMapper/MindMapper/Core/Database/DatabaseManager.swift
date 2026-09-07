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
        migrator.registerMigration("v1_initial", migrate: V1InitialMigration.run)
        migrator.registerMigration("v2_session_pin", migrate: V2SessionPinMigration.run)
        migrator.registerMigration("v3_reminders", migrate: V3RemindersMigration.run)
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
