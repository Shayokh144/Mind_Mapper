# Pre-Release Checklist

Use this before submitting to the App Store, sharing via TestFlight, or calling the app "production ready."

---

## Locked-In Decisions

These decisions apply throughout the project. Review them before release to confirm nothing has drifted.

| Area | Development (now) | Production (release) |
|---|---|---|
| **Apple account** | Free Apple ID — run on your own iPhone (re-sign every ~7 days) | Enrol in [Apple Developer Program](https://developer.apple.com) ($99/year) for App Store / TestFlight |
| **LLM provider** | Google Gemini free tier (`GEMINI_API_KEY`) | OpenAI or another paid provider (`OPENAI_API_KEY`) |
| **LLM models** | Primary + fallback per tier (see below) | OpenAI primary + fallback pairs |
| **LLM fallback** | Auto-retry with fallback model on rate limit (429) or quota exceeded | Same — required before release |
| **Backend** | Supabase free tier | Supabase Pro ($25/mo) if you need no pause + higher limits |
| **API key location** | Gitignored `.env` at repo root (local curl tests) + Supabase secrets (task 08) | Supabase secrets only — delete local `.env` or remove keys before release |
| **Code location** | `iOSApp/` | Same |
| **Architecture guide** | `iOSApp/AGENT.md` | Same |
| **Docs & tasks** | `docs/` | Same |
| **Crash / error logging** | Local `AppLogger` (`NSLog`) in `Core/Logging/AppLogger.swift` | Wire `AppLogger` to Sentry (or equivalent) — see checklist below |

### LLM model tiers — primary + fallback

Every LLM call uses a **primary** model. If the primary fails due to **rate limit** or **out of quota**, the system retries **once** with the **fallback** model. Implemented in `LLMClient` + Edge Functions (task 08). Use cases pass a **tier** (`.nano`, `.mini`, `.full`, `.embed`) — never raw model strings.

**Development (Gemini):**

| Tier | Primary | Fallback |
|---|---|---|
| nano | `gemini-2.0-flash` | `gemini-2.0-flash-lite` |
| mini | `gemini-2.0-flash` | `gemini-1.5-flash` |
| full | `gemini-2.5-flash` | `gemini-2.0-flash` |
| embed | `text-embedding-004` | `text-embedding-004` |

**Production (OpenAI):**

| Tier | Primary | Fallback |
|---|---|---|
| nano | GPT-4.1 Nano | GPT-4o-mini |
| mini | GPT-4.1 Mini | GPT-4o-mini |
| full | GPT-4.1 | GPT-4.1 Mini |
| embed | text-embedding-3-small | text-embedding-ada-002 |

---

## API Key Storage

**Chosen approach (development):** gitignored `.env` at the repo root.

```bash
# Setup (once)
cp .env.example .env
# Edit .env → GEMINI_API_KEY=AIza...

# Load into Terminal (each new session)
set -a && source .env && set +a
```

| Option | Status | Notes |
|---|---|---|
| **`.env` file** *(chosen)* | ✅ Use this | Project-local, easy to swap keys; `.env` is gitignored |
| **Supabase secrets** | ✅ Also use (task 08) | Edge Functions read the key server-side; iOS never sees it |
| **direnv** | Optional | Auto-loads `.envrc` when you `cd` into the project |
| **macOS Keychain** | Optional | More secure; overkill for solo dev |
| **`~/.zshrc`** | Not used | Avoids polluting global shell config |

**Rule:** Never commit `.env`. Never put LLM keys in Swift source or the iOS binary.

**Workflow:**
1. Store `GEMINI_API_KEY` in `.env` for local curl tests (task 02).
2. Copy the same key to Supabase secrets in task 08: `supabase secrets set GEMINI_API_KEY=...`
3. Before release, remove dev keys from `.env` — production keys live in Supabase secrets only.

---

## Pre-Release Checklist

### Accounts & billing

- [ ] Enrolled in Apple Developer Program ($99/year)
- [ ] Upgraded LLM from Gemini dev tier to production provider (OpenAI or chosen alternative)
- [ ] Production API key set in Supabase secrets (`OPENAI_API_KEY` or equivalent)
- [ ] LLM billing cap set (e.g. $20–50/month on OpenAI)
- [ ] Supabase plan reviewed — upgrade to Pro if free-tier pause is unacceptable for real users
- [ ] Removed dev API keys from `.env` (or deleted the file)

### Backend & security

- [ ] Primary → fallback model retry tested (rate limit / quota scenario)
- [ ] LLM tier config uses production primary + fallback pairs (not dev Gemini models)
- [ ] Edge Functions require `Authorization` header (authenticated users only)
- [ ] No API keys in Swift source, `Info.plist`, or the compiled `.ipa`
- [ ] `.gitignore` covers `.env`, `xcuserdata`, `DerivedData`, and any secret files
- [ ] Supabase Row Level Security (RLS) enabled on all user tables
- [ ] Rate limiting / input guards tested under load

### iOS app quality

- [ ] All Phase 1 tasks complete (tasks 01–21)
- [ ] Full test suite passes ([task 20](tasks/phase_1/20-test-suite_iOS.md))
- [ ] Tested on a real iPhone (not Simulator only)
- [ ] Tested on oldest supported iOS version you plan to support
- [ ] No hardcoded colors/fonts — theme tokens used throughout
- [ ] Error messages are user-friendly (no raw `localizedDescription`)
- [ ] Remote crash/error logging integrated (Sentry or equivalent) via `AppLogger` — see **Observability** below
- [ ] Delete flows work (session, memory, account)
- [ ] App handles offline / no-network gracefully

### Observability (crash & error logging)

Today logging is local only: `AppLogger` in `iOSApp/MindMapper/MindMapper/Core/Logging/AppLogger.swift` uses `NSLog`. Call sites must keep using `AppLogger` so a remote backend can be swapped in one place.

- [ ] Choose a provider (recommended: [Sentry](https://sentry.io) for iOS; alternatives: Firebase Crashlytics, Bugsnag)
- [ ] Create the project / DSN; store the DSN in Supabase secrets or Xcode config — never hardcode in source committed to git if the key is sensitive
- [ ] Add the SDK (e.g. Sentry Swift package) and initialize in `MindMapperApp` at launch
- [ ] Replace the bodies of `AppLogger.error` / `AppLogger.info` to forward to the SDK (keep `NSLog` in DEBUG if useful)
- [ ] Verify a test error appears in the dashboard (`AppLogger.error("Sentry smoke test", error: …)`)
- [ ] Confirm PII policy: do not send memory text, chat content, or emails in breadcrumbs without privacy-policy disclosure
- [ ] Privacy policy updated if crash reports / diagnostics are collected

### App Store readiness

- [ ] App icon and launch screen finalized
- [ ] Screenshots for required device sizes
- [ ] Privacy policy URL (required — app stores personal data)
- [ ] App Store description and keywords written
- [ ] Export compliance / encryption questionnaire completed in App Store Connect
- [ ] TestFlight beta tested by at least one other person
- [ ] Version and build numbers set correctly

### Data & privacy

- [ ] User informed that memories are stored on-device (and server if sync is enabled)
- [ ] Account deletion removes all user data (local + server)
- [ ] No analytics or tracking without disclosure in privacy policy
- [ ] Scope guard blocks out-of-scope queries in production

### Final smoke test

- [ ] Fresh install → sign up → store a memory → query it → get correct answer
- [ ] Close app → reopen → session and memories persist
- [ ] Sign out → sign back in → data restored (if server sync enabled)
- [ ] Delete account → all data gone

---

## When to Revisit This Checklist

- Before first TestFlight upload
- Before App Store submission
- After switching LLM provider (Gemini → OpenAI)
- After adding server-side sync or new paid features
