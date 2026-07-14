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

- [ ] **1.** Create `Core/RAG/MixedQueryService.swift`. Implement `answer(question:sessionId:userId:) async throws -> String`. Use `async let` to run `RAGAnswerService.answer()` and a general knowledge `tier: .full` call in parallel. Await both results, then make a third merge call using `tier: .mini` to produce a single coherent response that starts with the user's stored memories and then adds general suggestions. All tiers use primary → fallback automatically via `LLMClient`.
- [ ] **2.** Create `Domain/UseCases/MixedQueryUseCase.swift` wrapping `MixedQueryService`. Register in `AppContainer`.
- [ ] **3.** Refactor `Core/ChatOrchestrator.swift` to match the ../../iOSApp/AGENT.md architecture: rename it to `Features/Chat/ChatViewModel.swift`, mark it `@MainActor final class ObservableObject`, inject all use cases via `init` (do not use `.shared` singletons inside it).
- [ ] **4.** Implement `sendMessage(_ rawInput: String) async` in `ChatViewModel`. The full pipeline in order: (1) RateLimiter.check(), (2) InputSanitiser.process(), (3) save user message to SQLite, (4) ScopeGuard.check(), (5) ClassifyIntentUseCase.execute(), (6) route to SaveMemoryUseCase / QueryMemoryUseCase / MixedQueryUseCase / casual LLM call based on intent. Use `defer { isLoading = false }` to guarantee loading state resets.
- [ ] **5.** Implement `loadSession(_ session: Session) async` that fetches all messages for the session from SQLite and populates `@Published var messages`.
- [ ] **6.** Implement `startNewSession(userId: String) async throws -> Session` that creates a session row in SQLite and resets the message list.
- [ ] **7.** Map all `AppError` types to user-facing `errorMessage` strings — never show raw error descriptions.
- [ ] **8.** Register `ChatViewModel` factory method `makeChatViewModel(sessionId:router:)` in `AppContainer`.
- [ ] **9.** Write unit tests for `ChatViewModel` using mock use cases: test that a STORE message calls `SaveMemoryUseCase.execute()`, test that a QUERY message calls `QueryMemoryUseCase.execute()`, test that a scope-blocked message sets `errorMessage` and does NOT call any use case, test that `isLoading` is always false after completion (including error paths).

---

## ✅ Done When

- [ ] Sending 'I put my keys on the table' → SaveMemoryUseCase called, acknowledgement bubble appears.
- [ ] 'Where are my keys?' → QueryMemoryUseCase called, answer bubble appears with retrieved memory.
- [ ] 'What dress ideas did we discuss and suggest more?' → MixedQueryUseCase called, parallel calls fire, merged answer appears.
- [ ] 'Debug this code' → blocked at scope guard, error message appears, no use case called.
- [ ] `isLoading` is always false after any path completes — confirmed in unit tests.
- [ ] Unit tests pass with mock dependencies.

---

## 📝 Notes

This is the most complex single task in the project. Break it into two sessions: first build and test `MixedQueryService`, then build `ChatViewModel`. Do not attempt both in one sitting. The `async let` pattern for parallel execution in `MixedQueryService` is documented in ../../iOSApp/AGENT.md Section 6.2.
