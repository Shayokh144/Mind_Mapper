# Build RAG Query Pipeline — Stage 3 & 4: Temporal Resolution + LLM Synthesis

---

## Category

`ios`

## Estimated Time

⏱️ 4–6 hours

## Depends On

Task 12 (Stages 1 and 2 complete)

## Related Plan Section

📄 `../planning/execution-plan.md` → Phase 7 — Four-Stage RAG Query Pipeline › Steps 7.3 (Stage 3), 7.4 (Stage 4) | How RAG Works section — full data journey example

## Related UI

Chat View assistant bubble — the final answer the user reads. For cross-session queries, the 'Found across N conversations' ThemeBadge appears below the answer bubble.

---

## What To Do

- [x] **1.** Add `static func resolveTemporalOrder(_ chunks: [RetrievedChunk]) -> [RetrievedChunk]` to `RAGRetriever.swift`. Sort chunks by `createdAt` ascending (oldest first). Walk the `supersedesId` chain: build a dictionary mapping oldMemoryId → newCleanText. For each chunk whose ID appears as a key in this map, annotate its `cleanText` with the prefix `[OUTDATED → replaced by: newText]` and set `isSuperseded = true`.
- [x] **2.** Create `Core/RAG/RAGAnswerService.swift`. Inject `RAGRetriever` (via `AppContainer.makeRAGRetriever()`) + `LLMClientProtocol` + DB access for recent messages. Implement `answer(question: String, sessionId: String, userId: String) async throws -> RAGAnswer`.
- [x] **3.** Inside `RAGAnswerService.answer()`, chain the four stages: `try await retriever.retrieve(...)` (Stage 1 instance method), `RAGRetriever.filterConfident(...)` (Stage 2 static), if confident results are empty return a 'no memory found' reply via `tier: .mini`, otherwise `RAGRetriever.resolveTemporalOrder(...)` (Stage 3 static), then build the Stage 4 prompt. Use `RetrievedChunk.representedSessionIds(in:)` for the cross-session badge (`RAGAnswer.representedSessionIds`).
- [x] **4.** Load the last 4 messages from the current session from SQLite to include as recent conversation context in the prompt.
- [x] **5.** Build the Stage 4 system prompt with explicit instructions to: answer only from provided memories, acknowledge history when decisions changed, note [OUTDATED] memories briefly, and use approximate relative dates like 'back in March' or 'more recently'.
- [x] **6.** Format memories for the prompt as numbered list with date prefix: `[1] [Mar 3] Blue T-shirt is in the 3rd drawer`.
- [x] **7.** Call `llmClient.complete(tier: .mini, ...)` with the assembled prompt, max_tokens=400, temperature=0.4.
- [x] **8.** Create `Domain/UseCases/QueryMemoryUseCase.swift` wrapping `RAGAnswerService.answer()`. Register in `AppContainer` (`makeRAGAnswerService()` / `makeQueryMemoryUseCase()`).
- [x] **9.** Write an integration test for the full cross-session scenario: save 3 memories across different sessions about a topic, query the topic, verify the answer references all three chronologically and identifies the superseded memory correctly.

---

## ✅ Done When

- [x] Query 'Where is my passport?' after storing it twice (second time with 'moved to safe') → answer says 'You originally kept it in the drawer but moved it to the safe'. *(integration test with mocked synthesis)*
- [x] Query 'What did I decide to get my wife?' after 3 separate sessions → answer synthesises all three sessions chronologically. *(integration test; Stage 4 prompt verified)*
- [x] Query about a topic with no stored memories → returns a graceful 'I don't have anything stored about that' message.
- [x] The Stage 4 LLM prompt contains numbered memories with dates and the recent chat history.
- [x] Integration test passes.

---

## 📝 Notes

The temporal resolution logic (Stage 3) modifies only the text passed to the LLM prompt — it does NOT modify the SQLite records. The `is_superseded` flag in SQLite is set only by the save pipeline when a new memory explicitly supersedes an old one. Stage 3 simply reads that flag and formats the output accordingly.

**Depends on task 12 as shipped:** `RAGRetriever` is DI-based (`init(llmClient:vectorStore:database:)`), not `static retrieve` / `VectorStore.shared`. Stages 1–2 API:

```swift
let raw = try await retriever.retrieve(question: question, userId: userId)
let confident = RAGRetriever.filterConfident(raw)
let sessions = RetrievedChunk.representedSessionIds(in: confident) // badge count
```

**As shipped (task 13):**
- `RAGAnswer` returns `text` + `representedSessionIds` for the Chat badge.
- RAG vector search uses `includeSuperseded: true` so Stage 3 can annotate outdated rows (save-time supersede lookup still excludes them via default `false`).
- Tests: `MindMapperTests/RAGAnswerServiceTests.swift`.
