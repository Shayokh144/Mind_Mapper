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

- [ ] **1.** `Core/Navigation/AppRouter.swift` already exists (task 14) with `Destination`, `Sheet`, `navigate(to:)`, `navigateBack()`, `navigateToRoot()`, `present(_:)`, `dismissSheet()`. Confirm it matches this task’s API; extend only if needed — do not recreate the file.
- [ ] **2.** Update `MindMapperApp.swift` to initialize both `AppContainer` and `AppRouter` as `@StateObject` instances. Inject both as `@EnvironmentObject` on the root view.
- [ ] **3.** Create `Features/Root/RootView.swift` with a `TabView` containing three tabs: Chats (SessionListView), Memories (MemoryListView placeholder), Settings (SettingsView placeholder). Apply `.tint(Color.theme.accent)` to the TabView. *(Today’s `RootView` is still the temporary auth shell — replace/expand it.)*
- [ ] **4.** Wrap the Chats tab in a `NavigationStack(path: $router.path)`. Add a `.navigationDestination(for: AppRouter.Destination.self)` modifier that switches on the destination enum and presents the correct view.
- [ ] **5.** Add `.sheet(item: $router.presentedSheet)` to handle modal presentations.
- [ ] **6.** In `MindMapperApp.swift`, use `authManager.isAuthenticated` to show either `OnboardingView` or `RootView`. Use a `.animation(.easeInOut)` transition between the two.
- [ ] **7.** Handle notification deep links: add a `NotificationCenter` observer for `.openMemory` notifications (posted by the notification delegate in Task 20). On receipt, navigate to the correct session using `router.navigate(to: .chat(sessionId:))`.

---

## ✅ Done When

- [ ] Launching the app while unauthenticated shows OnboardingView.
- [ ] After login, RootView with three tabs appears.
- [ ] Tapping a session in the list navigates to ChatView (not a new modal).
- [ ] Calling `router.navigateToRoot()` from any depth returns to the session list.
- [ ] Tab bar icon tint matches `Color.theme.accent`.

---

## 📝 Notes

Never use `NavigationLink` with a destination view directly in list rows. Always use `Button` that calls `router.navigate(to:)` from the ViewModel. This ensures navigation logic stays in the ViewModel layer, not scattered across view bodies. See ../../iOSApp/AGENT.md Section 5.2.

**Task 14 prerequisite:** `AppRouter` + `makeChatViewModel(sessionId:router:)` already exist. This task wires them into the live app shell (tabs + `EnvironmentObject`). Chat UI itself is task 18.
