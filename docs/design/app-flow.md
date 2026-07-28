# Mind Mapper — Current App Flow

> **Living document.** Describes only what is **built and wired into the running app today**.  
> **After every task that changes screens, routing, or auth behavior, update this file** in the same PR / same session (diagrams + screen map + “built / not yet” lists).

Related: [`theme-guide.md`](theme-guide.md) (visual system), `iOSApp/AGENT.md` (architecture rules).

Primary flow code:

- `App/MindMapperApp.swift` (`MindMapperApp` + `AppRootHost`)
- `Core/Navigation/AppRouter.swift`
- `Core/Network/AuthManager.swift` / `AuthManagerProtocol.swift`
- `Core/DI/AppContainer.swift`
- `Features/Onboarding|Auth|Root|Sessions|Chat|Memories|Settings/*`

---

## Built so far (in the live app)

| Area | What exists |
|------|-------------|
| Boot | System `LaunchScreen` (blue + centered “Mind Mapper”) → `DatabaseManager` → `AppContainer` → `AppRootHost` / `SessionRestoreView`, or boot-failure text |
| Theme | Color/font/spacing tokens + shared components (`PrimaryButton`, `ThemeTextField`, `ThemeBadge`, …) |
| Local DB | GRDB `memory.db`, V1 schema (`users`, `sessions`, `messages`, `memories`, …) |
| Auth | Email sign up / sign in / sign out, session restore, forgot password, set new password, deep-link callback |
| Reachability | Single `NetworkReachabilityService` (`NWPathMonitor`), global offline banner, `NetworkGate` + auth VM guards |
| Reconnect | On path → connected, `revalidateSessionIfNeeded()` |
| Local user | On auth success, upsert `users` via `AuthRepository` |
| Screens in flow | Onboarding, Login (sheet), Forgot password (sheet), Set new password, Root tabs (Chats / Memories / Settings), Session list shell, Chat shell, session restore splash, boot failure, offline banner |
| Navigation | `AppRouter` (`path`, sheets, `selectedTab`, `.openMemory` deep link) as `@EnvironmentObject` |
| Config | `AppConfig` (Supabase URL/key, `mindmapper://auth-callback`) |

---

## 1. Cold start → root gate

```mermaid
flowchart TD
    A["@main MindMapperApp"] --> B{"DatabaseManager.shared?"}
    B -->|nil| C["Boot failure UI<br/>Couldn't open local storage"]
    B -->|ok| D{"AppContainer.make<br/>valid Supabase URL?"}
    D -->|nil| E["Boot failure UI<br/>Couldn't configure the backend"]
    D -->|ok| F["AppRootHost<br/>StateObject AppContainer + AppRouter<br/>ObservedObject AuthManager"]
    F --> G[".task → restoreSession()"]
    F --> DL[".onOpenURL → handleAuthCallback"]
    F --> Net["NetworkReachabilityService"]
    Net -->|disconnected| Ban["Top ThemeBadge offline banner"]
    Net -->|connected| Rev["revalidateSessionIfNeeded()"]
    G --> H{"isRestoringSession?"}
    H -->|yes| I["SessionRestoreView<br/>rotating splash logo"]
    H -->|no| J{"pendingPasswordReset?"}
    J -->|yes| K["SetNewPasswordView"]
    J -->|no| L{"isAuthenticated?"}
    L -->|yes| M["RootView"]
    L -->|no| N["OnboardingView"]
    DL --> Overlay["Optional bottom ThemeBadge<br/>deepLinkErrorMessage"]
```

Auth sheets call `NetworkGate.requireConnection` before Supabase; offline attempts show `AppError.noInternet` inline (banner remains the global signal).

Gate priority in `AppRootHost` (first match wins):

1. `isRestoringSession` → spinner  
2. `pendingPasswordReset` → set new password  
3. `isAuthenticated` → Root  
4. else → Onboarding  

`isRestoringSession` defaults to `true` until `restoreSession()` finishes (including remote validation), so cold start shows `SessionRestoreView` (branded splash) briefly — longer if the network is slow.

---

## 2. Session restore (local-first) — task 07b

```mermaid
flowchart TD
    A["restoreSession()"] --> B{"client.auth.currentSession<br/>local storage?"}
    B -->|no| C["clearLocalAuth<br/>no remote signOut<br/>isAuthenticated = false"]
    B -->|yes| D["applyRestoredSession<br/>fetch/upsert SQLite user<br/>isAuthenticated = true"]
    D --> E["validateSessionRemotely<br/>auth.session refresh + auth.user"]
    E --> F{"Outcome"}
    F -->|OK| G["needsRemoteRevalidation = false"]
    F -->|network / transient| H["Keep signed in<br/>needsRemoteRevalidation = true"]
    F -->|hard auth failure| I["clearLocalAuth + remote signOut"]
    C --> J["isRestoringSession = false"]
    G --> J
    H --> J
    I --> J
    J --> K["AppRootHost shows Onboarding or Root"]
```

Classifier: `AuthNetworkErrorClassifier` (transient vs hard auth).  
`revalidateSessionIfNeeded()` exists on the protocol but is **not** called from UI yet (task 07d).

---

## 3. Unauthenticated path

