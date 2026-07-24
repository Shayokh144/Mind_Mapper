# Implement Authentication (Supabase Email Auth)

---

## Category

`ios`

## Estimated Time

⏱️ 3–4 hours

## Depends On

Task 3 (Supabase project), Task 4 (Xcode project), Task 5 (theme system)

## Related Plan Section

📄 `../planning/execution-plan.md` → Phase 2 — Auth › Steps 2.1 and 2.2

## Related UI

Onboarding screen (welcome + auth) — the first screen the user sees. See mockup: Screen 1 (Onboarding).

## Deferred

**Sign in with Apple** requires a paid Apple Developer Program account. It is tracked in `[docs/pre-release-checklist.md](../../pre-release-checklist.md)` — do not implement it in this task.

**Forgot password + Confirm email** (custom URL scheme deep links) is Phase 1 task `[07a-forgot-password_iOS.md](07a-forgot-password_iOS.md)`. **Free** Supabase + **free** Apple ID are enough — no $99 Apple program required.

---



## What To Do

- [x] **1.** In the Supabase dashboard, go to Authentication → Providers → confirm Email is enabled.
- [x] **2.** Create `Core/DI/AppContainer.swift` as a `@MainActor final class ObservableObject`. Initialize the Supabase client here using your Project URL and anon key from Task 3 (from root `.env` / config). This is the single place where the client is created.
- [x] **3.** Create `Core/Network/AuthManager.swift` as a `@MainActor final class ObservableObject` conforming to `AuthManagerProtocol`. Implement `signUp(email:password:)`, `signIn(email:password:)`, `signOut()`, and `restoreSession()` methods.
- [x] **4.** In `restoreSession()`, check for an active Supabase session on app launch. If found, load the local User record from SQLite. If not found, set `isAuthenticated = false`.
- [x] **5.** Create `Domain/Repositories/AuthRepositoryProtocol.swift` with the protocol definition — see ../../iOSApp/AGENT.md pattern for repository protocols.
- [x] **6.** Create `Features/Auth/LoginViewModel.swift` as a `@MainActor final class ObservableObject`. It holds `@Published var email`, `@Published var password`, `@Published var isLoading`, `@Published var errorMessage`. It calls `AuthManager` methods — it never calls Supabase directly.
- [x] **7.** Create `Features/Onboarding/OnboardingView.swift` using the theme system. Implement the layout shown in the UI mockup: app icon, one-sentence headline, three feature bullets, 'Continue with email' PrimaryButton, and legal footnote. (No Apple button in this task.)
- [x] **8.** Create `Features/Auth/LoginView.swift` for email/password sign-in (and sign-up as needed) with two ThemeTextFields and a PrimaryButton. Include error display using `ThemeBadge` with `.danger` role.
- [x] **9.** In `MindMapperApp.swift`, initialize `AppContainer` as `@StateObject`. Use `AuthManager.isAuthenticated` to switch between `OnboardingView` and `RootView` (the main app).
- [x] **10.** On successful login, create a User row in the local SQLite `users` table using the Supabase user ID as the primary key.
- [x] **11.** On app launch, call `authManager.restoreSession()` inside a `.task` modifier on the root view — never in `init`.

---



## ✅ Done When

- [x] Register a new user with email + password — User row appears in SQLite `users` table.
- [x] Kill and relaunch the app — user is still logged in (session restored from Supabase).
- [x] Sign out — `isAuthenticated` becomes false, OnboardingView is shown.
- [x] Error message appears in the UI when wrong password is entered.

---



## 📝 Notes

The `AppContainer` must be created once in `@main` and passed as `@EnvironmentObject` to all views. Never create a second `SupabaseClient` anywhere else in the app. See ../../iOSApp/AGENT.md Section 8 for the full dependency injection pattern.

**Email confirmation:** If Supabase has “Confirm email” enabled, sign-up may not return a session until the user clicks the link. For local testing, turn off **Authentication → Providers → Email → Confirm email**, or confirm via the inbox before signing in.