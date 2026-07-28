# Supabase Edge Functions as the LLM Proxy

Why MindMapper never calls Gemini (or later OpenAI) directly from the iPhone, and how the Edge Function request flow works.

**Related task:** [`docs/tasks/phase_1/08-edge-functions_backend.md`](../tasks/phase_1/08-edge-functions_backend.md)  
**Related code (after task 08):** `supabase/functions/llm-proxy/`, `supabase/functions/embed/`, `Core/Network/LLMClient.swift`  
**Related docs:** `iOSApp/AGENT.md` §6.7 (model tiers / fallback), `docs/pre-release-checklist.md` (API key security), [`switching-llm-provider.md`](./switching-llm-provider.md) (Gemini → OpenAI later)

---

## Why we need this

The LLM provider API key (`GEMINI_API_KEY` in development, later `OPENAI_API_KEY`) is **billing-sensitive**.

If the iOS app called Gemini with the key in the binary:

1. Anyone can unpack the `.ipa` / app bundle with free tools.
2. They extract the key.
3. They use *your* account and run up *your* bill (or exhaust free-tier quota).

**Arkana / obfuscation** only hides the key; it does not keep it off the device. A determined attacker can still recover it.

A **Supabase Edge Function** is a small serverless script that:

- Lives on Supabase’s servers (Deno / TypeScript) — **not** inside the iOS app
- Holds the API key in **Supabase secrets** (environment), never in TypeScript source or the app binary
- Accepts requests only from **authenticated** users (`Authorization: Bearer <JWT>`)
- Forwards the call to Gemini (or OpenAI later), then returns JSON to the phone

The iPhone only needs the public Supabase URL + anon key + a logged-in user’s JWT. The billing key never leaves the server.

Same pattern for embeddings via a separate `embed` function.

---

## What is (and isn’t) part of the iOS app

| Piece | Where it runs | Role |
|--------|----------------|------|
| `supabase/functions/**/*.ts` | Supabase Edge (Deno) after `supabase functions deploy` | Proxy: auth check, secrets, call provider, fallback once |
| `LLMClient.swift` | iPhone | Call Edge Functions by **tier** (`.nano`, `.mini`, `.full`, `.embed`) |
| `GEMINI_API_KEY` | Supabase secrets only | Provider auth — never in Swift or committed `.ts` |

The `.ts` files live in this git repo for version control. They are **backend** code. Deploying them uploads the function to your linked Supabase project; Xcode does not compile them into the app.

---

## How to deploy `.ts` files to Supabase

Editing `supabase/functions/**/*.ts` on your Mac does **nothing** for the live project until you **deploy**. Deploy = upload the function bundle to your linked Supabase project via the CLI.

### Prerequisites

1. Supabase CLI installed (`brew install supabase/tap/supabase`).
2. Logged in: `supabase login`
3. Repo linked to this project (from repo root):

```bash
cd /path/to/Mind_Mapper
supabase projects list   # LINKED column should show ● for Mind Mapper
# If not linked:
supabase link --project-ref uhkiqfmziggrgxbamzoy
```

4. Provider secret set (once, or whenever the key changes) — **not** in the `.ts` source:

```bash
set -a && source .env && set +a
supabase secrets set "GEMINI_API_KEY=$GEMINI_API_KEY" --project-ref uhkiqfmziggrgxbamzoy
```

### Deploy the functions

From the **repo root** (where `supabase/functions/` lives):

```bash
# Deploy one function
supabase functions deploy llm-proxy --project-ref uhkiqfmziggrgxbamzoy
supabase functions deploy embed --project-ref uhkiqfmziggrgxbamzoy

# Or deploy every function under supabase/functions/
supabase functions deploy --project-ref uhkiqfmziggrgxbamzoy
```

What happens:

1. CLI packages `index.ts` plus any imports (e.g. `_shared/provider.ts`).
2. Uploads them to Supabase Edge.
3. The live URL becomes available immediately, e.g.  
   `https://uhkiqfmziggrgxbamzoy.supabase.co/functions/v1/llm-proxy`

