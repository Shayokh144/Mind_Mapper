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

Each tier maps to a **primary** and **fallback** model. If the primary fails with rate limit (429) or quota exhaustion, the system retries **once** with the fallback (see task 08 and `AGENT.md` §6.7). That retry lives in the Edge Function / `LLMClient` layer — not scattered through features.

Dev (Gemini) example (update `LLMModelConfig` when Google retires IDs):

| Tier | Primary | Fallback |
|------|---------|----------|
| `.nano` | `gemini-flash-lite-latest` | `gemini-3.5-flash-lite` |
| `.mini` | `gemini-flash-latest` | `gemini-flash-lite-latest` |
| `.full` | `gemini-3.6-flash` | `gemini-flash-latest` |
| `.embed` | `gemini-embedding-001` | `gemini-embedding-001` |

When upgrading to OpenAI for production, swap secrets, endpoint URLs, and the tier config — the tier enum and “call by tier” API stay the same.

---

## Mental model

```text
Feature / UseCase  →  LLMClient (tier)  →  Edge Function  →  Provider API
                         ↑                      ↑
                    no API keys            secrets + JWT check
```

**Bottom line:** Edge Functions are the server-side lockbox for the LLM key and the single place that talks to Gemini. The iOS app only asks Supabase for a completion or embedding over HTTPS as a logged-in user.
