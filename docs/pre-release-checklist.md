# Pre-Release Checklist

Use this before submitting to the App Store, sharing via TestFlight, or calling the app "production ready."

---

## Locked-In Decisions

These decisions apply throughout the project. Review them before release to confirm nothing has drifted.

| Area | Development (now) | Production (release) |
|---|---|---|
| **Apple account** | Free Apple ID — run on your own iPhone (re-sign every ~7 days) | Enrol in [Apple Developer Program](https://developer.apple.com) ($99/year) for App Store / TestFlight |
| **Auth** | Email + password ([task 07](tasks/phase_1/07-authentication_iOS.md)); **forgot password + confirm email** via custom URL scheme ([task 07a](tasks/phase_1/07a-forgot-password_iOS.md)) — free Supabase + free Apple ID | Optional Universal Links upgrade; add **Sign in with Apple** (paid Developer Program) |
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
| nano | `gemini-flash-lite-latest` | `gemini-3.5-flash-lite` |
| mini | `gemini-flash-latest` | `gemini-flash-lite-latest` |
| full | `gemini-3.6-flash` | `gemini-flash-latest` |
| embed | `gemini-embedding-001` | `gemini-embedding-001` |

> Source of truth: `LLMModelConfig` in `Core/Network/LLMClient.swift`. Google retires free-tier IDs periodically.

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

### Sign in with Apple (deferred from task 07)

Requires a **paid** Apple Developer Program account. Skip until you enrol — email auth is enough during development.

- [ ] In Apple Developer portal → Identifiers → App ID (`abu.taher.com.MindMapper`): enable **Sign in with Apple** and save
- [ ] In Xcode: MindMapper target → Signing & Capabilities → + Capability → **Sign in with Apple**
- [ ] In Supabase → Authentication → Providers → **Apple**: enable and set Client IDs to the app bundle ID (`abu.taher.com.MindMapper`)
- [ ] Native iOS only: use `AuthenticationServices` + `supabase.auth.signInWithIdToken(provider: .apple, …)` — no Services ID / `.p8` / callback URL needed unless you also add web/Android OAuth later
- [ ] Implement `signInWithApple()` on `AuthManager` / `AuthManagerProtocol`
- [ ] Update Onboarding UI: add **Continue with Apple** PrimaryButton; keep email as SecondaryButton (or equivalent)
- [ ] Done when: Apple button shows the native sign-in sheet; successful Apple login creates/loads the local SQLite `users` row and sets `isAuthenticated = true`

### Email deep links — Universal Links upgrade (production)

Phase 1 [task 07a](tasks/phase_1/07a-forgot-password_iOS.md) already supports **Confirm email** and **forgot password** on **free** Supabase + **free** Apple ID using a **custom URL scheme**. Before App Store release, optionally upgrade to Universal Links (stronger than custom schemes).

- [ ] Keep Confirm email **on** for production
- [ ] (Optional) Register **Associated Domains** + host `apple-app-site-association` — requires paid Apple Developer Program + your HTTPS domain
- [ ] Point Supabase **Site URL** / **Redirect URLs** at the Universal Link (or keep the custom scheme from task 07a)
- [ ] Confirm-email and recovery links both open MindMapper and complete session-from-URL + local `users` upsert
- [ ] Done when: inbox links work reliably on device without relying on `http://localhost:3000`

### Backend & security

- [ ] Primary → fallback model retry tested (rate limit / quota scenario)
- [ ] LLM tier config uses production primary + fallback pairs (not dev Gemini models)
- [ ] Edge Functions require `Authorization` header (authenticated users only)
- [ ] No API keys in Swift source, `Info.plist`, or the compiled `.ipa`
- [ ] `.gitignore` covers `.env`, `xcuserdata`, `DerivedData`, and any secret files
- [ ] Supabase Row Level Security (RLS) enabled on all user tables
- [ ] Rate limiting / input guards tested under load

### iOS app quality

- [ ] All Phase 1 tasks complete (tasks 01–21, including [07a auth email deep links](tasks/phase_1/07a-forgot-password_iOS.md))
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