A “Docker is not running” warning is fine for **remote** deploy — you do not need local Docker for this.

### After you change code

Any edit to `llm-proxy/index.ts`, `embed/index.ts`, or `_shared/*.ts` requires a **new deploy** of the function(s) that import those files. Redeploy both if you touched `_shared`.

### Confirm it landed

- CLI prints `"Deployed Functions."` with a dashboard link.
- Dashboard: **Edge Functions** → see `llm-proxy` / `embed` and recent deploys.
- Smoke test without a JWT should return **401** (auth required):

```bash
curl -sS -o /dev/null -w "%{http_code}\n" \
  -X POST "https://uhkiqfmziggrgxbamzoy.supabase.co/functions/v1/llm-proxy" \
  -H "Content-Type: application/json" \
  -d '{"model":"gemini-flash-lite-latest","messages":[{"role":"user","content":"hi"}]}'
# → 401
```

Full authenticated curl examples: [`08-edge-functions_backend.md`](../tasks/phase_1/08-edge-functions_backend.md) (Notes).

---

## Request flow

```text
iPhone (Swift)
  LLMClient.complete(tier: .nano, …)
        │
        │  HTTPS + Authorization: Bearer <user JWT>
        ▼
Supabase Edge Function (llm-proxy)
  • checks JWT
  • reads GEMINI_API_KEY from Supabase secrets
  • calls Gemini (primary, then fallback once if needed)
        │
        ▼
Gemini API
        │
        ▼
JSON response back to the iPhone
```

`embed` follows the same shape: iOS → `embed` Edge Function → embedding model → vector array back to the phone.

---

## Auth gate

Edge Functions must reject requests with no `Authorization` header (401). Only signed-in MindMapper users (email/password or later social) get a Supabase JWT; that JWT is what the proxy checks.

Without this gate, anyone who knew the function URL could burn your Gemini quota.

---

## Model tiers and fallback (why the proxy is involved)

Use cases never pass raw model name strings. They call:

```swift
LLMClient.complete(tier: .nano, messages: …)
```

Each tier maps to a **primary** and **fallback** model. If the primary fails with rate limit (429), quota exhaustion, **or a 25s provider timeout (504)**, the system retries **once** with the fallback (see task 08 and `AGENT.md` §6.7). That retry lives in the Edge Function — not scattered through features.

For short completions (`max_tokens` ≤ 64, e.g. scope / intent), `llm-proxy` sets Gemini `thinkingConfig.thinkingBudget = 0` on **non-lite** Flash models (Lite rejects that field with a generic `invalid argument`). If that still returns 400, the proxy retries the same model without `thinkingConfig`. Dynamic thinking on Flash has been observed to take **~2 minutes** for a one-word `ALLOWED` reply (free-tier queue + thinking), which outlasts the iOS client.

Dev (Gemini) example (update `LLMModelConfig` when Google retires IDs):

| Tier | Primary | Fallback |
|------|---------|----------|
| `.nano` | `gemini-3.5-flash-lite` (500 RPD) | `gemini-2.5-flash-lite` (20) |
| `.mini` | `gemini-3.5-flash-lite` (500 RPD) | `gemini-3.6-flash` (20) |
| `.full` | `gemini-3.6-flash` (20) | `gemini-2.5-flash` (20) |
| `.embed` | `gemini-embedding-001` | `gemini-embedding-001` |

Only these free-tier quota models (plus embed). No `*-latest` aliases, no `gemini-2.0-flash*` (`limit: 0`).

### Rotating / setting a new `GEMINI_API_KEY`

