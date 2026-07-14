# Build Memory Save Pipeline (STORE Intent)

---

## Category
`ios`

## Estimated Time
⏱️ 6–9 hours

## Depends On
Task 6 (database), Task 8 (LLMClient), Task 10 (intent classifier)

## Related Plan Section
📄 `../planning/execution-plan.md` → Phase 6 — Memory Save Pipeline › Steps 6.1, 6.2, 6.3 | How RAG Works section (Save Time phase)

## Related UI
Chat View — the assistant's acknowledgement bubble after a user stores a fact. The 'Saved ✓' indicator. See light mode chat mockup where 'Got it, updated — watch is now the plan' appears as an assistant bubble.

---

## What To Do

- [ ] **1.** Create `Domain/UseCases/SaveMemoryUseCase.swift` with protocol and implementation following ../../iOSApp/AGENT.md Section 4.3 pattern. The use case orchestrates all steps in the save pipeline.
- [ ] **2.** Create `Core/RAG/MemoryExtractor.swift`. Implement `extract(from rawText: String) async throws -> ExtractionResult`. The extraction LLM prompt (using `tier: .mini`) must return JSON with: `clean_text` (normalised fact in standalone form), `entities` array (each with type and value), and `supersedes_hint` (null or a word/phrase indicating this updates an older memory). Use `JSONDecoder` to parse the response — strip markdown code fences before decoding.
- [ ] **3.** Create `Core/VectorStore/VectorStore.swift`. Implement `save(embedding: [Float], memoryId: String) async throws` that serializes the float array to Data and writes a Vector record to SQLite. Implement `search(queryEmbedding: [Float], topK: Int, threshold: Float) async throws -> [VectorSearchResult]` that loads all non-superseded vectors from SQLite, computes cosine similarity for each, filters by threshold, and returns sorted results. Add `cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float` as a pure function.
- [ ] **4.** Create `Data/Repositories/MemoryRepository.swift` conforming to `MemoryRepositoryProtocol`. Implement `save(_ memory: Memory)`, `fetchAll(for userId:)`, `delete(_ memoryId:)`, and `markSuperseded(_ memoryId:)`.
- [ ] **5.** Create `Data/Repositories/VectorRepository.swift` conforming to `VectorRepositoryProtocol`. Implement `save(embedding:memoryId:)` and `search(queryEmbedding:topK:threshold:)`.
- [ ] **6.** Inside `SaveMemoryUseCase.execute()`, implement the six-step save flow: (1) extract clean fact + entities + supersedes hint, (2) if supersedes hint exists, run a quick vector search to find the older memory to mark as superseded, (3) embed the clean text via `LLMClient.shared.embed(text:tier: .embed)`, (4) write Memory row + MemoryEntity rows + supersedes relationship to SQLite atomically in a single GRDB write transaction, (5) write Vector row to SQLite, (6) call LLM to generate a warm acknowledgement reply using `tier: .mini`.
- [ ] **7.** Register `MemoryRepository`, `VectorRepository`, and `SaveMemoryUseCase` in `AppContainer`.
- [ ] **8.** Write integration tests: save a memory, verify SQLite has the correct Memory row with all entity tags, verify the Vector table has a blob of the correct size (6144 bytes), verify a second save with 'instead of' language sets `supersedes_id` and marks the old memory as `is_superseded = true`.

---

## ✅ Done When

- [ ] Say 'I put my blue T-shirt in the 3rd drawer' → Memory row in SQLite with clean_text = 'Blue T-shirt is in the 3rd drawer'.
- [ ] MemoryEntities table has rows: type='location', value='3rd drawer' and type='category', value='clothing'.
- [ ] Vectors table has a row with 6144-byte blob for that memory.
- [ ] Say 'Actually, going with a watch instead of the perfume' → new memory saved, old memory's `is_superseded` = 1.
- [ ] The acknowledgement message returned is a natural, friendly sentence (not JSON).

---

## 📝 Notes

The atomic GRDB write transaction (step 4) is critical — if writing the memory entities fails, the memory row itself must also be rolled back. Use `db.write { ... }` with all inserts inside the same closure to guarantee atomicity. The cosine similarity computation should be moved off the main thread using `Task.detached` when the vector store grows large — add a TODO comment for this optimization.
