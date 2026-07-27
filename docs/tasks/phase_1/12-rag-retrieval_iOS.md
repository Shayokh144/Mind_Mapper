# Build RAG Query Pipeline — Stage 1 & 2: Hybrid Retrieval

---

## Category
`ios`

## Estimated Time
⏱️ 4–6 hours

## Depends On
Task 11 (memory save pipeline and VectorStore complete)

## Related Plan Section
📄 `../planning/execution-plan.md` → Phase 7 — Four-Stage RAG Query Pipeline › Step 7.1 (Stage 1), Step 7.2 (Stage 2) | How RAG Works section — The Four-Stage Pipeline diagram

## Related UI
Chat View — the foundation of every assistant answer bubble for QUERY intent. The 'Found across 2 conversations' ThemeBadge (dark mode mockup) is triggered when results span multiple sessions.

---

## What To Do

- [x] **1.** Create `Core/RAG/RAGRetriever.swift`. This is the Stage 1 and Stage 2 implementation — a struct with static methods.
- [x] **2.** Implement `retrieve(question: String, userId: String) async throws -> [RetrievedChunk]`. Define `RetrievedChunk` struct with fields: memoryId, cleanText, createdAt, isSuperseded, supersedesId, sessionId, similarity, source (either 'vector' or 'entity').
- [x] **3.** In the retrieve method, run the two retrieval paths: (a) Vector search — call `LLMClient.shared.embed(text: question, tier: .embed)` to get the query vector, then call `VectorStore.shared.search(queryEmbedding:topK:threshold:)` with topK=15 and threshold=0.55 for a broad net. (b) Entity filter — implement `extractEntitiesFromQuestion(_ question: String) async throws -> [String]` using `tier: .nano` with max_tokens 60 to extract up to 4 searchable nouns from the question as a JSON array. Then query `memory_entities` in SQLite with `WHERE entity_value LIKE '%term%'` for each extracted entity.
- [x] **4.** Merge the two result sets: combine vector results and entity results into one array, de-duplicate by memoryId (keeping higher similarity score if duplicated), sort by similarity descending.
- [x] **5.** Implement `filterConfident(_ chunks: [RetrievedChunk], threshold: Float) -> [RetrievedChunk]`. Keep chunks where `similarity >= threshold` (use 0.62 as default) OR where `source == 'entity'` (entity matches are always kept as they are exact matches).
- [x] **6.** Write unit tests using mock data: test that de-duplication keeps the highest similarity score when the same memoryId appears in both vector and entity results. Test that the confidence filter removes low-scoring vector results but keeps all entity matches.
- [x] **7.** Add a property to `RetrievedChunk` tracking which sessionIds were represented — the Chat Orchestrator will use this count to decide whether to show the 'Found across N conversations' badge.

---

## ✅ Done When

- [x] 'Where is my blue T-shirt?' → vector search returns the T-shirt memory at high similarity.
- [x] 'What did I decide for my wife?' → entity filter finds all wife/gift memories regardless of exact phrasing.
- [x] Same memory appearing in both vector and entity results → appears once in merged output with the higher similarity score.
- [x] A memory with similarity 0.45 → filtered out by Stage 2 confidence filter.
- [x] An entity-matched memory with similarity 0.40 → kept by Stage 2 (entity matches bypass the threshold).

---

## 📝 Notes

The topK=15 broad net in vector search is intentional — you want to over-retrieve at Stage 1 and let Stage 2 filter. Entity extraction uses `tier: .nano` with max_tokens=60. If the primary model hits rate limit or quota, `LLMClient` retries with the fallback automatically. If entity extraction fails or returns empty, retrieval still works via vector search alone.

**Implementation notes (as shipped):**
- `RAGRetriever` injects `LLMClientProtocol` + `VectorStore` + `DatabaseManager` (same DI pattern as `MemoryExtractor`) — no `.shared` statics on retrieve.
- Static helpers for unit tests: `merge`, `filterConfident`, `RetrievedChunk.representedSessionIds(in:)`.
- `AppContainer.makeRAGRetriever()` wires production deps.
- Entity extraction returns `[]` on failure (does not throw) so vector-only retrieval still works.
- `VectorStore.search` accepts optional `userId` and `includeSuperseded` (RAG retrieve uses `true`; save-time supersede lookup keeps default `false`). `VectorSearchResult` includes `sessionId` / supersede fields for chunk mapping.
- Tests: `MindMapperTests/RAGRetrieverTests.swift`.
