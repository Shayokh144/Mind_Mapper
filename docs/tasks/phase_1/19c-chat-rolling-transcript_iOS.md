# Chat Rolling Transcript & Session Message Cap

---

## Category
`ios`

## Estimated Time
⏱️ 3–5 hours

## Depends On
Task 14 (`ChatViewModel` / intent routing), Task 18 (`ChatView` input bar), Task 19b (stop / incomplete-turn UX), Task 11–13 (STORE / QUERY prompts — extend, do not recreate)

## Related Plan Section
📄 `../planning/execution-plan.md` → Phase 11 — Step 11.2 Chat Screen | Phase 7 Stage 4 (recent chat history) | `iOSApp/AGENT.md` › §3.2 ViewModel, §6 async

## Related UI
`ChatView` input bar: keep **500 character** per-message limit; add **session full** state when message cap hit (disable send + `ThemeBadge` / `errorMessage`). LLM replies should feel multi-turn (resolve “it” / “the file” from earlier bubbles in the same session).

## Related learning
📄 [`../learning/chat-session-message-context.md`](../learning/chat-session-message-context.md)

---

## Problem

Today each send mostly passes **only the new user string** into STORE extract/ack and CHAT. QUERY/MIXED inject **last 4** session messages, but STORE does not — so in one session:

1. “I kept my passport in the 3rd drawer of the wardrobe”  
2. “The passport is inside a blue colored file.”

…the 2nd STORE LLM call **does not see** turn 1. Continuity relies on RAG memories later, not ChatGPT-style context. We also only cap **characters per message** (`InputSanitiser.maxCharacters = 500`), not **how long a single chat can grow** (token cost / quality).

---

## Product rules (lock these in)

| Limit | Value | Meaning |
|---|---|---|
| Per-message characters | **500** (existing) | Unchanged — `InputSanitiser` + input counter |
| Max messages per session | **40** | Total `messages` rows (user + assistant) for one `sessionId` |
| Rolling LLM context | **Last 12 messages** | Prior bubbles included in LLM payloads (≈ 6 turns). Not the entire session if longer |

When `messages.count >= maxMessagesPerSession - 1` (need room for this user message **and** the coming assistant reply), **block send**: set user-facing copy (e.g. “This chat is full — start a new conversation”) and keep `canSend == false`. Do **not** silently drop history or auto-split sessions in this task.

Counting: use in-memory `messages` after `loadSession` / appends; optionally re-fetch count from `messageRepository` before send if you need a hard DB check.

---

## What To Do

### Shared limits + transcript helper

- [x] **1.** Introduce a single source of truth for chat limits (prefer `Core/Chat/ChatLimits.swift` or `Domain/Models/ChatLimits.swift` — no magic numbers scattered in View / ViewModel):
      - `maxCharactersPerMessage` → wire to existing `InputSanitiser.maxCharacters` (keep **500**; do not fork a second constant without aliasing).
      - `maxMessagesPerSession = 40`
      - `rollingContextMessageCount = 12`
      - Helper: `static func rollingContext(from messages: [Message], limit: Int = rollingContextMessageCount) -> [Message]` — last `limit` messages in chronological order (oldest → newest). Exclude nothing by role (include user + assistant). Pure function; unit-testable.

- [x] **2.** Add `L10n.Chat` keys for session-full (title/body or single `errorMessage` string) and accessibility if the send control stays visible but disabled. Update `Localizable.xcstrings`.

### Session message cap (UI + ViewModel)

- [x] **3.** On `ChatViewModel`:
      - `var isSessionAtMessageLimit: Bool` derived from `messages.count` vs `ChatLimits`.
      - `canSend` must be false when at limit (in addition to empty input / `isLoading`).
      - `performSend` / retry paths: guard at limit **before** saving a new user message; surface `L10n` via `errorMessage` or a dedicated banner (Views stay thin — no business math in `ChatView`).

- [x] **4.** `ChatView`: disable send when `!canSend`; show session-full feedback (reuse `ThemeBadge` / existing error banner pattern). Keep character counter behaviour; prefer `ChatLimits.maxCharactersPerMessage` / `InputSanitiser.maxCharacters` instead of hard-coded `500` in the view if easy.
      - **As shipped:** `SessionMessageQuotaBar` above the input (green → warning → danger as usage grows); caption “N of 40 messages left”.

### Rolling transcript into LLM paths

- [x] **5.** Build LLM history once per send in `ChatViewModel` (or a small `ChatTranscriptBuilder` in `Core/Chat/`): map rolling `[Message]` → `[LLMMessage(role:content:)]` using stored roles (`user` / `assistant`). Pass this into routes that talk to the LLM.

