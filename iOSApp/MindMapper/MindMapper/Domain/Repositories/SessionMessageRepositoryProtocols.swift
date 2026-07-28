import Foundation

protocol SessionRepositoryProtocol {
    func save(_ session: Session) async throws
    func update(_ session: Session) async throws
    func fetch(id: String) async throws -> Session?
    func fetchAll(for userId: String) async throws -> [Session]
    /// Sessions that have at least one message (empty drafts are omitted).
    func fetchAllWithMessages(for userId: String) async throws -> [Session]
    /// FK-safe cascade: entities → vectors → memories → messages → session (one transaction).
    func deleteCascade(id: String) async throws
    /// Removes draft sessions with no messages (safe: no child rows).
    func purgeEmptySessions(for userId: String) async throws
}

protocol MessageRepositoryProtocol {
    func save(_ message: Message) async throws
    func fetchAll(for sessionId: String) async throws -> [Message]
}
