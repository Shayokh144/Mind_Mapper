import Foundation

protocol MemoryRepositoryProtocol {
    func save(_ memory: Memory) async throws
    /// Atomic write: memory + entities + optional supersede of an older row.
    func save(
        _ memory: Memory,
        entities: [MemoryEntity],
        superseding supersededId: String?
    ) async throws
    func fetchAll(for userId: String) async throws -> [Memory]
    func fetch(id: String) async throws -> Memory?
    func fetchEntities(for memoryId: String) async throws -> [MemoryEntity]
    func delete(_ memoryId: String) async throws
    func markSuperseded(_ memoryId: String) async throws
}
