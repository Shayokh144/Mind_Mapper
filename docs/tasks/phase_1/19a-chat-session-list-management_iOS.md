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
Chats tab root list (`ChatSessionListView`): row capsules for topic tags, swipe / context menu for rename + pin, sheet or alert to create a custom tag. Built-in tags stay the fixed set from `Session.TopicTag` (wardrobe, plans, locations, people, ideas, gifts, work, health, other).

---

## What To Do

### Rename types (SessionList → ChatSession)

- [ ] **1.** Rename `SessionListView` → `ChatSessionListView` (file + type). Rename related presentation types consistently:
      - `SessionListViewModel` → `ChatSessionListViewModel`
      - `SessionDisplayModel` → `ChatSessionDisplayModel`
      - `SessionRowView` → `ChatSessionRowView`
      - `AppContainer.makeSessionListViewModel(router:)` → `makeChatSessionListViewModel(router:)`
      - Update call sites (`RootView`, previews, tests, `AGENT.md` tree / examples).
      Keep the feature folder `Features/Sessions/` (domain still uses `Session`). Do **not** rename `DeleteSessionUseCase` / `SessionRepository`.

### Domain + persistence (pin + custom tags)

- [ ] **2.** Add pin support on `Session`: `isPinned: Bool` (default `false`). GRDB migration (e.g. `v2_session_pin_and_custom_tag`) adding `is_pinned INTEGER NOT NULL DEFAULT 0` on `sessions`. Update `SessionRecord` ↔ domain mapping. Sort list: **pinned first**, then `updatedAt` descending (existing order for unpinned).

- [ ] **3.** Support **user-created topic tags** beyond the built-in `Session.TopicTag` cases. Today `SessionRecord.topicTag` is a `String?` but domain maps only known enum raw values — unknown strings become `nil`. Fix that:
      - Prefer a small domain representation, e.g. built-in `TopicTag` **or** custom `String` (trimmed, non-empty, reasonable max length).
      - Persist custom labels in the existing `topic_tag` column (free-form string). Built-ins keep writing enum `rawValue` (CloseSessionUseCase unchanged for LLM-assigned tags).
      - Close / LLM path may still overwrite with a built-in tag later — document that in Notes; user can re-apply a custom tag after close if needed (or preserve custom when present — pick one and stick to it).

- [ ] **4.** Thin use cases (or one metadata use case with clear methods) + `AppContainer` factories:
      - Rename session title (`execute(sessionId:title:)`)
      - Toggle / set pin (`execute(sessionId:isPinned:)`)
      - Set topic tag (built-in or custom) (`execute(sessionId:tag:)`)
      All persist via `SessionRepository.update` (or focused repo helpers). No DB calls from the View.

### List UI / ViewModel

- [ ] **5.** Extend `ChatSessionListViewModel`: load/sort with pins; `rename` / `togglePin` / `setTopicTag` (or equivalent); confirmation / sheet presentation state. Keep swipe-to-delete + confirmation from tasks 17 / 19.

- [ ] **6.** User can **rename** a session (edit title). Prefer context menu and/or swipe action → alert / sheet with `ThemeTextField` + Save / Cancel. Empty title → fall back to “New conversation” display (same as today). Persist trimmed title; bump `updatedAt`.

- [ ] **7.** User can **pin** a session to the top (and unpin). Leading swipe and/or context menu with pin / unpin. Show a small pin affordance on the row when pinned (SF Symbol `pin.fill`, theme tokens only). Re-sort immediately after toggle.

- [ ] **8.** User can assign a **built-in** tag or **create a custom** tag (text entry). UI: picker / sheet listing built-in tags + “Create tag…” field. Validate length (reuse input-guard style limits if a constant exists; otherwise a sensible cap e.g. 24–32 chars). Custom tags must use a **distinct** color from all built-in `iconColor` mappings in `ChatSessionDisplayModel` (dedicated theme token or a clear unused semantic color — no raw hex).

- [ ] **9.** Render **all** topic tags as **capsule** UI on the row (and in any tag picker chips). Prefer composing `ThemeBadge` with capsule clipping (`Capsule()` / `Radius.pill`) — do not leave tags as plain caption `Text`. Built-in tags keep existing icon + color mapping; custom tags use the dedicated custom color (icon can be generic, e.g. `tag` / `bubble.left`).

- [ ] **10.** Update `L10n.Sessions` (rename / pin / unpin / tag / create tag / validation errors). Update `docs/design/app-flow.md` screen name if it still says `SessionListView`. Update `iOSApp/AGENT.md` folder tree + factory names. Brief “Planned → As shipped” note on Step 11.1 in the execution plan when done.

---

## ✅ Done When

- [ ] Types renamed: `ChatSessionListView` / `ChatSessionListViewModel` / `ChatSessionDisplayModel` / `ChatSessionRowView` + factory; app builds; delete swipe still works.
- [ ] User can rename a session title; list shows the new title after save.
- [ ] User can pin / unpin; pinned sessions stay at the top across reload.
- [ ] User can pick a built-in tag **or** create a custom tag; custom tags survive reload (not dropped by enum mapping).
- [ ] Custom tag color is visually distinct from built-in tag colors.
- [ ] Every visible topic tag uses capsule / pill chrome (not plain text).
- [ ] Views stay thin: theme tokens only; no GRDB / `DatabaseManager` in Views.

---

## 📝 Notes

**Already shipped (extend, do not recreate):**
- List shell, search, empty state, `+` new session, swipe delete → confirmation → `DeleteSessionUseCase` (tasks 17 / 19).
- `SessionRepository.fetchAll` / `save` / `update` / `deleteCascade`.
- Built-in `Session.TopicTag` + `CloseSessionUseCase` LLM title/tag assignment.
- `ThemeBadge` (pill radius) — good base for capsule tags.

**Out of scope:**
- Syncing pins/tags to Supabase.
- Renaming the domain `Session` type or delete use cases.
- Memory list UI (task 22), portfolio empty-state polish (task 21 — update that doc’s type names if it still says `SessionListView`).

**Suggested row actions:**
| Action | UI |
|---|---|
| Delete | Trailing swipe (existing) |
| Pin / Unpin | Leading swipe and/or context menu |
| Rename | Context menu → alert/sheet |
| Tag | Context menu → sheet (built-ins + create custom) |
