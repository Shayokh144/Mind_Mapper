import Foundation

protocol SessionRepositoryProtocol {
    func save(_ session: Session) async throws
    func update(_ session: Session) async throws
    func fetch(id: String) async throws -> Session?
    func fetchAll(for userId: String) async throws -> [Session]
}

protocol MessageRepositoryProtocol {
    func save(_ message: Message) async throws
    func fetchAll(for sessionId: String) async throws -> [Message]
}
