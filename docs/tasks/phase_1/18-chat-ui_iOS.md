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

- [ ] **1.** Create `Features/Chat/ChatView.swift`. Receive `sessionId: String` and create `@StateObject private var viewModel: ChatViewModel` using `container.makeChatViewModel(sessionId:router:)`.
- [ ] **2.** Build the message list using `ScrollViewReader` wrapping a `ScrollView` with a `LazyVStack`. Each `MessageDisplayModel` renders as either a user or assistant `ChatBubble` component from the theme system. Auto-scroll to the bottom when `viewModel.messages.count` changes using `proxy.scrollTo(last.id, anchor: .bottom)` wrapped in `withAnimation`.
- [ ] **3.** Add a `TypingIndicator` at the bottom of the list when `viewModel.isLoading` is true. The indicator shows three animated dots in an assistant bubble shape.
- [ ] **4.** Add the 'Found across N conversations' `ThemeBadge` with `.accent` role and `sparkles` SF Symbol below the assistant bubble when `viewModel.lastAnswerSessionCount > 1`. This badge should only appear for QUERY and MIXED intent responses.
- [ ] **5.** Add the error banner below the message list: when `viewModel.errorMessage` is non-nil, show a `ThemeBadge` with `.warning` role. Dismissed when the user taps it or sends a new message.
- [ ] **6.** Build the input bar at the bottom: a `ThemeTextField` component with placeholder 'Tell me something or ask...', a character counter label showing `500 - inputText.count` that turns red when below 50 characters remaining, and a circular send button using `Color.theme.accent` fill with a white upward arrow SF Symbol. Disable the send button when `inputText` is empty or `viewModel.isLoading` is true.
- [ ] **7.** Add a `@FocusState` for the text field. Tapping the message list dismisses the keyboard using `.scrollDismissesKeyboard(.interactively)`.
- [ ] **8.** In the navigation bar: show the session title. Add a trailing kebab menu button (`circle.grid.2x2` or `ellipsis` SF Symbol) with a `Menu` containing: 'View memories in this chat' (navigate to MemoryListView for this session) and 'Delete conversation' (calls delete with confirmation).
- [ ] **9.** Trigger `viewModel.closeSession()` in `.onDisappear`. Register `AppLifecycleListener` for background trigger.
- [ ] **10.** Apply `.task { await viewModel.loadSession() }` to load message history when the view appears.

---

## ✅ Done When

- [ ] Message history loads correctly when opening an old session.
- [ ] Sending a message shows user bubble immediately, then typing indicator, then assistant bubble.
- [ ] 'Found across 2 conversations' badge appears for cross-session queries.
- [ ] Scope-blocked message shows a warning-bordered assistant bubble.
- [ ] Character counter turns red below 50 remaining.
- [ ] Send button is disabled when text field is empty.
- [ ] Keyboard dismisses when scrolling up through messages.
- [ ] View works correctly in both light and dark mode (test in Xcode Canvas).

---

## 📝 Notes

The `ChatBubble` component from the theme system (Task 5) handles all bubble styling. Do not re-implement bubble styles in this view. The `ThemeTextField` from the theme system handles the 500-character limit automatically — do not add a second limit check here. The typing indicator animation should use `withAnimation(.easeInOut(duration: 0.5).repeatForever())` on the dot opacity.

**Badge data:** `viewModel.lastAnswerSessionCount` comes from `RAGAnswer.representedSessionIds.count` set in `ChatViewModel` after QUERY/MIXED (task 14). Do not recompute session IDs in the view.
