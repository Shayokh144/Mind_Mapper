# Build Session List UI

---

## Category
`ios`

## Estimated Time
⏱️ 3–4 hours

## Depends On
Task 5 (Theme), Task 15 (Sessions have titles and tags), Task 16 (AppRouter)

## Related Plan Section
📄 `../planning/execution-plan.md` → Phase 11 — SwiftUI Interface › Step 11.1 | ../../iOSApp/AGENT.md › Section 3.1 (Views are thin), Section 3.3 (Display Models)

## Related UI
Screen 2 in the UI mockup — Home screen / Session List. Shows: large title 'My memory', search bar, list of sessions each with coloured icon tile, session title, topic tag, relative timestamp. Plus button in top-right navigation bar. Three-tab bottom navigation.

---

## What To Do

- [ ] **1.** Extend `Features/Sessions/SessionListViewModel.swift` (shell shipped in task 16). Keep `SessionRepository` + `AppRouter` injection. Replace published `[Session]` with `@Published var sessions: [SessionDisplayModel]`. Implement / refine `loadSessions(userId:) async`, `openSession(_ session: SessionDisplayModel)` (calls `router.navigate`), `startNewSession(userId:) async`. Map `Session` domain models to `SessionDisplayModel` in the ViewModel — the View never sees raw `Session` objects.
- [ ] **2.** Define `SessionDisplayModel: Identifiable` with: id, title (with 'New conversation' fallback), topicTag, relativeDate (formatted as relative string), iconName (SF Symbol name mapped from TopicTag), iconColor (Color from theme mapped from TopicTag). Map topic tags to icons: wardrobe→'tshirt', plans→'airplane', gifts→'gift', work→'briefcase', health→'heart', etc.
- [ ] **3.** Extend `Features/Sessions/SessionListView.swift` (shell from task 16 — already inside RootView’s `NavigationStack`; do **not** nest another stack). Use `container.makeSessionListViewModel(router:)` (**optional**). Body: large title, search bar (`ThemeTextField`), `List` of session rows, empty state ('Start your first conversation — tap + to begin'), toolbar + button.
- [ ] **4.** Build `SessionRowView` as a subcomponent: 38×38pt rounded icon tile with background color and SF Symbol, session title in `.headlineStyle()`, topic tag in `.captionStyle()`, relative date aligned trailing in `.captionStyle()`.
- [ ] **5.** Add swipe-to-delete on the list rows. On delete, show a `.confirmationDialog` asking 'Delete this conversation and all its memories?' with a destructive button. On confirmation, call the delete use case (built in Task 19).
- [ ] **6.** Implement the search bar: filter `sessions` array in the ViewModel by `title.localizedCaseInsensitiveContains(searchText)` as a computed property. The search is purely local — no LLM call.
- [ ] **7.** Apply `.task { await viewModel.loadSessions(userId: ...) }` to the view — never call async work from `onAppear`. *(Shell already uses `.task { await viewModel.loadSessions() }`.)*

---

## ✅ Done When

- [ ] Session list loads and shows all sessions ordered by last updated.
- [ ] Each row shows the correct coloured icon, title, tag, and relative date.
- [ ] Tapping a row navigates to ChatView via AppRouter.
- [ ] Tapping + creates a new session and navigates to a blank ChatView.
- [ ] Typing in the search bar filters sessions in real time.
- [ ] Swipe-to-delete shows confirmation dialog, then removes the row and cleans up data.
- [ ] Empty state view appears when there are no sessions.

---

## 📝 Notes

The View must not import GRDB or Supabase. It must not call `DatabaseManager` directly. It receives only `SessionDisplayModel` objects from the ViewModel. The `iconColor` for each topic must come from `Color.theme` tokens, not hardcoded hex values.

**Already shipped:** `SessionRepository.fetchAll(for:)` / `save` / `update` (tasks 14–15). Titles and `topicTag` come from `CloseSessionUseCase`. Task 16 shipped shell `SessionListView` / `SessionListViewModel` + `makeSessionListViewModel(router:)` (optional) and Root tab navigation — **extend** those files; do not recreate or nest a second `NavigationStack`.

