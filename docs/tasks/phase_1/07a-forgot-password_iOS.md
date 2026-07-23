# Auth Email Deep Links (Forgot Password + Confirm Email)

---

## Category
`ios`

## Estimated Time
⏱️ 3–4 hours

## Depends On
Task 7 (email auth — `AuthManager`, `LoginView`, `AppContainer`)

## Related Plan Section
📄 `../planning/execution-plan.md` → Phase 2 — Auth | [`docs/pre-release-checklist.md`](../../pre-release-checklist.md) → optional Universal Links upgrade later

## Related UI
Login — “Forgot password?”; post-sign-up “check your email” state when Confirm email is on; set-new-password screen after a recovery link opens the app.

## Accounts (no paid Apple / Supabase Pro required)
| Need | Free enough? |
|------|----------------|
| Supabase free Auth emails (confirm + recovery) | **Yes** |
| Free Apple ID + **custom URL scheme** (`mindmapper://…`) | **Yes** |
| Paid Apple Developer ($99) | **Not required** for this task |
| Universal Links / Associated Domains | Optional later (paid Apple + your domain) |

Confirm email and forgot password use the **same** redirect plumbing: custom scheme → `onOpenURL` → Supabase session-from-URL.

---

## What To Do

### Shared deep-link plumbing
- [ ] **1.** Choose a custom URL scheme (recommend `mindmapper`) and callback (e.g. `mindmapper://auth-callback`). Put it in `AppConfig` next to the Supabase URL/key.
- [ ] **2.** In Xcode, register the URL scheme (Info → URL Types / `CFBundleURLTypes`). No paid capability required.
- [ ] **3.** In Supabase → Authentication → **URL Configuration**: add the callback to **Redirect URLs** (and set **Site URL** appropriately). Do **not** use `http://localhost:3000` for iOS.
- [ ] **4.** In `MindMapperApp` (or root host), handle `.onOpenURL` (and cold-start URL if needed). Pass the URL into Supabase (`auth.session(from:)` / `client.handle(_:)`), then upsert local SQLite `users` and set `isAuthenticated` when a session is established.

### Forgot password
- [ ] **5.** Add `requestPasswordReset(email:)` on `AuthManager` / `AuthManagerProtocol` → `resetPasswordForEmail` with `redirectTo` = custom scheme callback.
- [ ] **6.** Add “Forgot password?” on `LoginView` (theme tokens) + email request UI; ViewModel calls only `AuthManager`.
- [ ] **7.** After a recovery session from the deep link, show **Set new password** (two secure fields + `PrimaryButton`). Update password via `AuthManager`, then continue as signed-in.

### Confirm email
- [ ] **8.** In Supabase → Authentication → Providers → **Email**: enable **Confirm email** (can test on free tier once redirects work).
- [ ] **9.** Ensure `signUp` uses the same `redirectTo` / email redirect so the confirm link opens `mindmapper://…` (not localhost).
- [ ] **10.** After the user taps **Confirm email address**, the app opens via the scheme, session-from-URL completes, and the local `users` row is upserted — same handler as step 4.
- [ ] **11.** UX: when sign-up returns no session (confirmation required), keep showing the existing “Check your email…” `AppError` / badge; after they confirm and return to the app, land signed in (or prompt to sign in if Supabase only verifies without creating a session — handle both).

### Errors
- [ ] **12.** Map failures to `AppError` with user-facing copy (generic message for unknown reset emails to avoid account enumeration).

---

## ✅ Done When

- [ ] Forgot password: request email → link opens MindMapper → set new password → can sign in.
- [ ] Confirm email: sign up → inbox link opens MindMapper → account confirmed and user can use the app (signed in or clear sign-in path).
- [ ] Wrong/expired links show a clear error; app does not crash.
- [ ] Works with **Supabase free** + **free Apple ID** (custom scheme only).

---

## 📝 Notes

- One `SupabaseClient` in `AppContainer`. One URL handler serves both `type=signup` (confirm) and `type=recovery` (reset).
- Supabase free tier sends these emails with rate limits / deliverability constraints.
- Production polish: Universal Links instead of (or in addition to) the custom scheme — see pre-release checklist. Sign in with Apple still needs paid Apple Developer.
