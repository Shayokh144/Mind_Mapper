# Chat Session List — Rename, Pin & Custom Tags

---

## Category
`ios`

## Estimated Time
⏱️ 3–4 hours

## Depends On
Task 6 (database / `Session` / migrations), Task 17 (session list UI), Task 19 (delete swipe + confirmation — keep working after rename)

## Related Plan Section
📄 `../planning/execution-plan.md` → Phase 11 — Step 11.1 Session List Screen | `iOSApp/AGENT.md` › Section 3.1 / 3.3 (thin Views, display models)

## Related UI
Chats tab root list (`ChatSessionListView`): row capsules for topic tags, row kebab (⋯) → rename / update tag → shared bottom sheet (title + tag), leading swipe to pin. Built-in tags stay the fixed set from `Session.TopicTag`; free-form custom tags use `Session.Topic.custom`.

---

## What To Do

### Rename types (SessionList → ChatSession)

- [x] **1.** Rename `SessionListView` → `ChatSessionListView` (file + type). Rename related presentation types consistently:
      - `SessionListViewModel` → `ChatSessionListViewModel`
      - `SessionDisplayModel` → `ChatSessionDisplayModel`
      - `SessionRowView` → `ChatSessionRowView`
      - `AppContainer.makeSessionListViewModel(router:)` → `makeChatSessionListViewModel(router:)`
      - Update call sites (`RootView`, previews, tests, `AGENT.md` tree / examples).
      Keep the feature folder `Features/Sessions/` (domain still uses `Session`). Do **not** rename `DeleteSessionUseCase` / `SessionRepository`.

### Domain + persistence (pin + custom tags)

- [x] **2.** Add pin support on `Session`: `isPinned: Bool` (default `false`). GRDB migration `v2_session_pin` adding `is_pinned`. Update `SessionRecord` ↔ domain mapping. Sort: **pinned first**, then `updatedAt` descending (multiple pins allowed).

- [x] **3.** Support **user-created topic tags** beyond the built-in `Session.TopicTag` cases via `Session.Topic` (`.builtIn` / `.custom`). Persist in `topic_tag` column. CloseSessionUseCase still assigns built-ins from the LLM, but **preserves** an existing user title/tag.

- [x] **4.** `UpdateChatSessionUseCase` + `AppContainer.makeUpdateChatSessionUseCase()`:
      - `updateMetadata(sessionId:title:topicTag:)` — **no LLM**
      - `setPinned(sessionId:isPinned:)`

### List UI / ViewModel

- [x] **5.** Extend `ChatSessionListViewModel`: load/sort with pins; edit sheet + pin; keep swipe-to-delete + confirmation.

- [x] **6–8.** **As shipped UI (per product):** Each row has a vertical ⋯ menu with **Rename chat session** and **Update/add session tag**. Both open the **same** bottom sheet with **two fields** (title + tag), prefilled when data exists, placeholders when empty. Save persists directly (no LLM). If **both** fields are empty, Save is disabled / no-op. Custom text that matches a built-in raw value maps to `.builtIn`; otherwise `.custom` with distinct `Color.theme.splashBackground` tint.

- [x] **7.** Pin via **leading swipe** (multiple pins OK; pinned group sorted by `updatedAt`). Pin icon on row when pinned.

- [x] **9.** Topic tags render as **capsule** `ThemeBadge` (optional `tint`).

- [x] **10.** `L10n.Sessions` keys, `app-flow.md`, `AGENT.md`, execution-plan Step 11.1 note.

---

## ✅ Done When

- [x] Types renamed: `ChatSessionListView` / `ChatSessionListViewModel` / `ChatSessionDisplayModel` / `ChatSessionRowView` + factory; delete swipe still works.
- [x] User can edit title/tag via ⋯ → shared sheet; no LLM on save.
- [x] User can pin / unpin; multiple pinned sessions stay on top, ordered by last updated.
- [x] Custom tags survive reload; distinct color from built-ins.
- [x] Topic tags use capsule chrome.
- [x] Views stay thin: theme tokens only; no GRDB / `DatabaseManager` in Views.

---

## 📝 Notes

**As shipped:**
- Edit UX is one sheet (title + tag), not separate rename/tag pickers.
- `CloseSessionUseCase` skips LLM title/tag overwrite when the session already has a user title or tag (summary still generated).
- Custom tag color: `Color.theme.splashBackground`.
- Pin: leading swipe only (not in the ⋯ menu).

**Already shipped (do not recreate):**
- List shell, search, empty state, `+` new session, swipe delete → confirmation → `DeleteSessionUseCase` (tasks 17 / 19).
- `SessionRepository.fetchAll` / `save` / `update` / `deleteCascade`.
- Built-in `Session.TopicTag` + close-session LLM path.
- `ThemeBadge` — extended with `tint` + `Capsule()`.

**Out of scope:**
- Syncing pins/tags to Supabase.
- Renaming the domain `Session` type or delete use cases.
- Memory list UI (task 22).
