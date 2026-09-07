import Foundation
import GRDB

/// Local vector index over memory embeddings (cosine similarity).
nonisolated struct VectorStore: Sendable {
    private let database: DatabaseManager

    init(database: DatabaseManager) {
        self.database = database
    }

    func save(embedding: [Float], memoryId: String) async throws {
        let vector = Vector(
            memoryId: memoryId,
            embedding: EmbeddingCodec.encode(embedding)
        )
        do {
            try await database.dbQueue.write { db in
                try VectorRecord(from: vector).insert(db)
            }
        } catch {
            AppLogger.error("Failed to save vector for memory \(memoryId)", error: error)
            throw AppError.saveFailed(underlying: error)
        }
    }

    func search(
        queryEmbedding: [Float],
        topK: Int = 15,
        threshold: Float = 0.55,
        userId: String? = nil,
        includeSuperseded: Bool = false
    ) async throws -> [VectorSearchResult] {
        let pairs: [(embedding: Data, memory: Memory)]
        do {
            pairs = try await database.dbQueue.read { db in
                var memoryQuery = MemoryRecord.all()
                if !includeSuperseded {
                    memoryQuery = memoryQuery.filter(Column("is_superseded") == false)
                }
                if let userId {
                    memoryQuery = memoryQuery.filter(Column("user_id") == userId)
                }
                let memories = try memoryQuery.fetchAll(db)
                let memoryById = Dictionary(uniqueKeysWithValues: memories.map { ($0.id, $0) })
                let vectors = try VectorRecord.fetchAll(db)
                return vectors.compactMap { record -> (Data, Memory)? in
                    guard let memoryRecord = memoryById[record.memoryId] else { return nil }
                    return (record.embedding, memoryRecord.domainModel)
                }
            }
        } catch {
            AppLogger.error("Failed to load vectors for search", error: error)
            throw AppError.loadFailed(underlying: error)
        }

        // TODO: Move cosine similarity off the main thread (`Task.detached`) when the vector store grows large.
        let scored = Self.score(
            pairs: pairs,
            queryEmbedding: queryEmbedding,
            threshold: threshold
        )

        return Array(scored.sorted { $0.similarity > $1.similarity }.prefix(topK))
    }

    static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0
        var magA: Float = 0
        var magB: Float = 0
        for index in a.indices {
            let av = a[index]
            let bv = b[index]
            dot += av * bv
            magA += av * av
            magB += bv * bv
        }
        let denominator = sqrt(magA) * sqrt(magB)
        guard denominator > 0 else { return 0 }
        return dot / denominator
    }

    private static func score(
        pairs: [(embedding: Data, memory: Memory)],
        queryEmbedding: [Float],
        threshold: Float
    ) -> [VectorSearchResult] {
        pairs.compactMap { pair in
            let embedding = EmbeddingCodec.decode(pair.embedding)
            let score = cosineSimilarity(queryEmbedding, embedding)
            guard score >= threshold else { return nil }
            return VectorSearchResult(
                memoryId: pair.memory.id,
                cleanText: MemoryLinkPreserver.mergingLinks(
                    from: pair.memory.rawText,
                    into: pair.memory.cleanText
                ),
                similarity: score,
                createdAt: pair.memory.createdAt,
                sessionId: pair.memory.sessionId,
                isSuperseded: pair.memory.isSuperseded,
                supersedesId: pair.memory.supersedesId
            )
        }
    }
}
