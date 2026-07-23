import Foundation

protocol AuthRepositoryProtocol: Sendable {
    func upsert(_ user: User) async throws
    func fetch(id: String) async throws -> User?
}
