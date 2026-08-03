# Polish, Settings Screen & Portfolio Prep

---

## Category
`ios`

## Estimated Time
⏱️ 4–6 hours

## Depends On
Task 20 (all tests passing)

## Related Plan Section
📄 `../planning/execution-plan.md` → Phase 13 — Polish & Portfolio Prep

## Related UI
App Icon + Launch Screen, empty states in Session List and Chat View, Settings screen (basic version from Task 19 expanded), app-level AppLifecycleListener.

---

## What To Do

- [ ] **1.** Create the app icon: design a simple, clean icon representing memory/brain/conversation. Use SF Symbols 'brain.head.profile' or 'bubble.left.and.bubble.right' as inspiration. Export at all required sizes and add to Assets.xcassets → AppIcon.
- [ ] **2.** Create a Launch Screen storyboard or `LaunchScreen.storyboard`. Center the app name 'Memory' in the screen background using `Color.theme.background` equivalent. Keep it minimal.
- [ ] **3.** Add the empty state view to the Chats list (`ChatSessionListView` after task 19a; today `SessionListView`): when `sessions.isEmpty`, show a centered illustration (SF Symbol 'message.badge.filled.fill' at large size, `Color.theme.textMuted`), a headline 'Nothing here yet', and body text 'Start a new chat and tell the app something you want to remember'.
- [ ] **4.** Add the empty state view to `ChatView`: when `viewModel.messages.isEmpty` (new session), show a centered prompt: SF Symbol 'sparkles' in accent color, headline 'What's on your mind?', and body 'Tell me a fact, a plan, or ask about something you've shared before.'
- [ ] **5.** Expand `SettingsView` to include: a profile section (avatar placeholder + email), app version number (read from Bundle), a Feedback row that opens a mailto link, a Privacy Policy row (open Safari), a 'How it works' row (open a sheet with a brief RAG explanation for users), Sign out SecondaryButton, and Delete Account DestructiveButton.
- [ ] **6.** Add `AppLifecycleListener` in `MindMapperApp.swift` using SwiftUI's `.onChange(of: scenePhase)`. On `.background`, trigger `CloseSessionUseCase` for the current active session if one exists.
- [ ] **7.** Write a `README.md` for the GitHub repository. Include: app description (2–3 sentences), architecture overview (MVVM + Clean Architecture), tech stack table (SwiftUI, GRDB, Supabase, OpenAI), key features (RAG pipeline, cross-session memory, scope guard), and a setup guide for other developers (API keys, Supabase project).
- [ ] **8.** Take screenshots on your iPhone for the 3 main screens (Onboarding, Session List, Chat) in both light and dark mode. Save them in a `Screenshots/` folder in the repo.
- [ ] **9.** Make a final commit with message 'Portfolio MVP complete'. Tag it as `v1.0.0-mvp` in Git.

---

## ✅ Done When

- [ ] App icon appears correctly in the home screen and app switcher.
- [ ] Launch screen appears briefly and is visually consistent with the app's light/dark mode.
- [ ] Empty states appear in Session List and Chat with correct copy and icons.
- [ ] Settings screen shows all sections and all interactive rows work.
- [ ] App backgrounding triggers session close (verify session title appears when foregrounding).
- [ ] README.md is clear enough that another iOS developer could clone and run the project.
- [ ] GitHub repo is clean: no API keys, no .xcuserstate files, no DerivedData.

---

## 📝 Notes

This is your portfolio piece. Spend extra time on the app icon and empty states — they are the first things a hiring manager or interviewer will notice. The README is equally important — it signals your architectural thinking even before they read the code.