```mermaid
flowchart TD
    O["OnboardingView"] -->|Continue with email| L["LoginView sheet"]
    L -->|Need an account? / Already have…| Mode["toggle isSignUpMode"]
    L -->|Forgot password? sign-in only| FP["ForgotPasswordView sheet"]
    L -->|Sign in| SI["AuthManager.signIn"]
    L -->|Sign up| SU["AuthManager.signUp<br/>redirectTo auth-callback"]
    SI --> Persist["AuthRepository.upsert User<br/>isAuthenticated = true"]
    SU -->|session returned| Persist
    SU -->|no session confirm required| Confirm["errorMessage:<br/>emailConfirmationRequired"]
    Persist --> Swap["AppRootHost replaces tree with RootView<br/>Onboarding + sheets go away"]
    FP -->|Submit| Reset["requestPasswordReset"]
    Reset --> Msg["Always success copy<br/>passwordResetEmailSent<br/>anti-enumeration"]
    Reset --> Mail["Email → mindmapper://auth-callback"]
```

Notes:

- Login / Forgot password are **sheets** on Onboarding. Authenticated navigation uses `AppRouter` (tabs + Chats `NavigationStack`).
- Login does not call `dismiss()` on success — the host swaps to `RootView`, so Onboarding (and its sheet) leave the hierarchy.
- Errors surface as `ThemeBadge` via `AppError` on the ViewModel.

---

## 4. Deep links (`mindmapper://auth-callback`)

Registered URL scheme + `AppConfig.authCallbackURLString`. Same handler for **confirm email** and **password recovery**.

```mermaid
flowchart TD
    U["App opens / resumes with URL"] --> H["handleAuthCallback"]
    H --> P{"client.auth.session from URL?"}
    P -->|fail| Err["deepLinkErrorMessage<br/>ThemeBadge overlay on AppRootHost"]
    P -->|ok| T{"recovery?<br/>type=recovery or expectPasswordRecovery"}
    T -->|yes| SP["upsert user<br/>pendingPasswordReset = true<br/>isAuthenticated = false"]
    T -->|no| Auth["upsert user<br/>isAuthenticated = true<br/>pendingPasswordReset = false"]
    SP --> SetPW["SetNewPasswordView"]
    Auth --> Root["RootView"]
    SetPW -->|passwords match + updatePassword| Done["pendingPasswordReset = false<br/>isAuthenticated = true → RootView"]
    SetPW -->|mismatch / API error| Badge["error ThemeBadge on screen"]
```

---

## 5. Signed-in path (today)

```mermaid
flowchart TD
    R["RootView TabView<br/>tint = Color.theme.accent"] --> C["Chats tab<br/>NavigationStack path = router.path"]
    R --> M["Memories tab<br/>placeholder"]
    R --> S["Settings tab<br/>email + Sign out"]
    C --> L["SessionListView<br/>+ new / tap row"]
    L -->|router.navigate chat| Chat["ChatView<br/>bubbles + input + close hooks"]
    Chat -->|Done / navigateBack / delete| L
    S -->|Sign out| SO["AuthManager.signOut"]
    SO -->|ok| O["isAuthenticated = false → Onboarding"]
    N["Notification .openMemory"] --> R
    N -->|resolve session_id or memory_id| Chat
```

`RootView` is the authenticated shell. Session list (task 17) and chat UI (task 18) are shipped. Sign-out lives on Settings.

---

## 6. Auth call shape (every auth screen)

```mermaid
flowchart LR
    V["View"] --> VM["ViewModel"]
    VM --> AM["AuthManager"]
    AM --> SB["Supabase Auth"]
    AM --> AR["AuthRepository"]
    AR --> DB["GRDB users table"]
```

ViewModels never talk to Supabase or GRDB directly. Factories live on `AppContainer` (`makeLoginViewModel()`, etc.).

---

## Screen map (current)

| Surface | Entry | Exit / next |
|--------|--------|-------------|
| Boot failure text | DB or config missing | — |
| `SessionRestoreView` (rotating logo) | `isRestoringSession` | Onboarding / Root / SetNewPassword |
| `OnboardingView` | Signed out, not resetting password | Sheet → Login |
| `LoginView` | Onboarding sheet | Sign-in/up → Root; or sheet → Forgot password |
| `ForgotPasswordView` | Login sheet | Success message; email deep link later |
| `SetNewPasswordView` | Recovery deep link | Update password → Root |
| `RootView` (tabs) | `isAuthenticated` | Chats / Memories / Settings; sign out → Onboarding |
| `SessionListView` | Chats tab root | + or row → `ChatView` via `AppRouter` |
| `ChatView` | `Destination.chat` | Menu memories/delete; disappear/background → `closeSession` |
| `MemoryListView` (placeholder) | Memories tab or push | — |
| `SettingsView` | Settings tab | Sign out / delete account → Onboarding |
| Deep-link error badge | Failed `handleAuthCallback` | Tap to clear |
| Offline banner (top) | `networkReachability.status == .disconnected` | Auto-hides when connected |

---

## Present in the project but **not** in the live flow

| Item | Status |
|------|--------|
| `ContentView` | Xcode template leftover — not used by `@main` |
| Memories list / memory detail content | Placeholders |
| Push notification → `.openMemory` poster | Observer ready; delegate in task 20 |
| Sign in with Apple | Pre-release checklist |

---

## Maintenance checklist (when a task changes flow)

- [ ] Update the relevant Mermaid diagram(s)
- [ ] Update **Screen map** and **Built so far**
- [ ] Move items out of **not in the live flow** when they ship
- [ ] Keep this file scoped to **runtime user flow**, not every class in the repo
