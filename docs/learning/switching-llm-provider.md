# Switching LLM Provider (Gemini → OpenAI)

How MindMapper is set up so you can swap the AI backend later **without rewriting chat features or use cases**.

**Related:** [`supabase-edge-functions-llm-proxy.md`](./supabase-edge-functions-llm-proxy.md), task [`08-edge-functions_backend.md`](../tasks/phase_1/08-edge-functions_backend.md), `Core/Network/LLMClient.swift`, `supabase/functions/`

---

## Why this is possible

Use cases and Chat UI never call Gemini or OpenAI directly. They only call:

```swift
LLMClient.complete(tier: .nano, messages: …)
LLMClient.embed(text: …)
```

Tiers (`.nano`, `.mini`, `.full`, `.embed`) map to model **names** in one place (`LLMModelConfig`). The Edge Function holds the **API key** and talks to the provider. Change those two layers → the rest of the app stays the same.

---

## Mental model

```text
UseCase → LLMClient(tier) → Edge Function → [Gemini today | OpenAI later]
                ↑                    ↑
         only model names     only provider URL + secret
```

---

## What changes vs what stays

| Layer | What changes |
|--------|----------------|
| **Supabase secret** | `supabase secrets set OPENAI_API_KEY=sk-...` (Gemini key can stay or be removed) |
| **Edge Functions** | Point `llm-proxy` / `embed` at `api.openai.com` (`/v1/chat/completions`, `/v1/embeddings`), read `OPENAI_API_KEY`, map responses into the same JSON shape iOS already expects (`choices[].message.content`, `data[].embedding`) |
| **`LLMModelConfig` (Swift)** | Swap tier names, e.g. nano → `gpt-4.1-nano`, embed → `text-embedding-3-small` |
| **Redeploy** | `supabase functions deploy llm-proxy` and `embed` |
| **Unchanged** | Tier enum, ViewModels, use cases, Auth JWT gate, fallback-once rule |

---

## Suggested switch checklist (when you’re ready)

1. Create an OpenAI key; set a spending cap on the OpenAI dashboard.
2. Add to local `.env` (gitignored): `OPENAI_API_KEY=sk-...`
3. Set the Supabase secret (never commit the key):

```bash
set -a && source .env && set +a
supabase secrets set "OPENAI_API_KEY=$OPENAI_API_KEY" --project-ref uhkiqfmziggrgxbamzoy
```

4. Update Edge Function code to call OpenAI (or branch on something like `LLM_PROVIDER=openai`). Keep the **outbound** contract to iOS the same:
   - complete → `{ "choices": [{ "message": { "content": "..." } }], "model_used", "used_fallback" }`
   - embed → `{ "data": [{ "embedding": [...] }], "model_used", "used_fallback" }`
5. Update `LLMModelConfig` primary/fallback strings to OpenAI model IDs (prod table lives in `docs/pre-release-checklist.md`).
6. Redeploy both functions.
7. Smoke-test: in-app **Test LLM** (or curl) + one embed call.
8. Optionally remove `GEMINI_API_KEY` from Supabase secrets once you’re fully on OpenAI.

---

## What you do **not** need to change

- Feature ViewModels / use cases that already pass `tier:`
- Auth / JWT requirement on Edge Functions
- Primary → fallback **once** behavior (same HTTP codes / quota semantics, adapted to OpenAI error bodies if needed)
- Chat UI screens

---

## Bottom line

**Today:** Gemini behind Supabase Edge Functions.  
**Later:** Same iOS API (`LLMClient` + tiers); swap secret, proxy endpoints, and model name config, then redeploy.
