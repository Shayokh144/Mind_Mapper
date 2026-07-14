# Build Supabase Edge Functions (LLM & Embedding Proxy)

---

## Category
`backend`

## Estimated Time
⏱️ 2–3 hours

## Depends On
Task 2 (Gemini API key for dev), Task 3 (Supabase CLI)

## Related Plan Section
📄 `../planning/execution-plan.md` → Phase 3 — Backend Proxy › Steps 3.1, 3.2, 3.3 | LLM & API Decision section

## Related UI
None — this is backend-only. Powers all LLM responses visible in Chat View.

---

## What To Do

- [ ] **1.** In your project root, initialize Supabase functions: `supabase functions new llm-proxy` and `supabase functions new embed`.
- [ ] **2.** Write the `llm-proxy` Edge Function in `supabase/functions/llm-proxy/index.ts`. It must:
  - Check for an `Authorization` header (reject 401 if missing)
  - Read `model`, `fallback_model` (optional), `messages`, `max_tokens`, `temperature` from the request body
  - Call the provider API (Gemini in dev) with the **primary** `model`
  - If the primary fails with **rate limit (429)** or **quota exceeded** (403/402 or provider `resource_exhausted` / `insufficient_quota`), **retry once** with `fallback_model`
  - Return the successful response; if both fail, return a structured error the iOS client can map to a user-friendly message
- [ ] **3.** Write the `embed` Edge Function in `supabase/functions/embed/index.ts`. Same primary → fallback pattern:
  - Accept `input`, `model`, and optional `fallback_model` in the request body
  - Primary: `text-embedding-004` (dev) / `text-embedding-3-small` (prod)
  - Fallback: retry once on rate limit or quota errors
- [ ] **4.** Store the API key as a Supabase secret — never in TypeScript source:

```bash
supabase secrets set GEMINI_API_KEY=...   # dev
# Later: supabase secrets set OPENAI_API_KEY=sk-...
```

- [ ] **5.** Deploy both functions: `supabase functions deploy llm-proxy` and `supabase functions deploy embed`.
- [ ] **6.** Test the LLM proxy from Terminal. Confirm a valid chat completion response.
- [ ] **7.** Test the embed function. Confirm you get back an embedding array.
- [ ] **8.** Create `Core/Network/LLMClient.swift` in the iOS project. Implement:
  - `LLMModelTier` enum: `.nano`, `.mini`, `.full`, `.embed` — each maps to a **primary** and **fallback** model name (single config struct, easy to swap Gemini ↔ OpenAI)
  - `complete(tier:messages:maxTokens:temperature:)` — sends both `model` and `fallback_model` to `llm-proxy`; never hardcode model strings in use cases
  - `embed(text:tier: .embed)` — same fallback pattern via `embed` function
  - `isRetryableLLMError(_:)` helper — detects 429, quota, and provider-specific exhaustion codes
- [ ] **9.** Define tier constants (dev — Gemini):

| Tier | Primary | Fallback |
|---|---|---|
| `.nano` | `gemini-2.0-flash` | `gemini-2.0-flash-lite` |
| `.mini` | `gemini-2.0-flash` | `gemini-1.5-flash` |
| `.full` | `gemini-2.5-flash` | `gemini-2.0-flash` |
| `.embed` | `text-embedding-004` | `text-embedding-004` |

- [ ] **10.** Add a debug-only test button that calls `LLMClient.shared.complete(tier: .nano, ...)` and prints the result. Remove after verification.
- [ ] **11.** Manually test fallback: temporarily set primary to an invalid model name, confirm fallback model is used and a response still returns.

---

## ✅ Done When

- [ ] Both edge functions deploy without errors.
- [ ] curl test of `llm-proxy` returns a valid chat completion response.
- [ ] curl test of `embed` returns a valid embedding array.
- [ ] `LLMClient.complete(tier:)` works from the iOS app (visible in Xcode console).
- [ ] Primary → fallback retry works for rate-limit / quota errors (tested manually or with unit test).
- [ ] No API keys in the iOS binary or TypeScript source — only in Supabase secrets.
- [ ] Use cases call `LLMClient` by **tier** (`.nano`, `.mini`, `.full`) — never raw model name strings.

---

## 📝 Notes

The edge functions must validate the Authorization header — only authenticated app users can invoke the LLM.

**Dev vs production:** During development, proxy the **Gemini API** (`GEMINI_API_KEY`, `generativelanguage.googleapis.com`). When upgrading to OpenAI, swap secrets, endpoint URLs, and the tier config in `LLMClient` — the tier enum and fallback logic stay the same.

**Fallback rule:** Retry with fallback **once** per request. Do not loop. Log which model succeeded (primary vs fallback) for debugging. See `iOSApp/AGENT.md` Section 6.7.