1. Create a key in [Google AI Studio](https://aistudio.google.com/apikey) (or rotate the old one).
2. Put it in repo-root `.env` (gitignored):

```bash
GEMINI_API_KEY=your_new_key_here
```

3. Push the same value to Supabase (Edge Functions read secrets, not `.env`):

```bash
set -a && source .env && set +a
supabase secrets set "GEMINI_API_KEY=$GEMINI_API_KEY" --project-ref uhkiqfmziggrgxbamzoy
```

Secrets apply without redeploying; redeploy only if you also changed function code:

```bash
supabase functions deploy llm-proxy --project-ref uhkiqfmziggrgxbamzoy
supabase functions deploy embed --project-ref uhkiqfmziggrgxbamzoy
```

4. Confirm models + quota: AI Studio → Rate limits, or `curl ".../v1beta/models?key=$GEMINI_API_KEY"`.

**Local fast-path:** `LocalMessageClassifier` short-circuits obvious scope/intent (e.g. expense/bill STORE) so free-tier Gemini latency does not block routine personal notes. Ambiguous text still uses `.nano` LLM.

When upgrading to OpenAI for production, swap secrets, endpoint URLs, and the tier config — the tier enum and “call by tier” API stay the same.

---

## Mental model

```text
Feature / UseCase  →  LLMClient (tier)  →  Edge Function  →  Provider API
                         ↑                      ↑
                    no API keys            secrets + JWT check
```

**Bottom line:** Edge Functions are the server-side lockbox for the LLM key and the single place that talks to Gemini. The iOS app only asks Supabase for a completion or embedding over HTTPS as a logged-in user.

---

## Debugging request / response (LLM_DEBUG)

The Logs Explorer **gateway** rows (`POST | 200 | …/llm-proxy`) only show HTTP status. They do **not** include Gemini bodies. A `200` means the Edge Function returned successfully to iOS — the phone can still fail later when decoding bad/truncated JSON.

### Commands to run now (enable debug + ship proxy fixes)

From the **repo root**:

```bash
# 1) Opt-in truncated request/response logs in Edge Function runtime logs
supabase secrets set LLM_DEBUG=1 --project-ref uhkiqfmziggrgxbamzoy

# 2) Deploy llm-proxy (timeouts, thinkingBudget for short replies, thought-part filtering, llm_debug)
supabase functions deploy llm-proxy --project-ref uhkiqfmziggrgxbamzoy
supabase functions deploy embed --project-ref uhkiqfmziggrgxbamzoy
```

Then reproduce the chat message in the app.

### Where to read the logs

- Dashboard → **Edge Functions** → **llm-proxy** → **Logs**, or
- Logs Explorer → search / filter for `llm_debug`

You’ll get truncated JSON lines like:

```text
llm_debug {"phase":"ok","model":"gemini-flash-latest","request":{"lastUserPreview":"Need to add…"},"gemini":{"finishReason":"STOP","thoughtPartCount":1},"responsePreview":"{ \"clean_text\": … }"}
```

Fields include: last user preview, `finishReason`, thought vs answer part counts, and a response preview.

### Turn debug off when finished

```bash
supabase secrets unset LLM_DEBUG --project-ref uhkiqfmziggrgxbamzoy
# or: supabase secrets set LLM_DEBUG=0 --project-ref uhkiqfmziggrgxbamzoy
```

Leave debug off in day-to-day use — logs contain truncated user text.

**Also on device:** `MemoryExtractor` logs a truncated raw payload on decode failure (`AppLogger` in Xcode console) — useful even when `LLM_DEBUG` is off.

### iOS DEBUG request / response logs

In **Debug** builds, `LLMClient` prints truncated request + response details via `AppLogger.debug` (Xcode console, prefix `[MindMapper][DEBUG]`):

- `complete`: tier, model/fallback, maxTokens, temperature, each message role + truncated content, then response model / fallback / truncated body
- `embed`: truncated input + dims on success

These calls are **compiled out of Release** (`AppLogger.debug` is empty outside `#if DEBUG`), so App Store / production builds do not emit them. No secret or runtime flag required — use a Debug scheme while developing; archive/Release for production.
