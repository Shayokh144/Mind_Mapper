# Build Navigation System & App Router

---

## Category
`ios`

## Estimated Time
⏱️ 2–3 hours

## Depends On
Task 7 (Auth — to know which root view to show), Task 5 (Theme — for tab bar tint)

## Related Plan Section
📄 `../planning/execution-plan.md` → Phase 10–11 | ../../iOSApp/AGENT.md › Section 5 — Navigation Best Practices

## Related UI
All screens — AppRouter controls the NavigationStack that connects Onboarding → Session List → Chat → Settings. Tab bar with 3 tabs (Chats, Memories, Settings).

---

## What To Do

- [x] **1.** `Core/Navigation/AppRouter.swift` already exists (task 14) with `Destination`, `Sheet`, `navigate(to:)`, `navigateBack()`, `navigateToRoot()`, `present(_:)`, `dismissSheet()`. Confirm it matches this task’s API; extend only if needed — do not recreate the file.
- [x] **2.** Update `MindMapperApp.swift` to initialize both `AppContainer` and `AppRouter` as `@StateObject` instances. Inject both as `@EnvironmentObject` on the root view.
- [x] **3.** Create `Features/Root/RootView.swift` with a `TabView` containing three tabs: Chats (SessionListView), Memories (MemoryListView placeholder), Settings (SettingsView placeholder). Apply `.tint(Color.theme.accent)` to the TabView. *(Today’s `RootView` is still the temporary auth shell — replace/expand it.)*
- [x] **4.** Wrap the Chats tab in a `NavigationStack(path: $router.path)`. Add a `.navigationDestination(for: AppRouter.Destination.self)` modifier that switches on the destination enum and presents the correct view.
- [x] **5.** Add `.sheet(item: $router.presentedSheet)` to handle modal presentations.
- [x] **6.** In `MindMapperApp.swift`, use `authManager.isAuthenticated` to show either `OnboardingView` or `RootView`. Use a `.animation(.easeInOut)` transition between the two.
- [x] **7.** Handle notification deep links: add a `NotificationCenter` observer for `.openMemory` notifications (posted by the notification delegate in Task 20). On receipt, navigate to the correct session using `router.navigate(to: .chat(sessionId:))`.

---

## ✅ Done When

- [x] Launching the app while unauthenticated shows OnboardingView.
- [x] After login, RootView with three tabs appears.
- [x] Tapping a session in the list navigates to ChatView (not a new modal). *(minimal list shell; polish in task 17)*
- [x] Calling `router.navigateToRoot()` from any depth returns to the session list. *(Chat toolbar “Done”)*
- [x] Tab bar icon tint matches `Color.theme.accent`.

---

## 📝 Notes

Never use `NavigationLink` with a destination view directly in list rows. Always use `Button` that calls `router.navigate(to:)` from the ViewModel. This ensures navigation logic stays in the ViewModel layer, not scattered across view bodies. See ../../iOSApp/AGENT.md Section 5.2.

**Task 14 prerequisite:** `AppRouter` + `makeChatViewModel(sessionId:router:)` already exist. This task wires them into the live app shell (tabs + `EnvironmentObject`). Chat UI itself is task 18.

**As shipped:**
- `AppRouter` extended with `Tab` / `selectedTab`, `openChat(sessionId:)`, `Notification.Name.openMemory` + `OpenMemoryUserInfoKey`.
- `AppRootHost` owns `@StateObject` `AppContainer` + `AppRouter`; both injected as `@EnvironmentObject`.
- `RootView` — Chats `NavigationStack` + destinations + sheets; Memories/Settings tabs; `.openMemory` resolves `session_id` or `memory_id` → chat.
- Minimal `SessionListView` / `SessionListViewModel` (task 17 polishes display models, search, rows).
- Stub `ChatView` (loads session, close on disappear/background; task 18 builds bubbles/input).
- `SettingsView` + `SettingsViewModel` (sign out moved from old temp RootView).
- Sheet placeholders: `NewSessionSheet`, `MemoryDetailPlaceholder`.
