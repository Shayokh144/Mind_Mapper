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

- [ ] **1.** Create `Core/RAG/RAGRetriever.swift`. This is the Stage 1 and Stage 2 implementation — a struct with static methods.
- [ ] **2.** Implement `retrieve(question: String, userId: String) async throws -> [RetrievedChunk]`. Define `RetrievedChunk` struct with fields: memoryId, cleanText, createdAt, isSuperseded, supersedesId, sessionId, similarity, source (either 'vector' or 'entity').
- [ ] **3.** In the retrieve method, run the two retrieval paths: (a) Vector search — call `LLMClient.shared.embed(text: question, tier: .embed)` to get the query vector, then call `VectorStore.shared.search(queryEmbedding:topK:threshold:)` with topK=15 and threshold=0.55 for a broad net. (b) Entity filter — implement `extractEntitiesFromQuestion(_ question: String) async throws -> [String]` using `tier: .nano` with max_tokens 60 to extract up to 4 searchable nouns from the question as a JSON array. Then query `memory_entities` in SQLite with `WHERE entity_value LIKE '%term%'` for each extracted entity.
- [ ] **4.** Merge the two result sets: combine vector results and entity results into one array, de-duplicate by memoryId (keeping higher similarity score if duplicated), sort by similarity descending.
- [ ] **5.** Implement `filterConfident(_ chunks: [RetrievedChunk], threshold: Float) -> [RetrievedChunk]`. Keep chunks where `similarity >= threshold` (use 0.62 as default) OR where `source == 'entity'` (entity matches are always kept as they are exact matches).
- [ ] **6.** Write unit tests using mock data: test that de-duplication keeps the highest similarity score when the same memoryId appears in both vector and entity results. Test that the confidence filter removes low-scoring vector results but keeps all entity matches.
- [ ] **7.** Add a property to `RetrievedChunk` tracking which sessionIds were represented — the Chat Orchestrator will use this count to decide whether to show the 'Found across N conversations' badge.

---

## ✅ Done When

- [ ] 'Where is my blue T-shirt?' → vector search returns the T-shirt memory at high similarity.
- [ ] 'What did I decide for my wife?' → entity filter finds all wife/gift memories regardless of exact phrasing.
- [ ] Same memory appearing in both vector and entity results → appears once in merged output with the higher similarity score.
- [ ] A memory with similarity 0.45 → filtered out by Stage 2 confidence filter.
- [ ] An entity-matched memory with similarity 0.40 → kept by Stage 2 (entity matches bypass the threshold).

---

## 📝 Notes

The topK=15 broad net in vector search is intentional — you want to over-retrieve at Stage 1 and let Stage 2 filter. Entity extraction uses `tier: .nano` with max_tokens=60. If the primary model hits rate limit or quota, `LLMClient` retries with the fallback automatically. If entity extraction fails or returns empty, retrieval still works via vector search alone.
