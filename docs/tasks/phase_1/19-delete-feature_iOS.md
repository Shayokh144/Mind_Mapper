# Build Delete Feature (Session, Memory & Account Deletion)

---

## Category
`ios`

## Estimated Time
⏱️ 3–4 hours

## Depends On
Task 6 (database), Task 17 (SessionListView swipe), Task 18 (ChatView menu)

## Related Plan Section
📄 `../planning/execution-plan.md` → Chat/Session Delete section in the execution plan — full deletion dependency chain analysis

## Related UI
Session List (swipe-to-delete row), Chat View (kebab menu → Delete conversation), Settings screen (Delete account button). Confirmation dialogs appear on all three.

---

## What To Do

- [x] **1.** Create `Domain/UseCases/DeleteSessionUseCase.swift` with protocol and implementation. *(Shipped with task 17 for list swipe — extend tests / call sites here.)*
- [x] **2.** Implement `execute(sessionId: String) async throws` following the mandatory deletion order from the execution plan: (1) fetch all memoryIds for the session, (2) DELETE from memory_entities WHERE memory_id IN (memoryIds), (3) DELETE from vectors WHERE memory_id IN (memoryIds), (4) DELETE from memories WHERE session_id = sessionId, (5) DELETE from messages WHERE session_id = sessionId, (6) DELETE the session row itself. All six steps must be wrapped in a single GRDB write transaction. *(As shipped: `SessionRepository.deleteCascade(id:)` + `DeleteSessionUseCase`.)*
- [x] **3.** Create `Domain/UseCases/DeleteMemoryUseCase.swift`. Implement single-memory deletion: (1) delete memory_entities for the memory, (2) delete the vector, (3) check if this memory has a `supersedes_id` — if so, set `is_superseded = false` on the older memory (restore it to RAG visibility), (4) delete the memory row.
- [x] **4.** Create `Domain/UseCases/DeleteAccountUseCase.swift`. Implement: fetch all sessionIds for the user, call `DeleteSessionUseCase.execute()` for each, delete the user row from SQLite, call `AuthManager.signOut()`.
- [x] **5.** Register all three use cases in `AppContainer`. *(Partial: `makeDeleteSessionUseCase()` already wired for session list.)*
- [x] **6.** Add `deleteSession(_ sessionId: String) async` to `SessionListViewModel`. Show the `.confirmationDialog` with the exact copy: 'Delete this conversation and all its memories?' and 'This cannot be undone.' Destructive button text: 'Delete conversation'. *(Shipped in task 17 as `requestDelete` / `confirmDelete`.)*
- [x] **7.** Add `deleteCurrentSession() async` to `ChatViewModel`. On confirmation, call `DeleteSessionUseCase`, then call `router.navigateBack()` to return to the session list. *(Shipped in task 18 as `confirmDeleteConversation()` via kebab menu.)*
- [x] **8.** Create `Features/Settings/SettingsView.swift` (basic version). Show: user email, Sign out button (`SecondaryButton`), 'Delete my account and all data' button (`DestructiveButton` outlined style) at the bottom. Account deletion shows a two-step confirmation: first dialog warns that all memories will be permanently deleted, second dialog requires typing 'DELETE' to confirm. *(Settings shell may already exist — extend with account delete.)*
- [x] **9.** Write a unit test for `DeleteSessionUseCase` that verifies all five child tables are cleaned up before the parent session row is deleted.

---

## ✅ Done When

- [x] Swipe-to-delete on session list → confirmation dialog → all 5 tables cleaned up → row removed from list.
- [x] After session delete, querying that topic in a different session returns no results from the deleted session.
- [x] Deleting a memory that superseded an older one → the older memory becomes visible in RAG again (is_superseded = false).
- [x] Account delete → all sessions, memories, vectors, entities, and user row removed → app navigates to OnboardingView.
- [x] Unit test verifies deletion order (children before parent).

---

## 📝 Notes

The deletion order is critical and must not be changed. SQLite foreign key constraints will cause errors if you delete a parent row before its children. Test this with FK enforcement on: `PRAGMA foreign_keys = ON` in the DatabaseManager. The 'restore superseded memory' logic in DeleteMemoryUseCase is a subtle edge case — document it with a code comment explaining why it's necessary.

**As shipped:**
- `DeleteSessionUseCase` / `SessionRepository.deleteCascade` (tasks 17–18 UI already wired).
- `DeleteMemoryUseCase` → `MemoryRepository.delete` restores `supersedes_id` target (`is_superseded = 0`) then removes entities/vector/memory. **Memory list / detail UI call sites → task 22**; use case + unit test shipped.
- `DeleteAccountUseCase` + Settings two-step confirm (warning dialog → type `DELETE` sheet) → sign-out → Onboarding via existing auth state.
- Factories: `makeDeleteSessionUseCase()` / `makeDeleteMemoryUseCase()` / `makeDeleteAccountUseCase()`.
- Tests: `DeleteSessionUseCaseTests`, `DeleteMemoryUseCaseTests`.

**Follow-on:** Session list rename / pin / custom tags + rename `SessionListView` → `ChatSessionListView` → [task 19a](19a-chat-session-list-management_iOS.md).
