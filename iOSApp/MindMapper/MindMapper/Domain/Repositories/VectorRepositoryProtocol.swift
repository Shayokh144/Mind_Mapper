import Foundation

struct VectorSearchResult: Equatable, Sendable {
    let memoryId: String
    let cleanText: String
    let similarity: Float
    let createdAt: Date
}

protocol VectorRepositoryProtocol {
    func save(embedding: [Float], memoryId: String) async throws
    func search(
        queryEmbedding: [Float],
        topK: Int,
        threshold: Float
    ) async throws -> [VectorSearchResult]
}
