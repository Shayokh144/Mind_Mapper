# Build Intent Classifier

---

## Category
`ios`

## Estimated Time
⏱️ 2–3 hours

## Depends On
Task 8 (LLMClient), Task 9 (guards complete — classifier runs after guards pass)

## Related Plan Section
📄 `../planning/execution-plan.md` → Phase 5 — Intent Classification › Step 5.1 | ../../iOSApp/AGENT.md › Section 4.3 (Use Cases)

## Related UI
None — internal routing logic. Determines which pipeline the Chat Orchestrator (Task 14) routes to.

---

## What To Do

- [x] **1.** Create `Domain/Models/Intent.swift` as an enum with four cases: `.store` (user is sharing a fact), `.query` (user is asking about something stored), `.mixed` (needs both memory and general knowledge), `.chat` (casual conversation).
- [x] **2.** Create `Domain/UseCases/ClassifyIntentUseCase.swift` with a protocol `ClassifyIntentUseCaseProtocol` and a concrete `ClassifyIntentUseCase` class. See ../../iOSApp/AGENT.md Section 4.3 for the use case pattern.
- [x] **3.** Implement the classification prompt inside the use case. Use `LLMClient.shared.complete(tier: .nano, ...)` with max_tokens 5, temperature 0. The prompt must include clear examples of each intent: STORE ('I put my passport in the drawer'), QUERY ('Where is my passport?'), MIXED ('What dress ideas did we discuss and can you suggest more?'), CHAT ('Thanks!'). Do not pass raw model strings — fallback on rate limit / quota is handled by `LLMClient` (task 08).
- [x] **4.** Parse the single-word response and return the matching `Intent` enum case. Default to `.chat` if the response is unrecognised.
- [x] **5.** Register `ClassifyIntentUseCase` in `AppContainer.swift` with the `makeClassifyIntentUseCase()` factory method.
- [x] **6.** Write unit tests using a `MockLLMService` that returns predetermined responses. Test all four intent paths. Test that an unrecognised response defaults to `.chat`.

---

## ✅ Done When

- [x] 'I put my blue T-shirt in the 3rd drawer' → `.store`
- [x] 'Where is my blue T-shirt?' → `.query`
- [x] 'What gift ideas did we discuss, and suggest some more?' → `.mixed`
- [x] 'Thanks!' → `.chat`
- [x] Unrecognised LLM response → `.chat` (safe default)
- [x] Unit tests pass with mock LLM service.

---

## 📝 Notes

This use case must never call `DatabaseManager` or `VectorStore` — it is a pure LLM classification step. If the intent is unclear, the safe default is `.chat`, which triggers only a simple conversational reply — never a memory save or retrieval.

**Wiring:** `AppContainer.makeClassifyIntentUseCase()` injects `LLMClient.shared` via `LLMClientProtocol`. Chat Orchestrator (task 14) calls `execute` after guards pass.
