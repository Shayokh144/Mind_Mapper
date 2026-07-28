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

## Related Learning
📄 [`docs/learning/supabase-edge-functions-llm-proxy.md`](../../learning/supabase-edge-functions-llm-proxy.md)

## Related UI
None — this is backend-only. Powers all LLM responses visible in Chat View.

---

## What To Do

- [x] **1.** In your project root, initialize Supabase functions: `supabase functions new llm-proxy` and `supabase functions new embed`.
- [x] **2.** Write the `llm-proxy` Edge Function in `supabase/functions/llm-proxy/index.ts`. It must:
  - Check for an `Authorization` header (reject 401 if missing)
  - Read `model`, `fallback_model` (optional), `messages`, `max_tokens`, `temperature` from the request body
  - Call the provider API (Gemini in dev) with the **primary** `model`
  - If the primary fails with **rate limit (429)** or **quota exceeded** (403/402 or provider `resource_exhausted` / `insufficient_quota`), **retry once** with `fallback_model`
  - Return the successful response; if both fail, return a structured error the iOS client can map to a user-friendly message
- [x] **3.** Write the `embed` Edge Function in `supabase/functions/embed/index.ts`. Same primary → fallback pattern:
  - Accept `input`, `model`, and optional `fallback_model` in the request body
  - Primary: `gemini-embedding-001` (dev) / `text-embedding-3-small` (prod)
  - Fallback: retry once on rate limit or quota errors
- [x] **4.** Store the API key as a Supabase secret — never in TypeScript source:

```bash
supabase secrets set GEMINI_API_KEY=...   # dev
# Later: supabase secrets set OPENAI_API_KEY=sk-...
```

- [x] **5.** Deploy both functions: `supabase functions deploy llm-proxy` and `supabase functions deploy embed`.
- [ ] **6.** Test the LLM proxy from Terminal. Confirm a valid chat completion response. *(optional if iOS Test LLM button already succeeded)*
- [ ] **7.** Test the embed function. Confirm you get back an embedding array.
- [x] **8.** Create `Core/Network/LLMClient.swift` in the iOS project. Implement:
  - `LLMModelTier` enum: `.nano`, `.mini`, `.full`, `.embed` — each maps to a **primary** and **fallback** model name (single config struct, easy to swap Gemini ↔ OpenAI)
  - `complete(tier:messages:maxTokens:temperature:)` — sends both `model` and `fallback_model` to `llm-proxy`; never hardcode model strings in use cases
  - `embed(text:tier: .embed)` — same fallback pattern via `embed` function
  - `isRetryableLLMError(_:)` helper — detects 429, quota, and provider-specific exhaustion codes
- [x] **9.** Define tier constants (dev — Gemini):

| Tier | Primary | Fallback |
|---|---|---|
| `.nano` | `gemini-flash-lite-latest` | `gemini-3.5-flash-lite` |
| `.mini` | `gemini-flash-latest` | `gemini-flash-lite-latest` |
| `.full` | `gemini-3.6-flash` | `gemini-flash-latest` |
| `.embed` | `gemini-embedding-001` | `gemini-embedding-001` |

> **Note (2026-07):** Older IDs (`gemini-2.0-flash`, `gemini-2.5-flash`, `text-embedding-004`) return free-tier `limit: 0` / `NOT_FOUND` for new keys. Update `LLMModelConfig` when Google retires aliases again.

- [x] **10.** Add a debug-only test button that calls `LLMClient.shared.complete(tier: .nano, ...)`, verify in console, then **remove** the button (done).
- [ ] **11.** Manually test fallback: temporarily set primary to an invalid model name, confirm fallback model is used and a response still returns.

---

## ✅ Done When

- [x] Both edge functions deploy without errors.
- [ ] curl test of `llm-proxy` returns a valid chat completion response. *(covered in-app if preferred)*
- [ ] curl test of `embed` returns a valid embedding array.
- [x] `LLMClient.complete(tier:)` works from the iOS app (visible in Xcode console).
- [x] Primary → fallback retry works for rate-limit / quota errors (tested manually or with unit test).
- [x] No API keys in the iOS binary or TypeScript source — only in Supabase secrets.
- [x] Use cases call `LLMClient` by **tier** (`.nano`, `.mini`, `.full`) — never raw model name strings.

---

## 📝 Notes

The edge functions must validate the Authorization header — only authenticated app users can invoke the LLM.

**Dev vs production:** During development, proxy the **Gemini API** (`GEMINI_API_KEY`, `generativelanguage.googleapis.com`). When upgrading to OpenAI, swap secrets, endpoint URLs, and the tier config in `LLMClient` — the tier enum and fallback logic stay the same.

**Fallback rule:** Retry with fallback **once** per request. Do not loop. Log which model succeeded (primary vs fallback) for debugging. See `iOSApp/AGENT.md` Section 6.7.

**As shipped (latency fix):** `fetchWithTimeout` (25s) → 504 treated as retryable → fallback once. Short replies (`max_tokens` ≤ 64) send `thinkingConfig.thinkingBudget = 0` when the model allows (avoids ~125s Flash free-tier hangs on ALLOWED/STORE). Redeploy `llm-proxy` + `embed` after pulling.

### Manual curl (steps 6–7, 11)

Sign in with the app (or Auth API) and copy the access token. Then:

```bash
export SUPABASE_URL="https://uhkiqfmziggrgxbamzoy.supabase.co"
export ANON_KEY="your-anon-key"
export ACCESS_TOKEN="your-user-jwt"

# llm-proxy
curl -sS "$SUPABASE_URL/functions/v1/llm-proxy" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "apikey: $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemini-flash-lite-latest",
    "fallback_model": "gemini-3.5-flash-lite",
    "messages": [{"role":"user","content":"Reply with OK"}],
    "max_tokens": 16,
    "temperature": 0
  }'

# embed
curl -sS "$SUPABASE_URL/functions/v1/embed" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "apikey: $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "input": "hello mind mapper",
    "model": "gemini-embedding-001",
    "fallback_model": "gemini-embedding-001"
  }'

# fallback (step 11) — invalid primary → fallback once (404 / not found is retryable)
curl -sS "$SUPABASE_URL/functions/v1/llm-proxy" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "apikey: $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "this-model-does-not-exist-xyz",
    "fallback_model": "gemini-flash-lite-latest",
    "messages": [{"role":"user","content":"Reply with OK"}],
    "max_tokens": 16,
    "temperature": 0
  }'
```

Expect `used_fallback: true` and a normal `choices[0].message.content` on the fallback curl.

**iOS check:** Sign in → tap **Test LLM (.nano)** → confirm UI + Xcode console. ✅ Verified (`used_fallback=false`, reply `OK`). Debug button removed after verification.
