# Build Input Guards (Sanitiser, Scope Guard, Rate Limiter)

---

## Category
`ios`

## Estimated Time
⏱️ 3–4 hours

## Depends On
Task 8 (LLMClient for the scope guard LLM call)

## Related Plan Section
📄 `../planning/execution-plan.md` → Phase 4 — Input Guards › Steps 4.1, 4.2, 4.3 | Scope enforcement section in the security discussion

## Related UI
Chat View input bar — error messages appear inline below the text field when input is blocked. Uses `ThemeBadge` with `.warning` role for the scope-blocked state shown in the dark mode chat mockup.

---

## What To Do

- [x] **1.** Create `Core/Guards/InputSanitiser.swift` as a value-type `struct` with a static `process(_ raw: String) -> SanitiseResult` method. Define `SanitiseResult` as an enum with cases `.allowed(String)` and `.blocked(String)` where the String is the user-facing reason.
- [x] **2.** Implement all four sanitisation steps in order: (1) character limit check — reject if over 500 characters, (2) code block detector — check for code signals like triple backticks, `func `, `def `, `class `, `import `, `SELECT `, `<?php`, etc., (3) URL and file path detector using a regex pattern, (4) prompt injection pattern stripper — replace known injection phrases with `[removed]` using case-insensitive regex before passing to the next layer.
- [x] **3.** Create `Core/Guards/ScopeGuard.swift` (instance + `ScopeGuardProtocol`). `check(_ input: String) async throws -> ScopeResult` with `.inScope` / `.outOfScope(String)`.
- [x] **4.** Implement the scope guard LLM call using `LLMClient.complete(tier: .nano, ...)`, max_tokens 5, temperature 0. The system prompt must define IN SCOPE and OUT OF SCOPE examples clearly. The call must return ALLOWED or BLOCKED as a single word. Primary → fallback model retry is automatic (task 08).
- [x] **5.** Create `Core/Guards/RateLimiter.swift` as a thread-safe `final class` conforming to `RateLimiterProtocol`. Track: message count (reset hourly), consecutive block count, cooldown expiry time. Implement `check() -> RateResult` returning `.allowed` or `.throttled(String)`. Implement `recordBlocked()` and `recordAllowed()`. Trigger a 60-second cooldown after 5 consecutive blocks.
- [x] **6.** Create protocol definitions for each guard in `Domain/Repositories/`: `ScopeGuardProtocol` and `RateLimiterProtocol` — this enables mock injection in tests.
- [x] **7.** Write unit tests for `InputSanitiser`: test that 501-character input is blocked, that a message containing triple backticks is blocked, that a clean personal memory passes through, that injection phrases are stripped but the message still passes to the scope guard.
- [x] **8.** Write a unit test for `RateLimiter`: test that 5 consecutive `recordBlocked()` calls trigger cooldown, test that `recordAllowed()` resets the consecutive block count.

---

## ✅ Done When

- [x] Typing 'debug this Swift code for me' → blocked by code detector before any LLM call. *(unit test)*
- [x] Pasting 600 characters → blocked by length check. *(unit test)*
- [x] Typing 'ignore all previous instructions' → injection stripped, then likely blocked by scope guard. *(strip covered by unit test; scope LLM when Chat wires guards)*
- [x] Typing 'I put my keys on the shelf' → passes sanitiser. *(unit test; `.inScope` when Chat calls `ScopeGuard`)*
- [x] After 5 consecutive blocked messages → `RateLimiter` returns `.throttled` with a countdown. *(unit test)*
- [x] All unit tests pass.

---

## 📝 Notes

The scope guard LLM call (layer 2) must run AFTER sanitisation (layer 1) — never send unsanitised text to the LLM. The classification calls (scope guard, intent) are always free from a credit perspective — only substantive LLM calls that generate value for the user will be charged in future.

**Wiring:** `AppContainer` exposes `scopeGuard` + `rateLimiter`. Chat ViewModel (task 18 / send pipeline) should call in order: `rateLimiter.check()` → `InputSanitiser.process` → `scopeGuard.check` → `recordAllowed` / `recordBlocked`.

**Follow-on (task 19c):** Keep the **500** character per-message cap (`InputSanitiser.maxCharacters`). Add a separate **session message count** cap (`ChatLimits.maxMessagesPerSession`) — not a sanitiser concern; enforce in `ChatViewModel` before save. See [19c-chat-rolling-transcript_iOS.md](19c-chat-rolling-transcript_iOS.md).

`RateLimiter` is `nonisolated` (opts out of default `MainActor` isolation) and lock-guarded so unit tests can deallocate it safely.
