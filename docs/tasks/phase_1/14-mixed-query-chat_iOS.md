# Build Mixed Query Pipeline & Chat Orchestrator

---

## Category
`ios`

## Estimated Time
⏱️ 5–7 hours

## Depends On
Tasks 9, 10, 11, 12, 13 (all guard and pipeline components)

## Related Plan Section
📄 `../planning/execution-plan.md` → Phase 8 — Mixed Query Pipeline › Step 8.1 | Phase 10 — Chat Orchestrator › Step 10.1 | ../../iOSApp/AGENT.md › Section 3.2 (ViewModel), Section 6.2 (async let parallelism)

## Related UI
Chat View — the central hub that drives the entire chat experience. All message bubbles, loading indicator, error banner, and input bar are controlled by the ChatViewModel built here.

---

## What To Do

- [x] **1.** Create `Core/RAG/MixedQueryService.swift`. Inject `RAGAnswerServiceProtocol` + `LLMClientProtocol`. Implement `answer(question:sessionId:userId:) async throws -> RAGAnswer` (or a thin wrapper that still exposes `representedSessionIds` from the memory path). Use `async let` to run `ragAnswerService.answer(...)` and a general knowledge `tier: .full` call in parallel. Await both, then make a third merge call using `tier: .mini` that starts with the user's stored memories and then adds general suggestions. Use `memoryAnswer.text` in the merge prompt — not a bare `String` from a static call.
- [x] **2.** Create `Domain/UseCases/MixedQueryUseCase.swift` wrapping `MixedQueryService`. Register in `AppContainer`.
- [x] **3.** Refactor `Core/ChatOrchestrator.swift` to match the ../../iOSApp/AGENT.md architecture: rename it to `Features/Chat/ChatViewModel.swift`, mark it `@MainActor final class ObservableObject`, inject all use cases via `init` (do not use `.shared` singletons inside it). *(No prior ChatOrchestrator existed — implemented greenfield `ChatViewModel` + `ChatDependencies`.)*
- [x] **4.** Implement `sendMessage(_ rawInput: String) async` in `ChatViewModel`. The full pipeline in order: (1) RateLimiter.check(), (2) InputSanitiser.process(), (3) save user message to SQLite, (4) ScopeGuard.check(), (5) ClassifyIntentUseCase.execute(), (6) route to SaveMemoryUseCase / QueryMemoryUseCase / MixedQueryUseCase / casual LLM call based on intent. For QUERY (and MIXED), set `lastAnswerSessionCount = answer.representedSessionIds.count` for the ThemeBadge. Use `defer { isLoading = false }` to guarantee loading state resets.
- [x] **5.** Implement `loadSession(_ session: Session) async` that fetches all messages for the session from SQLite and populates `@Published var messages`.
- [x] **6.** Implement `startNewSession(userId: String) async throws -> Session` that creates a session row in SQLite and resets the message list.
- [x] **7.** Map all `AppError` types to user-facing `errorMessage` strings — never show raw error descriptions.
- [x] **8.** Register `ChatViewModel` factory method `makeChatViewModel(sessionId:router:)` in `AppContainer`.
- [x] **9.** Write unit tests for `ChatViewModel` using mock use cases: test that a STORE message calls `SaveMemoryUseCase.execute()`, test that a QUERY message calls `QueryMemoryUseCase.execute()`, test that a scope-blocked message sets `errorMessage` and does NOT call any use case, test that `isLoading` is always false after completion (including error paths).

---

## ✅ Done When

- [x] Sending 'I put my keys on the table' → SaveMemoryUseCase called, acknowledgement bubble appears. *(unit test)*
- [x] 'Where are my keys?' → QueryMemoryUseCase called, answer bubble appears with retrieved memory. *(unit test)*
- [x] 'What dress ideas did we discuss and suggest more?' → MixedQueryUseCase called, parallel calls fire, merged answer appears. *(unit + MixedQueryService tests)*
- [x] Scope-blocked / code-blocked messages → error message appears, no use case called. *(note: "Debug this code" hits InputSanitiser via `"debug this"`; ScopeGuard tested with trivia)*
- [x] `isLoading` is always false after any path completes — confirmed in unit tests.
- [x] Unit tests pass with mock dependencies.

---

## 📝 Notes

This is the most complex single task in the project. Break it into two sessions: first build and test `MixedQueryService`, then build `ChatViewModel`. Do not attempt both in one sitting. The `async let` pattern for parallel execution in `MixedQueryService` is documented in ../../iOSApp/AGENT.md Section 6.2.

**DI:** Inject `RAGAnswerService` / `QueryMemoryUseCase` via `AppContainer.makeQueryMemoryUseCase()` (Stages 1–4 already DI-based). Do not add new `.shared` statics.

**Task 13 return type:** `QueryMemoryUseCase.execute` → `RAGAnswer` with `text` + `representedSessionIds` (not a bare `String`). Chat should publish `lastAnswerSessionCount` from that for task 18’s badge.

**As shipped:**
- `ChatDependencies` bundles guards + use cases + message/session repos (keeps VM init lean).
- Thin `SessionRepository` / `MessageRepository` added for chat persistence (also used by later session-list / close tasks).
- Minimal `AppRouter` in `Core/Navigation/` so `makeChatViewModel(sessionId:router:)` compiles; task 16 expands Root/Tab wiring.
- `makeChatViewModel` returns `nil` when unauthenticated.
- Tests: `ChatViewModelTests`, `MixedQueryServiceTests`.

**Follow-on (task 19c):** Rolling transcript into `route` / use cases + session message cap — [19c-chat-rolling-transcript_iOS.md](19c-chat-rolling-transcript_iOS.md). Extend shipped `ChatViewModel`; do not recreate the orchestrator.
