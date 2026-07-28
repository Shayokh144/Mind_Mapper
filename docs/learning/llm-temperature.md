# LLM Temperature: Why `0` vs `0.3` (and friends)

When MindMapper calls `LLMClient.complete(...)`, every call passes a **`temperature`**. In `CloseSessionUseCase` you see two different values on purpose:

```swift
// Title + topic tag — must parse as strict JSON
temperature: 0

// Bullet summary — readable prose, still grounded
temperature: 0.3
```

**Related code:** `Domain/UseCases/CloseSessionUseCase.swift`, `Domain/UseCases/ClassifyIntentUseCase.swift`, `Core/RAG/MemoryExtractor.swift`, `Features/Chat/ChatViewModel.swift`  
**Related task:** [`15-session-close-pipeline_iOS.md`](../tasks/phase_1/15-session-close-pipeline_iOS.md)

---

## The short answer

**Temperature** controls how *random* the model’s next-token choices are.

| Value | Behaviour | Use when |
|---|---|---|
| **`0`** | Nearly deterministic — always picks the highest-probability token | Classification, JSON schemas, enums, extractors |
| **`0.3`** | Slight variety — still factual and structured | Summaries, short grounded prose |
| **`0.5–0.7`** | More natural / conversational | Chat replies, acknowledgements, merged answers |

It is **not** “creativity dial = smarter.” Higher temperature can also mean more typos, invented facts, or broken JSON.

---

## What temperature actually does

At each step the model scores possible next tokens. Temperature reshapes that distribution:

- **Low (→ 0):** peaky distribution → safe, repeatable answers. Same prompt → very similar output.
- **Higher:** flatter distribution → more surprise tokens → varied wording (and more risk of nonsense).

Providers may treat exact `0` slightly differently (some still sample lightly), but the *intent* in our code is: **minimise variance for machine-parsed outputs**.

---

## Why session close uses both

### Title + topic → `temperature: 0`

```text
Reply ONLY with JSON: {"title": "...", "topic": "..."}
```

Downstream we:

1. Strip code fences.
2. `JSONDecoder`-decode the payload.
3. Map `topic` onto `Session.TopicTag` (fixed enum).

Failures look like: extra commentary, wrong keys, `topic: "travel"` instead of `plans`, markdown wrappers. **`0`** keeps the model on the rails so decoding rarely throws `AppError.llmResponseInvalid`.

Same pattern elsewhere: `ClassifyIntentUseCase` (one word: STORE/QUERY/…), `MemoryExtractor` (JSON), `ScopeGuard`, entity extraction in `RAGRetriever` — all **`temperature: 0`**.

### Summary bullets → `temperature: 0.3`

```text
Summarise this conversation as 3-5 bullet points...
Write each bullet as a complete standalone sentence.
```

Here we want:

- Faithful facts from the transcript (not inventing a Bali trip that never happened).
- Natural sentence variety so bullets aren’t robotic clones.
- Still stable enough that re-closing the same chat doesn’t rewrite history every time.

**`0.3`** is a middle ground: less rigid than pure JSON classification, far colder than casual chat (`0.7`).

Those bullets are later embedded for retrieval. Slight wording changes are fine; invented facts are not — so we stay low.

---

## How the rest of the app chooses

Rough map of shipped call sites (values can drift; check the file if unsure):

| Job | Typical temp | Why |
|---|---|---|
| Intent / scope / JSON extract | `0` | Must match a schema or enum |
| Session summary bullets | `0.3` | Structured prose |
| RAG answer / merge | `0.4–0.5` | Helpful wording, stay on retrieved facts |
| Mixed general-knowledge leg | `~0.6` | A bit more suggestion variety |
| Casual CHAT / “Got it” ack | `0.7` | Friendly tone |

Rule of thumb for new calls:

1. **Will Swift parse the string?** → start at **`0`**.
2. **Will a human read it, but it must stay true to stored memory?** → **`0.3–0.5`**.
3. **Tone matters more than exact words?** → **`0.6–0.7`**.
4. Avoid **`> 0.8`** for memory features — hallucinations hurt trust.

---

## What temperature is *not*

- Not a substitute for a good prompt (formats, enums, “reply ONLY with…” still matter).
- Not the same as **`maxTokens`** (length budget) or **tier** (`.nano` / `.mini` / `.full` model choice).
- Not guaranteed identical output even at `0` across model versions or providers — treat “deterministic” as *as stable as the API allows*.

---

## Quick quiz (mental model)

Closing a session:

- Need `{"title","topic"}` for SQLite columns → **`0`**
- Need 3–5 readable bullets to embed → **`0.3`**

If title generation starts failing JSON decode in production, check temperature first (should stay `0`), then the prompt and fence-stripping — don’t “fix” it by raising temperature.
