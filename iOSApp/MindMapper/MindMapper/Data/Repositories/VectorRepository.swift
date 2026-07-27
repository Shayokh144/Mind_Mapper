import Foundation

nonisolated struct VectorRepository: VectorRepositoryProtocol {
    private let store: VectorStore

    init(database: DatabaseManager) {
        self.store = VectorStore(database: database)
    }

    init(store: VectorStore) {
        self.store = store
    }

    func save(embedding: [Float], memoryId: String) async throws {
        try await store.save(embedding: embedding, memoryId: memoryId)
    }

    func search(
        queryEmbedding: [Float],
        topK: Int,
        threshold: Float
    ) async throws -> [VectorSearchResult] {
        try await store.search(
            queryEmbedding: queryEmbedding,
            topK: topK,
            threshold: threshold
        )
    }
}
