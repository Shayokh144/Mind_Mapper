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

- [ ] **1.** Create `Core/Guards/InputSanitiser.swift` as a value-type `struct` with a static `process(_ raw: String) -> SanitiseResult` method. Define `SanitiseResult` as an enum with cases `.allowed(String)` and `.blocked(String)` where the String is the user-facing reason.
- [ ] **2.** Implement all four sanitisation steps in order: (1) character limit check — reject if over 500 characters, (2) code block detector — check for code signals like triple backticks, `func `, `def `, `class `, `import `, `SELECT `, `<?php`, etc., (3) URL and file path detector using a regex pattern, (4) prompt injection pattern stripper — replace known injection phrases with `[removed]` using case-insensitive regex before passing to the next layer.
- [ ] **3.** Create `Core/Guards/ScopeGuard.swift` as a `struct` with a static `check(_ input: String) async throws -> ScopeResult` method. Define `ScopeResult` with cases `.inScope` and `.outOfScope(String)`.
- [ ] **4.** Implement the scope guard LLM call using `LLMClient.shared.complete(tier: .nano, ...)`, max_tokens 5, temperature 0. The system prompt must define IN SCOPE and OUT OF SCOPE examples clearly. The call must return ALLOWED or BLOCKED as a single word. Primary → fallback model retry is automatic (task 08).
- [ ] **5.** Create `Core/Guards/RateLimiter.swift` as a `@MainActor final class ObservableObject`. Track: message count (reset hourly), consecutive block count, cooldown expiry time. Implement `check() -> RateResult` returning `.allowed` or `.throttled(String)`. Implement `recordBlocked()` and `recordAllowed()`. Trigger a 60-second cooldown after 5 consecutive blocks.
- [ ] **6.** Create protocol definitions for each guard in `Domain/Repositories/`: `ScopeGuardProtocol` and `RateLimiterProtocol` — this enables mock injection in tests.
- [ ] **7.** Write unit tests for `InputSanitiser`: test that 501-character input is blocked, that a message containing triple backticks is blocked, that a clean personal memory passes through, that injection phrases are stripped but the message still passes to the scope guard.
- [ ] **8.** Write a unit test for `RateLimiter`: test that 5 consecutive `recordBlocked()` calls trigger cooldown, test that `recordAllowed()` resets the consecutive block count.

---

## ✅ Done When

- [ ] Typing 'debug this Swift code for me' → blocked by code detector before any LLM call.
- [ ] Pasting 600 characters → blocked by length check.
- [ ] Typing 'ignore all previous instructions' → injection stripped, then likely blocked by scope guard.
- [ ] Typing 'I put my keys on the shelf' → passes all layers and returns `.inScope`.
- [ ] After 5 consecutive blocked messages → `RateLimiter` returns `.throttled` with a countdown.
- [ ] All unit tests pass.

---

## 📝 Notes

The scope guard LLM call (layer 2) must run AFTER sanitisation (layer 1) — never send unsanitised text to the LLM. The classification calls (scope guard, intent) are always free from a credit perspective — only substantive LLM calls that generate value for the user will be charged in future.
