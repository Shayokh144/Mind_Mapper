# Implement Authentication (Supabase Auth + Sign in with Apple)

---

## Category
`ios`

## Estimated Time
⏱️ 3–5 hours

## Depends On
Task 3 (Supabase project), Task 4 (Xcode project), Task 5 (theme system)

## Related Plan Section
📄 `../planning/execution-plan.md` → Phase 2 — Auth › Steps 2.1 and 2.2 | Auth Decision — Social Login section

## Related UI
Onboarding screen (welcome + auth buttons) — the first screen the user sees. See mockup: Screen 1 (Onboarding).

---

## What To Do

- [ ] **1.** In the Supabase dashboard, go to Authentication → Providers → confirm Email is enabled. Also enable Apple as a provider — follow Supabase's Apple OAuth setup guide (requires adding your App ID and a private key from Apple Developer portal).
- [ ] **2.** In Xcode, add the 'Sign in with Apple' capability: select the MindMapper target → Signing & Capabilities → + Capability → Sign in with Apple.
- [ ] **3.** Create `Core/DI/AppContainer.swift` as a `@MainActor final class ObservableObject`. Initialize the Supabase client here using your Project URL and anon key from Task 3. This is the single place where the client is created.
- [ ] **4.** Create `Core/Network/AuthManager.swift` as a `@MainActor final class ObservableObject` conforming to `AuthManagerProtocol`. Implement `signUp(email:password:)`, `signIn(email:password:)`, `signInWithApple()`, `signOut()`, and `restoreSession()` methods.
- [ ] **5.** In `restoreSession()`, check for an active Supabase session on app launch. If found, load the local User record from SQLite. If not found, set `isAuthenticated = false`.
- [ ] **6.** Create `Domain/Repositories/AuthRepositoryProtocol.swift` with the protocol definition — see ../../iOSApp/AGENT.md pattern for repository protocols.
- [ ] **7.** Create `Features/Auth/LoginViewModel.swift` as a `@MainActor final class ObservableObject`. It holds `@Published var email`, `@Published var password`, `@Published var isLoading`, `@Published var errorMessage`. It calls `AuthManager` methods — it never calls Supabase directly.
- [ ] **8.** Create `Features/Onboarding/OnboardingView.swift` using the theme system. Implement the layout shown in the UI mockup: app icon, one-sentence headline, three feature bullets, 'Continue with Apple' PrimaryButton, 'Continue with email' SecondaryButton, and legal footnote.
- [ ] **9.** Create `Features/Auth/LoginView.swift` for email/password sign-in with two ThemeTextFields and a PrimaryButton. Include error display using `ThemeBadge` with `.danger` role.
- [ ] **10.** In `MindMapperApp.swift`, initialize `AppContainer` as `@StateObject`. Use `AuthManager.isAuthenticated` to switch between `OnboardingView` and `RootView` (the main app).
- [ ] **11.** On successful login, create a User row in the local SQLite `users` table using the Supabase user ID as the primary key.
- [ ] **12.** On app launch, call `authManager.restoreSession()` inside a `.task` modifier on the root view — never in `init`.

---

## ✅ Done When

- [ ] Register a new user with email + password — User row appears in SQLite `users` table.
- [ ] Kill and relaunch the app — user is still logged in (session restored from Supabase).
- [ ] Sign out — `isAuthenticated` becomes false, OnboardingView is shown.
- [ ] Sign in with Apple button triggers the native Apple sign-in sheet.
- [ ] Error message appears in the UI when wrong password is entered.

---

## 📝 Notes

The `AppContainer` must be created once in `@main` and passed as `@EnvironmentObject` to all views. Never create a second `SupabaseClient` anywhere else in the app. See ../../iOSApp/AGENT.md Section 8 for the full dependency injection pattern.
