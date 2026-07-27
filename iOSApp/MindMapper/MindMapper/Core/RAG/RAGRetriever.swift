import Foundation
import GRDB

/// One candidate memory from Stage 1 hybrid retrieval (vector and/or entity).
nonisolated struct RetrievedChunk: Equatable, Sendable {
    let memoryId: String
    let cleanText: String
    let createdAt: Date
    let isSuperseded: Bool
    let supersedesId: String?
    let sessionId: String
    let similarity: Float
    /// `"vector"` or `"entity"`.
    let source: String

    /// Distinct session IDs across chunks — Chat Orchestrator uses the count for
    /// the "Found across N conversations" badge.
    static func representedSessionIds(in chunks: [RetrievedChunk]) -> [String] {
        Array(Set(chunks.map(\.sessionId))).sorted()
    }
}

/// Stage 1–3 of the RAG pipeline (hybrid retrieval, confidence filter, temporal resolution).
///
/// Injected dependencies (not `.shared` statics) so tests can mock the LLM and use
/// an in-memory database. Pure merge/filter/temporal helpers stay static for unit tests.
nonisolated struct RAGRetriever: @unchecked Sendable {
    private let llmClient: LLMClientProtocol
    private let vectorStore: VectorStore
    private let database: DatabaseManager

    /// Baseline similarity assigned to exact entity SQL matches.
    static let entityBaselineSimilarity: Float = 0.7
    static let defaultConfidenceThreshold: Float = 0.62
    static let vectorTopK = 15
    static let vectorThreshold: Float = 0.55

    init(
        llmClient: LLMClientProtocol,
        vectorStore: VectorStore,
        database: DatabaseManager
    ) {
        self.llmClient = llmClient
        self.vectorStore = vectorStore
        self.database = database
    }

    // MARK: - Stage 1

    /// Broad hybrid retrieval: vector similarity + entity structured filter.
    func retrieve(question: String, userId: String) async throws -> [RetrievedChunk] {
        async let embeddingTask = llmClient.embed(text: question, tier: .embed)
        async let entityHintsTask = extractEntitiesFromQuestion(question)

        let queryEmbedding = try await embeddingTask
        let entityHints = await entityHintsTask

        async let vectorTask = vectorStore.search(
            queryEmbedding: queryEmbedding,
            topK: Self.vectorTopK,
            threshold: Self.vectorThreshold,
            userId: userId,
            includeSuperseded: true
        )
        async let entityTask = searchByEntities(hints: entityHints, userId: userId)

        let vectorChunks = try await vectorTask.map(Self.chunk(fromVector:))
        let entityChunks = try await entityTask
        return Self.merge(vectorChunks + entityChunks)
    }

    // MARK: - Stage 2

    /// Keep chunks at/above threshold, or any exact entity match (bypass threshold).
    static func filterConfident(
        _ chunks: [RetrievedChunk],
        threshold: Float = RAGRetriever.defaultConfidenceThreshold
    ) -> [RetrievedChunk] {
        chunks.filter { $0.similarity >= threshold || $0.source == "entity" }
    }

    // MARK: - Stage 3

    /// Chronological order + annotate memories that were later superseded (prompt-only; does not write SQLite).
    static func resolveTemporalOrder(_ chunks: [RetrievedChunk]) -> [RetrievedChunk] {
        let sorted = chunks.sorted { $0.createdAt < $1.createdAt }

        var supersededBy: [String: String] = [:]
        for chunk in sorted {
            if let oldId = chunk.supersedesId {
                supersededBy[oldId] = chunk.cleanText
            }
        }

        return sorted.map { chunk in
            guard let newText = supersededBy[chunk.memoryId] else { return chunk }
            return RetrievedChunk(
                memoryId: chunk.memoryId,
                cleanText: "[OUTDATED → replaced by: \(newText)] \(chunk.cleanText)",
                createdAt: chunk.createdAt,
                isSuperseded: true,
                supersedesId: chunk.supersedesId,
                sessionId: chunk.sessionId,
                similarity: chunk.similarity,
                source: chunk.source
            )
        }
    }

    /// De-duplicate by `memoryId`, keeping the higher similarity score.
    static func merge(_ chunks: [RetrievedChunk]) -> [RetrievedChunk] {
        var bestById: [String: RetrievedChunk] = [:]
        for chunk in chunks {
            if let existing = bestById[chunk.memoryId] {
                if chunk.similarity > existing.similarity {
                    bestById[chunk.memoryId] = chunk
                }
            } else {
                bestById[chunk.memoryId] = chunk
            }
        }
        return bestById.values.sorted { $0.similarity > $1.similarity }
    }

    // MARK: - Entity extraction

    /// Uses `tier: .nano` / max_tokens 60. On failure or empty JSON, returns `[]`
    /// so vector-only retrieval still works.
    func extractEntitiesFromQuestion(_ question: String) async -> [String] {
        let prompt = """
        Extract key searchable nouns from this question (people, objects, topics, places).
        Reply with a JSON array of strings only. Maximum 4 items. No explanation.
        Example: ["wife", "gift", "passport", "drawer"]
        Question: "\(question)"
        """
        do {
            let result = try await llmClient.complete(
                tier: .nano,
                messages: [LLMMessage(role: "user", content: prompt)],
                maxTokens: 60,
                temperature: 0
            )
            let cleaned = MemoryExtractor.stripCodeFences(result)
            guard let data = cleaned.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data)
            else {
                return []
            }
            return decoded
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(4)
                .map { String($0) }
        } catch {
            AppLogger.error("Entity extraction from question failed; continuing with vector search", error: error)
            return []
        }
    }

    // MARK: - Private

    private static func chunk(fromVector result: VectorSearchResult) -> RetrievedChunk {
        RetrievedChunk(
            memoryId: result.memoryId,
            cleanText: result.cleanText,
            createdAt: result.createdAt,
            isSuperseded: result.isSuperseded,
            supersedesId: result.supersedesId,
            sessionId: result.sessionId,
            similarity: result.similarity,
            source: "vector"
        )
    }

    private func searchByEntities(hints: [String], userId: String) async throws -> [RetrievedChunk] {
        guard !hints.isEmpty else { return [] }

        do {
            return try await database.dbQueue.read { db in
                var chunks: [RetrievedChunk] = []
                var seenMemoryIds = Set<String>()

                for hint in hints {
                    let sql = """
                    SELECT m.id, m.clean_text, m.created_at, m.is_superseded,
                           m.supersedes_id, m.session_id
                    FROM memories m
                    JOIN memory_entities me ON me.memory_id = m.id
                    WHERE m.user_id = ? AND me.entity_value LIKE ?
                    ORDER BY m.created_at DESC
                    LIMIT 10
                    """
                    let rows = try Row.fetchAll(
                        db,
                        sql: sql,
                        arguments: [userId, "%\(hint.lowercased())%"]
                    )
                    for row in rows {
                        let memoryId: String = row["id"]
                        guard seenMemoryIds.insert(memoryId).inserted else { continue }
                        chunks.append(
                            RetrievedChunk(
                                memoryId: memoryId,
                                cleanText: row["clean_text"],
                                createdAt: row["created_at"],
                                isSuperseded: row["is_superseded"],
                                supersedesId: row["supersedes_id"],
                                sessionId: row["session_id"],
                                similarity: Self.entityBaselineSimilarity,
                                source: "entity"
                            )
                        )
                    }
                }
                return chunks
            }
        } catch {
            AppLogger.error("Entity SQL filter failed", error: error)
            throw AppError.loadFailed(underlying: error)
        }
    }
}
