import Foundation

nonisolated struct Vector: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var memoryId: String
    /// Serialized `[Float]` embedding blob (1536 × 4 bytes when using OpenAI embeddings).
    var embedding: Data
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        memoryId: String,
        embedding: Data,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.memoryId = memoryId
        self.embedding = embedding
        self.createdAt = createdAt
    }
}
