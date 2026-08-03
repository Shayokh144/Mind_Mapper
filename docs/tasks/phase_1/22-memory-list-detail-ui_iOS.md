# Build Memories List & Memory Detail UI

---

## Category
`ios`

## Estimated Time
⏱️ 3–4 hours

## Depends On
Task 5 (Theme), Task 11 (`Memory` / `MemoryRepository` / entities), Task 16 (`AppRouter` + placeholders), Task 18 (chat kebab → `memoryList`), Task 19 (`DeleteMemoryUseCase`)

## Related Plan Section
📄 `../planning/execution-plan.md` → Phase 11 — SwiftUI Interface (add Step 11.3) | Chat/Session Delete — per-memory delete UI | ../../iOSApp/AGENT.md › Section 3.1 (Views are thin), Section 3.3 (Display Models)

## Related UI
Memories tab (all memories), Chat kebab → “View memories in this chat” (session-scoped list), tap row → memory detail sheet. Delete confirmation on list swipe / detail.

---

## What To Do

- [ ] **1.** Extend `Features/Memories/MemoryListView.swift` (placeholder from task 16). Add `MemoryListViewModel` via `AppContainer.makeMemoryListViewModel(sessionId:router:)` (**optional** when unauthenticated). `sessionId == nil` → all memories for the user; non-nil → filter to that chat. Do **not** nest a second `NavigationStack` when pushed from Chats; the Memories **tab** already has its own stack in `RootView`.
- [ ] **2.** Define `MemoryDisplayModel: Identifiable` with at least: id, cleanText (primary line), relativeDate, isSuperseded, sessionTitle (optional caption when showing all memories), entitySummary (short joined entity values or count). Map `Memory` (+ optional session title / entities) in the ViewModel — the View never sees raw `Memory` / GRDB types.
- [ ] **3.** If needed, extend `MemoryRepositoryProtocol` with `fetchAll(forSessionId:)` (or filter in the VM from `fetchAll(for: userId)`). Prefer a repository method when session-scoped lists grow large. Hide superseded rows by default (or show with a muted “outdated” style — pick one and document in Notes).
- [ ] **4.** Build the list UI: empty state (`L10n.Memories.*`), `List` / `LazyVStack` of rows, optional local search on `cleanText` (same pattern as session list — no LLM). Row shows clean text + relative date; superseded styling if shown.
- [ ] **5.** On row tap, present detail via `router.present(.memoryDetail(memoryId:))` (sheet already wired in `RootView`).
- [ ] **6.** Replace `MemoryDetailPlaceholder` with a real `MemoryDetailView`.
      Load memory + entities via repository / thin ViewModel. Show:
      clean text (primary), raw text (secondary, collapsible), entity pills,
      created date, superseded/supersedes chain with dates.
      Add "View in chat" button → router.navigate(to: .chat(sessionId:))
      so user can jump to the original conversation from anywhere in the app.
      Session title shown as caption when opened from the global Memories tab.
- [ ] **7.** Wire delete: swipe-to-delete on list and/or destructive button on detail → confirmation → `DeleteMemoryUseCase.execute` (task 19 already restores superseded older memory). Dismiss detail / remove row on success.
- [ ] **8.** Confirm Chat kebab “View memories in this chat” still navigates to `Destination.memoryList(sessionId:)` and shows the scoped list. Confirm Memories tab (`sessionId: nil`) shows all user memories.
- [ ] **9.** Register `makeMemoryListViewModel` (and detail factory if used) in `AppContainer`. Update `iOSApp/AGENT.md` folder tree / factories. Update `docs/design/app-flow.md` screen map (move Memories list/detail out of placeholders).

---

## ✅ Done When

- [ ] Memories tab lists saved facts (clean text + date); empty state when none.
- [ ] Chat → View memories in this chat shows only that session’s memories.
- [ ] Tapping a row opens a detail sheet with real content (not only `memoryId` + placeholder copy).
- [ ] Delete memory (list and/or detail) confirms, removes the row, and keeps RAG supersede restore behaviour from task 19.
- [ ] Views stay thin: theme tokens only; no GRDB / Supabase / `DatabaseManager` in Views.

---

## 📝 Notes

**Already shipped (do not recreate):**
- `AppRouter.Sheet.memoryDetail` + `RootView` sheet switch → currently `MemoryDetailPlaceholder`.
- `Destination.memoryList(sessionId:)` + chat kebab navigation (task 18).
- `MemoryRepository.fetchAll(for:)` / `fetch(id:)` / `fetchEntities(for:)` / `delete` + `DeleteMemoryUseCase` (tasks 11 / 19).
- Placeholder `MemoryListView(sessionId:)` under Memories tab and chat push.

**Out of scope for this task:** editing memory text, syncing memories to Supabase, push deep-link polish (task 20), redesign of Settings.

**As shipped:** _(fill in when implementing)_
