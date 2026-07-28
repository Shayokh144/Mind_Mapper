import Foundation

protocol DeleteMemoryUseCaseProtocol: Sendable {
    func execute(memoryId: String) async throws
}

/// Deletes one memory and its children. If this memory replaced an older fact
/// (`supersedes_id`), the older memory is restored to RAG visibility.
nonisolated struct DeleteMemoryUseCase: DeleteMemoryUseCaseProtocol {
    private let memoryRepository: MemoryRepositoryProtocol

    init(memoryRepository: MemoryRepositoryProtocol) {
        self.memoryRepository = memoryRepository
    }

    func execute(memoryId: String) async throws {
        try await memoryRepository.delete(memoryId)
    }
}
