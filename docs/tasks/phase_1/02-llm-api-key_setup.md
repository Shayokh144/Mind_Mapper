# Get LLM API Key (Gemini for Dev → OpenAI Later)

---

## Category
`other`

## Estimated Time
⏱️ 30 minutes

## Depends On
None — can be done in parallel with Task 1

## Related Plan Section
📄 `../planning/execution-plan.md` → Phase 0 — Environment Setup › Step 0.2 | LLM & API Decision section

## Related UI
None — no UI built in this task

---

## Strategy

| Phase | Provider | Why |
|---|---|---|
| **Development (now)** | Google Gemini (free tier) | $0 cost while building and testing |
| **Production (later)** | OpenAI or another paid provider | Better model tiers, embeddings, and pricing at scale |

The app will be built with a provider-agnostic LLM client. Start with Gemini during development; swap to OpenAI (or another service) when you're ready to ship or need higher quality.

**Dev key storage:** gitignored `.env` at the repo root (see steps below).

---

## What To Do — Development (Gemini Free Tier)

- [ ] **1.** Create a Google account (or sign in) at [aistudio.google.com](https://aistudio.google.com).
- [ ] **2.** Go to **Get API key** → **Create API key** → choose or create a Google Cloud project. Name the key `MindMapper-Dev`.
- [ ] **3.** Copy the key immediately and store a backup in a password manager or Keychain. Do NOT paste it into any Swift file.
- [ ] **4.** Create your local env file from the template:

```bash
cd /path/to/Mind_Mapper
cp .env.example .env
```

- [ ] **5.** Open `.env` and set your key:

```bash
GEMINI_API_KEY=AIza...
```

> `.env` is in `.gitignore` — it will never be committed. `.env.example` (no real keys) is committed as a template.

- [ ] **6.** Load the env vars into your current Terminal session:

```bash
set -a && source .env && set +a
```

Run this whenever you open a new Terminal tab and need the key for curl tests. (Task 08 will also copy this key into Supabase secrets for the Edge Function.)

- [ ] **7.** Verify the key works:

```bash
curl "https://generativelanguage.googleapis.com/v1beta/models?key=$GEMINI_API_KEY"
```

You should see a JSON list of available Gemini models.

- [ ] **8.** Note the primary and fallback models for each tier (see [pre-release checklist](../../pre-release-checklist.md) — LLM model fallback). During development with Gemini:

| Tier | Primary | Fallback (rate limit / quota) |
|---|---|---|
| **nano** (classify, scope guard) | `gemini-flash-lite-latest` | `gemini-3.5-flash-lite` |
| **mini** (extract, summarise, acknowledge) | `gemini-flash-latest` | `gemini-flash-lite-latest` |
| **full** (mixed / general knowledge) | `gemini-3.6-flash` | `gemini-flash-latest` |
| **embed** | `gemini-embedding-001` | `gemini-embedding-001` |

> **Free tier limits:** Gemini's free tier has rate limits and retiring model IDs. Fallback is automatic in `LLMClient` + Edge Functions (task 08). Keep `LLMModelConfig` in sync with models that still work for your API key (`ai.google.dev`).

---

## What To Do Later — Production (OpenAI or Paid Provider)

Skip this section during initial development. Come back when you're ready to ship or need higher quality.

- [ ] **1.** Create an account at [platform.openai.com](https://platform.openai.com).
- [ ] **2.** Go to **API Keys** → Create new secret key → name it `MindMapper-Prod`. Copy immediately.
- [ ] **3.** Go to **Billing** → add a payment method → set a hard monthly cap (e.g. $10–20 USD).
- [ ] **4.** Add to `.env` (same file, new key):

```bash
OPENAI_API_KEY=sk-...
```

- [ ] **5.** Reload and verify:

```bash
set -a && source .env && set +a
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY"
```

- [ ] **6.** Production model tiers with primary → fallback pairs (from execution plan):

| Tier | Primary | Fallback |
|---|---|---|
| **nano** | GPT-4.1 Nano | GPT-4o-mini |
| **mini** | GPT-4.1 Mini | GPT-4o-mini |
| **full** | GPT-4.1 | GPT-4.1 Mini |
| **embed** | text-embedding-3-small | text-embedding-ada-002 |

When switching providers, update the Supabase Edge Function (task 08) and the `LLMClient` tier config — the rest of the app stays the same.

---

## ✅ Done When (Development)

- [ ] `.env` exists at repo root with `GEMINI_API_KEY` set (not committed to Git).
- [ ] The Gemini curl verification command returns a valid JSON response with model names.
- [ ] You understand Gemini is for dev; OpenAI (or another paid provider) comes later for production.

---

## 📝 Notes

Never commit `.env` to Git — only `.env.example` (empty template) is tracked.

During development, the key will also live on your backend (Supabase Edge Function secrets) after task 08 — not in the iOS binary.

Pre-release decisions and checklist: [pre-release-checklist.md](../pre-release-checklist.md).