- [x] **6.** **CHAT** — replace “system + current text only” with: system prompt + **rolling history** + current user turn (if current is already the last saved user row, do not duplicate it in the array).

- [x] **7.** **STORE** — extend `SaveMemoryUseCase` / `MemoryExtractor` APIs to accept optional `conversationContext: [LLMMessage]` (or `[Message]`):
      - **Extract:** include prior turns so pronouns / incomplete references resolve (“it” → passport). Prompt must still produce **one** `clean_text` for the **new** fact only; do not merge the whole thread into one memory.
      - **Ack:** may use short context so the acknowledgement can sound multi-turn; still one warm sentence, no invented facts.
      - Embed + SQLite write remain based on extracted `cleanText` (unchanged).
      - Keep supersede hint behaviour; history may improve hint quality but do not remove vector supersede lookup.

- [x] **8.** **QUERY / MIXED** — replace the hard-coded **last 4** in `RAGAnswerService.loadRecentMessages` with `ChatLimits.rollingContextMessageCount` (12), using the same chronological helper. Retrieved memories remain the grounding source; rolling chat is glue only. Update Stage 4 comments / execution-plan sketch text from “last 4 turns” → “last N messages (ChatLimits)”.

- [x] **9.** **Intent classify (recommended):** pass a short rolling tail (e.g. last 4 messages or same helper with a smaller cap) into `ClassifyIntentUseCase` so follow-ups like “what about the file?” classify as QUERY/STORE more reliably. If scope/time is tight, ship CHAT+STORE+QUERY first and leave classify as a follow-up checkbox — document which landed in Notes.

### Tests & docs

- [x] **10.** Unit tests:
      - `rollingContext` truncates to last N, preserves order.
      - Session at limit → `canSend` false / send does not call use cases (mock deps).
      - STORE extract (mock LLM) receives multi-message payload when history exists (assert message count / roles on mock).
      - QUERY path uses rolling limit (mock DB messages > 12 → only last 12 reach synthesis prompt, or assert helper usage).

- [x] **11.** Update docs in the same PR: `docs/learning/chat-session-message-context.md` (new behaviour), `docs/learning/rag-how-it-works.md` (Stage 4 recent-chat N), `docs/design/app-flow.md` (Chat row / built table), `iOSApp/AGENT.md` (§3.2 send pipeline note), `docs/planning/execution-plan.md` Step 11.2 “As shipped”, README task index already lists 19c.

---

## ✅ Done When

- [x] In one session: STORE “passport in 3rd drawer”, then STORE “it’s inside a blue file” → extraction for the 2nd turn can resolve the referent (clean text mentions passport / file), not a orphaned “it”.
- [x] CHAT follow-ups use prior bubbles in the LLM request (mock or logged payload).
- [x] QUERY/MIXED recent-chat window uses `ChatLimits.rollingContextMessageCount`, not a private `4`.
- [x] At 40 messages (with room rule above), user cannot send; clear copy points them to a new chat.
- [x] Per-message 500 character limit still enforced.
- [x] Views stay thin; limits live in one type; theme / `L10n` only for UI chrome.
- [x] Unit tests above pass; related learning / plan / AGENT / app-flow updated.

---

## 📝 Notes

**As shipped**
- `Core/Chat/ChatLimits.swift` — 500 chars / 40 messages / rolling 12 / intent tail 4 + helpers.
- `SessionMessageQuotaBar` above the composer (usage fill; success → warning → danger).
- STORE extract/ack, CHAT, and intent classify receive rolling context (current user turn not duplicated).
- QUERY/MIXED `loadRecentMessages` uses `ChatLimits.rollingContextMessageCount`.
- Tests: `ChatLimitsTests`, extended `ChatViewModelTests` / `SaveMemoryUseCaseTests`.

**Out of scope**

- Streaming tokens; server-side abort (still 19b).
- Auto-creating a new session when full.
- Sending the **entire** session transcript every turn (always cap with rolling window).
- Changing embedding / RAG retrieval thresholds.
- Raising the 500 character limit.

**Design intent**

- Rolling transcript = **short-term conversational coherence** inside one chat.
- RAG memories = **long-term facts** across sessions.
- Session message cap = **cost / quality guardrail**; close pipeline (task 15) still summarises the full transcript on leave for later retrieval.

**Already shipped (do not recreate)**

- `ChatView` / `ChatViewModel` send pipeline, stop generation (19b), incomplete-turn retry.
- `InputSanitiser` 500-char + code/URL/injection guards.
- STORE / QUERY / MIXED / CHAT routing; RAG four stages; session close transcript (task 15) for title/summary — separate from per-send rolling context.
