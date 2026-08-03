# Build Chat UI

---

## Category
`ios`

## Estimated Time
⏱️ 4–6 hours

## Depends On
Task 14 (ChatViewModel), Task 5 (Theme components — ChatBubble, ThemeTextField, ThemeBadge)

## Related Plan Section
📄 `../planning/execution-plan.md` → Phase 11 — SwiftUI Interface › Step 11.2 | ../../iOSApp/AGENT.md › Section 3.1, 6.4 (streaming)

## Related UI
Screens 3 and 4 in the UI mockup — Chat View in light and dark mode. Shows: navigation bar with session title and kebab menu, message bubbles (user right/assistant left), typing indicator (three dots), 'Found across N conversations' ThemeBadge, scope-blocked warning bubble, input bar with placeholder text and send button, character counter.

---

## What To Do

- [x] **1.** Extend `Features/Chat/ChatView.swift` (shell shipped in task 16 — loads session, closes on disappear/background). Keep receiving a `ChatViewModel` from `container.makeChatViewModel(sessionId:router:)` (**optional**; `nil` if unauthenticated). Replace the stub list with the full chat UI below — do not recreate the file or re-wire close hooks from scratch.
- [x] **2.** Build the message list using `ScrollViewReader` wrapping a `ScrollView` with a `LazyVStack`. Each `MessageDisplayModel` (already shipped) renders as either a user or assistant `ChatBubble` component from the theme system. Auto-scroll to the bottom when `viewModel.messages.count` changes using `proxy.scrollTo(last.id, anchor: .bottom)` wrapped in `withAnimation`.
- [x] **3.** Add a `TypingIndicator` at the bottom of the list when `viewModel.isLoading` is true. The indicator shows three animated dots in an assistant bubble shape.
- [x] **4.** Add the 'Found across N conversations' `ThemeBadge` with `.accent` role and `sparkles` SF Symbol below the assistant bubble when `viewModel.lastAnswerSessionCount > 1`. This badge should only appear for QUERY and MIXED intent responses.
- [x] **5.** Add the error banner below the message list: when `viewModel.errorMessage` is non-nil, show a `ThemeBadge` with `.warning` role. Dismissed when the user taps it or sends a new message.
- [x] **6.** Build the input bar at the bottom: a `ThemeTextField` component with placeholder 'Tell me something or ask...', a character counter label showing `500 - inputText.count` that turns red when below 50 characters remaining, and a circular send button using `Color.theme.accent` fill with a white upward arrow SF Symbol. Disable the send button when `inputText` is empty or `viewModel.isLoading` is true.
- [x] **7.** Add a `@FocusState` for the text field. Tapping the message list dismisses the keyboard using `.scrollDismissesKeyboard(.interactively)`.
- [x] **8.** In the navigation bar: show the session title. Add a trailing kebab menu button (`circle.grid.2x2` or `ellipsis` SF Symbol) with a `Menu` containing: 'View memories in this chat' (navigate to MemoryListView for this session — **full list UI in task 22**) and 'Delete conversation' (calls delete with confirmation).
- [x] **9.** Confirm `viewModel.closeSession()` still runs on `.onDisappear` and `.onAppBackground` (already wired in task 16 shell) — keep those hooks when rebuilding the body.
- [x] **10.** Confirm `.task { await viewModel.loadSession() }` remains on the view when the UI is rebuilt.

---

## ✅ Done When

- [x] Message history loads correctly when opening an old session.
- [x] Sending a message shows user bubble immediately, then typing indicator, then assistant bubble.
- [x] 'Found across 2 conversations' badge appears for cross-session queries.
- [x] Scope-blocked message shows a warning-bordered assistant bubble.
- [x] Character counter turns red below 50 remaining.
- [x] Send button is disabled when text field is empty.
- [x] Keyboard dismisses when scrolling up through messages.
- [x] View works correctly in both light and dark mode (test in Xcode Canvas).

---

## 📝 Notes

The `ChatBubble` component from the theme system (Task 5) handles all bubble styling. Do not re-implement bubble styles in this view. The `ThemeTextField` from the theme system handles the 500-character limit automatically — do not add a second limit check here. The typing indicator animation should use `withAnimation(.easeInOut(duration: 0.5).repeatForever())` on the dot opacity.

**Badge data:** `viewModel.lastAnswerSessionCount` comes from `RAGAnswer.representedSessionIds.count` set in `ChatViewModel` after QUERY/MIXED (task 14). Do not recompute session IDs in the view.

**Already shipped (task 14):** `ChatViewModel`, `MessageDisplayModel`, `ChatDependencies`, `sendMessage` / `loadSession` / `startNewSession`.  
**Already shipped (task 16):** Stub `ChatView` + Root navigation into chat; `.onDisappear` / `.onAppBackground` already call `closeSession()`. This task is SwiftUI polish — do not reimplement the orchestrator or close pipeline.

**As shipped:**
- Full `ChatView` with ScrollViewReader / LazyVStack, `TypingIndicator` (`Core/Theme/Components/`), input bar, kebab menu.
- `ChatBubble(isWarning:)` for scope-blocked replies; scope no longer duplicates into `errorMessage`.
- `ThemeTextField` optional `focus:` for `@FocusState`.
- Menu delete → confirmation → `DeleteSessionUseCase` → `navigateBack()` (task 19 Chat delete step covered).
- Canvas: `TypingIndicator` + `ChatBubble` previews cover light/dark; full ChatView needs a live session / simulator for end-to-end.
- Leaving with no messages discards the draft session (`onLeaveChat` → `DeleteSessionUseCase`) so empty chats never appear in the list.
- Incomplete last user turn (no assistant reply): **Retry** / **Edit & retry** directly below that user bubble; reopening the chat still shows this when the last stored message is from the user. Editing mode keeps a caption + cancel near the input bar.
