import Foundation

protocol ReminderRepositoryProtocol: Sendable {
    func save(_ reminder: Reminder) async throws
    func update(_ reminder: Reminder) async throws
    func fetch(id: String) async throws -> Reminder?
    func fetchAll(for userId: String) async throws -> [Reminder]
    func fetchAll(sessionId: String) async throws -> [Reminder]
    func fetchAll(memoryId: String) async throws -> [Reminder]
    func delete(id: String) async throws
    func deleteAll(sessionId: String) async throws
    func deleteAll(memoryId: String) async throws
}
