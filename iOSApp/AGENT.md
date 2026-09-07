# AGENT.md — iOS Swift Architectural Guide

> **Purpose:** This file defines the architectural rules, patterns, and conventions for the Memory App iOS project. Every screen, service, and component must follow these guidelines. When adding new code, read the relevant section here first.
>
> **Scope:** MVVM + Clean Architecture, SwiftUI navigation, async/await, error handling, dependency injection, testing, and code style.

---

## Table of Contents

1. [Project Architecture Overview](#1-project-architecture-overview)
2. [Folder Structure](#2-folder-structure)
3. [MVVM Rules](#3-mvvm-rules)
4. [Clean Architecture Layers](#4-clean-architecture-layers)
5. [Navigation Best Practices](#5-navigation-best-practices)
6. [Async/Await Best Practices](#6-asyncawait-best-practices)
7. [Error Handling](#7-error-handling)
8. [Dependency Injection](#8-dependency-injection)
9. [State Management](#9-state-management)
10. [Concurrency & Thread Safety](#10-concurrency--thread-safety)
11. [Naming Conventions](#11-naming-conventions)
12. [Code Style Rules](#12-code-style-rules)
13. [Testing Conventions](#13-testing-conventions)
14. [What Not To Do](#14-what-not-to-do)

---

## 1. Project Architecture Overview

This app uses **MVVM (Model-View-ViewModel)** layered on top of **Clean Architecture**. The two work together — MVVM governs how the UI layer is structured, and Clean Architecture governs how data and business logic flow through the rest of the app.

```
┌─────────────────────────────────────────────────────────┐
│  PRESENTATION LAYER (SwiftUI Views + ViewModels)        │
│  What the user sees and interacts with                  │
│  Views are dumb. ViewModels hold state + trigger logic. │
└───────────────────────┬─────────────────────────────────┘
                        │ calls
┌───────────────────────▼─────────────────────────────────┐
│  DOMAIN LAYER (Use Cases / Interactors)                 │
│  Pure Swift — no UIKit, no SwiftUI, no frameworks       │
│  Each use case does exactly one thing                   │
└───────────────────────┬─────────────────────────────────┘
                        │ calls
┌───────────────────────▼─────────────────────────────────┐
│  DATA LAYER (Repositories + Services)                   │
│  Talks to SQLite, OpenAI API, Supabase                  │
│  Returns domain models — never raw API/DB types         │
└─────────────────────────────────────────────────────────┘
```

**The direction of dependency is always downward — never upward.**

- A View knows about its ViewModel. A ViewModel never imports SwiftUI.
- A Use Case knows about Repositories. A Repository never imports a Use Case.
- The Domain layer never imports the Data layer.

---

## 2. Folder Structure

All Swift source lives in the `iOSApp/` folder at the repository root. The Xcode project (product name `MindMapper`) is created inside this folder.

```
iOSApp/
├── App/
│   ├── MindMapperApp.swift          ← @main entry point, DI container init
│   └── AppDelegate.swift           ← UNUserNotificationCenter delegate wiring
│
├── Core/
│   ├── Theme/                      ← Color+Theme, Font+Theme, Spacing, Components (ChatBubble, SessionMessageQuotaBar, …)
│   ├── Chat/                       ← ChatLimits (message/session caps + rolling context helpers)
│   ├── Notifications/              ← LocalNotificationService, NotificationTapRouter
│   ├── Database/                   ← DatabaseManager, migrations (v1, v2_session_pin, v3_reminders)
│   ├── Network/                    ← LLMClient, SupabaseClient wrapper
│   ├── VectorStore/                ← Cosine similarity over local embedding blobs
│   ├── RAG/                        ← MemoryExtractor, MemoryLinkPreserver, RAGRetriever, RAGAnswerService, MixedQueryService
│   ├── Navigation/                 ← AppRouter (NavigationStack path + sheets)
│   ├── Lifecycle/                  ← AppLifecycleListener (session close on background)
│   ├── Localization/               ← L10n typed accessors for Localizable.xcstrings
│   ├── DI/                         ← AppContainer (dependency injection)
│   └── Guards/                     ← InputSanitiser, ScopeGuard, RateLimiter, LocalMessageClassifier
│
├── Domain/
│   ├── Models/                     ← Pure Swift structs — Message, Memory, Session
│   ├── Repositories/               ← Protocols only — no implementation here
│   │   ├── SessionRepositoryProtocol.swift
│   │   ├── MessageRepositoryProtocol.swift
│   │   ├── MemoryRepositoryProtocol.swift
│   │   ├── ReminderRepositoryProtocol.swift
│   │   └── VectorRepositoryProtocol.swift
│   └── UseCases/
│       ├── SaveMemoryUseCase.swift
│       ├── QueryMemoryUseCase.swift
│       ├── MixedQueryUseCase.swift
│       ├── ClassifyIntentUseCase.swift
│       ├── CloseSessionUseCase.swift
│       ├── DeleteSessionUseCase.swift
│       ├── DeleteMemoryUseCase.swift
│       ├── DeleteAccountUseCase.swift
│       └── ReminderUseCases.swift
│
├── Data/
│   ├── Repositories/               ← Concrete implementations of Domain protocols
│   │   ├── SessionRepository.swift
│   │   ├── MessageRepository.swift
│   │   ├── MemoryRepository.swift
│   │   ├── ReminderRepository.swift
│   │   └── VectorRepository.swift
│   ├── Local/                      ← GRDB models, SQLite queries
│   └── Remote/                     ← Supabase/OpenAI API call implementations
│
├── Features/
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   └── OnboardingViewModel.swift
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   └── LoginViewModel.swift
│   ├── Sessions/
│   │   ├── ChatSessionListView.swift
│   │   ├── ChatSessionListViewModel.swift
│   │   ├── ChatSessionDisplayModel.swift
│   │   └── ChatSessionRowView.swift
│   ├── Chat/
│   │   ├── ChatView.swift
│   │   ├── ChatViewModel.swift
│   │   ├── ChatDependencies.swift
│   │   └── MessageDisplayModel.swift
│   ├── Memories/
│   │   ├── MemoryListView.swift
│   │   └── MemoryListViewModel.swift
│   ├── Reminders/
│   │   ├── RemindersListView.swift
│   │   ├── RemindersListViewModel.swift
│   │   ├── ReminderEditorView.swift
│   │   └── ReminderEditorViewModel.swift
│   └── Settings/
│       ├── SettingsView.swift
│       └── SettingsViewModel.swift
│
└── Resources/
    ├── Assets.xcassets
    ├── Localizable.xcstrings       ← English String Catalog (add locales later)
    └── Info.plist
```

**Rules:**
- One ViewModel per View file. Never share a ViewModel between two Views.
- Features are self-contained. A feature folder imports from `Domain` and `Core`, never from another feature folder.
- Domain models (`Domain/Models/`) are plain Swift structs. They never import GRDB, Supabase, or any framework.

---

## 3. MVVM Rules

### 3.1 — What Goes in a View

A View is responsible for **one thing only: rendering state**. It reads from its ViewModel and sends user actions back to it. Nothing else.

```swift
// ✅ Correct — View is thin; screen owns its ViewModel via @StateObject
// https://developer.apple.com/documentation/swiftui/stateobject
struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel

    /// Factory builds the VM; this view takes ownership (not ObservedObject).
    init(viewModel: ChatViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            ForEach(viewModel.messages) { message in
                ChatBubble(text: message.content, isUser: message.isUser, isWarning: message.isWarning)
            }
        }
        .task { await viewModel.loadSession() }
    }
}
```

```swift
// ❌ Wrong — business logic inside a View
struct ChatView: View {
    var body: some View {
        Button("Send") {
            // Directly calling an API from a view body — never do this
            let result = try? await LLMClient.shared.complete(...)
            messages.append(result)
        }
    }
}
```

**View must never:**
- Call an API or database directly
- Contain `if/else` business logic (only UI-branching is allowed, e.g. `if viewModel.isLoading`)
- Own domain model data — it reads from ViewModel's `@Published` properties
- Import `GRDB`, `Supabase`, or any data-layer framework

---

### 3.2 — What Goes in a ViewModel

A ViewModel holds **UI state** and **triggers use cases**. It translates domain results into display-ready properties.

```swift
// ✅ Correct ViewModel structure (matches shipped ChatViewModel)
@MainActor
final class ChatViewModel: ObservableObject {

    // MARK: — Published UI state
    @Published private(set) var messages: [MessageDisplayModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var inputText = ""
    @Published private(set) var lastAnswerSessionCount = 0

    // MARK: — Dependencies (bundled — never instantiated here)
    private let dependencies: ChatDependencies
    private let router: AppRouter
    private var sessionId: String
    private let userId: String

    init(
        sessionId: String,
        userId: String,
        dependencies: ChatDependencies,
        router: AppRouter
    ) {
        self.sessionId = sessionId
        self.userId = userId
        self.dependencies = dependencies
        self.router = router
    }

    // MARK: — User actions
    func sendMessage(_ rawInput: String? = nil) async {
        // rate → sanitise → session message cap (ChatLimits) → save user msg
        // → scope + classify (rolling tail) → STORE / QUERY / MIXED / CHAT
        // STORE/CHAT get ChatLimits.rollingContext; QUERY uses last-12 in RAGAnswerService
    }

    func loadSession() async { /* messageRepository.fetchAll */ }
    func closeSession() async { /* CloseSessionUseCase — also inactivity / background */ }
}
```

**Chat context limits (task 19c — shipped):** `Core/Chat/ChatLimits.swift` — `maxCharactersPerMessage` (= `InputSanitiser` **500**), `maxMessagesPerSession` (**40**), `rollingContextMessageCount` (**12**). Quota UI: `SessionMessageQuotaBar`. Do not hard-code `4` / `500` / session caps in Views. Rolling window = short-term coherence; RAG memories = long-term facts. See `docs/tasks/phase_1/19c-chat-rolling-transcript_iOS.md` and `docs/learning/chat-session-message-context.md`.

**ViewModel must never:**
- Import `SwiftUI` (it may import `Foundation` and `Combine` only)
- Create its own dependencies with `SomeThing()` — receive them via `init`
- Directly call `DatabaseManager` or `LLMClient` — it calls use cases only
- Contain SQL queries or API request construction

---

### 3.3 — Display Models vs Domain Models

Domain models (`Domain/Models/`) are pure data. ViewModels convert them to **display models** — structs optimised for the View to render directly, with pre-formatted strings and computed display properties.

```swift
// Domain model — pure, no formatting
struct Memory {
    let id: String
    let cleanText: String
    let createdAt: Date
}

// Display model — ready for the View to render, no logic needed in View
struct MemoryDisplayModel: Identifiable {
    let id: String
    let text: String
    let relativeDate: String    // "2 hours ago"
    let topicIcon: String       // "gift"
    let topicColor: Color       // Color.theme.accent
}

// ViewModel converts domain → display
extension ChatViewModel {
    private func toDisplay(_ memory: Memory) -> MemoryDisplayModel {
        MemoryDisplayModel(
            id: memory.id,
            text: memory.cleanText,
            relativeDate: memory.createdAt.formatted(.relative(presentation: .named)),
            topicIcon: iconFor(memory),
            topicColor: colorFor(memory)
        )
    }
}
```

---

## 4. Clean Architecture Layers

### 4.1 — Domain Models (Pure Swift Only)

```swift
// ✅ Domain/Models/Session.swift — zero framework imports
import Foundation

struct Session {
    let id: String
    let userId: String
    var title: String?
    var topicTag: TopicTag?
    var summary: String?
    let createdAt: Date
    var updatedAt: Date
}

enum TopicTag: String, CaseIterable {
    case wardrobe, plans, locations, people, ideas, gifts, work, health, other
}
```

---

### 4.2 — Repository Protocols (Domain Layer)

Repository protocols live in the **Domain** layer. They define *what* data operations exist — not *how* they are implemented.

```swift
// ✅ Domain/Repositories/MemoryRepositoryProtocol.swift
import Foundation

protocol MemoryRepositoryProtocol {
    func save(_ memory: Memory) async throws
    func fetchAll(for userId: String) async throws -> [Memory]
    func delete(_ memoryId: String) async throws
    func markSuperseded(_ memoryId: String) async throws
}
```

---

### 4.3 — Use Cases (Domain Layer)

Each use case does **exactly one thing**. It orchestrates across repositories and services to fulfill a single business operation.

```swift
// ✅ Domain/UseCases/SaveMemoryUseCase.swift
import Foundation

protocol SaveMemoryUseCaseProtocol {
    func execute(text: String, sessionId: String) async throws -> String
}

final class SaveMemoryUseCase: SaveMemoryUseCaseProtocol {

    private let memoryRepository: MemoryRepositoryProtocol
    private let vectorRepository: VectorRepositoryProtocol
    private let llmService: LLMServiceProtocol
    private let scopeGuard: ScopeGuardProtocol

    init(
        memoryRepository: MemoryRepositoryProtocol,
        vectorRepository: VectorRepositoryProtocol,
        llmService: LLMServiceProtocol,
        scopeGuard: ScopeGuardProtocol
    ) {
        self.memoryRepository = memoryRepository
        self.vectorRepository = vectorRepository
        self.llmService = llmService
        self.scopeGuard = scopeGuard
    }

    func execute(text: String, sessionId: String) async throws -> String {
        let extraction = try await llmService.extract(from: text)
        let embedding = try await llmService.embed(extraction.cleanText)
        let memory = Memory(
            id: UUID().uuidString,
            sessionId: sessionId,
            cleanText: extraction.cleanText,
            createdAt: Date()
        )
        try await memoryRepository.save(memory)
        try await vectorRepository.save(embedding, memoryId: memory.id)
        return try await llmService.acknowledge(original: text)
    }
}
```

**Use case rules:**
- One `execute()` method — no other public methods
- Protocol-backed — always define a `UseCaseProtocol` alongside the implementation
- No UI concepts — no `Color`, no `View`, no `@Published`
- Testable in isolation — every dependency is injected via `init`

---

### 4.4 — Repository Implementations (Data Layer)

The concrete implementation lives in the Data layer. It conforms to the Domain protocol.

```swift
// ✅ Data/Repositories/MemoryRepository.swift
import Foundation
import GRDB

final class MemoryRepository: MemoryRepositoryProtocol {
    private let database: DatabaseManager

    init(database: DatabaseManager) {
        self.database = database
    }

    func save(_ memory: Memory) async throws {
        let record = MemoryRecord(from: memory)    // local GRDB model
        try await database.dbQueue.write { db in
            try record.insert(db)
        }
    }

    func fetchAll(for userId: String) async throws -> [Memory] {
        try await database.dbQueue.read { db in
            try MemoryRecord
                .filter(Column("user_id") == userId)
                .fetchAll(db)
                .map(\.domainModel)            // convert GRDB → domain model
        }
    }

    func delete(_ memoryId: String) async throws {
        try await database.dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM memories WHERE id = ?",
                arguments: [memoryId]
            )
        }
    }

    func markSuperseded(_ memoryId: String) async throws {
        try await database.dbQueue.write { db in
            try db.execute(
                sql: "UPDATE memories SET is_superseded = 1 WHERE id = ?",
                arguments: [memoryId]
            )
        }
    }
}
```

---

## 5. Navigation Best Practices

### 5.1 — Use NavigationStack + NavigationPath (iOS 16+)

Never use `NavigationView` (deprecated). Use `NavigationStack` with a typed `NavigationPath` managed by a central `AppRouter`.

```swift
// Core/Navigation/AppRouter.swift
import SwiftUI

@MainActor
final class AppRouter: ObservableObject {
    @Published var path = NavigationPath()
    @Published var presentedSheet: Sheet?
    @Published var presentedAlert: AppAlert?

    enum Destination: Hashable {
        case chat(sessionId: String)
        case memoryList(sessionId: String)
        case settings
    }

    enum Sheet: Identifiable {
        case newSession
        case memoryDetail(memoryId: String)

        var id: String {
            switch self {
            case .newSession: return "newSession"
            case .memoryDetail(let id): return id
            }
        }
    }

    // MARK: — Navigation actions
    func navigate(to destination: Destination) {
        path.append(destination)
    }

    func navigateBack() {
        path.removeLast()
    }

    func navigateToRoot() {
        path.removeLast(path.count)
    }

    func present(_ sheet: Sheet) {
        presentedSheet = sheet
    }

    func dismissSheet() {
        presentedSheet = nil
    }
}
```

```swift
// App/MindMapperApp.swift
@main
struct MindMapperApp: App {
    @StateObject private var router = AppRouter()
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.path) {
                ChatSessionListView(viewModel: …)
                    .navigationDestination(for: AppRouter.Destination.self) { destination in
                        switch destination {
                        case .chat(let sessionId):
                            ChatView(sessionId: sessionId)
                        case .memoryList(let sessionId):
                            MemoryListView(sessionId: sessionId)
                        case .settings:
                            SettingsView()
                        }
                    }
            }
            .sheet(item: $router.presentedSheet) { sheet in
                switch sheet {
                case .newSession:
                    NewSessionView()
                case .memoryDetail(let id):
                    MemoryDetailView(memoryId: id)
                }
            }
            .environmentObject(router)
            .environmentObject(container)
        }
    }
}
```

---

### 5.2 — Navigation Rules

```swift
// ✅ Navigate from a ViewModel using the injected router
@MainActor
final class SessionListViewModel: ObservableObject {
    private let router: AppRouter

    func openChat(sessionId: String) {
        router.navigate(to: .chat(sessionId: sessionId))
    }
}

// ❌ Never navigate from inside a View body — it creates invisible dependencies
struct SessionListView: View {
    var body: some View {
        Button("Open") {
            // Don't do this — navigation logic belongs in the ViewModel
            NavigationLink(destination: ChatView(sessionId: "123")) {}
        }
    }
}
```

**Navigation rules:**
- `AppRouter` is the single source of navigation truth
- ViewModels navigate by calling `router.navigate(to:)` — they never import `NavigationPath` directly
- Views inject the router via `@EnvironmentObject` — they never create their own `NavigationLink` programmatically
- Deep links (e.g. from notification taps) go through `AppRouter` — never directly set view state

---

### 5.3 — Tab Bar Navigation

```swift
// Features/Root/RootView.swift
struct RootView: View {
    @State private var selectedTab: Tab = .chats

    enum Tab { case chats, memories, settings }

    var body: some View {
        TabView(selection: $selectedTab) {
            ChatSessionListView(viewModel: …)
                .tabItem {
                    Label("Chats", systemImage: "message.circle")
                }
                .tag(Tab.chats)

            MemoryListView()
                .tabItem {
                    Label("Memories", systemImage: "lightbulb")
                }
                .tag(Tab.memories)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(Tab.settings)
        }
        .tint(Color.theme.accent)
    }
}
```

---

## 6. Async/Await Best Practices

### 6.1 — Task Lifecycle Management

Always manage the lifetime of a `Task` when it is tied to a View's lifecycle.

**Hard rule:** never start async work with `.onAppear { Task { await … } }`. SwiftUI does not cancel that unstructured `Task` when the view disappears, and `onAppear` can fire more than once (e.g. certain navigation / tab scenarios). Use `.task` / `.task(id:)` instead.

```swift
// ✅ Correct — task is cancelled when view disappears
struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel

    var body: some View {
        ScrollView { /* content */ }
            .task {
                // .task modifier automatically cancels when view disappears
                await viewModel.loadSession()
            }
    }
}

// ✅ Correct — .task(id:) cancels the previous task and re-runs when the id changes
struct ProfileView: View {
    let userID: String
    @StateObject private var viewModel: ProfileViewModel

    var body: some View {
        content
            .task(id: userID) {
                await viewModel.loadUser(userID)
            }
    }
}

// ✅ Correct — root list stays mounted under NavigationStack; reload when path returns to empty
struct ChatSessionListView: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel: ChatSessionListViewModel

    var body: some View {
        listContent
            .task(id: router.path.count) {
                guard router.path.isEmpty else { return }
                await viewModel.loadSessions()
            }
    }
}

// ❌ Wrong — Task created in onAppear is never cancelled
struct ChatView: View {
    var body: some View {
        ScrollView { /* content */ }
            .onAppear {
                Task {
                    // This task outlives the view if the user navigates away
                    await viewModel.loadSession()
                }
            }
    }
}
```

| Pattern | When to use |
|---|---|
| `.task { }` | Load once when the view appears; auto-cancel on disappear |
| `.task(id:) { }` | Same, plus re-run when `id` changes (cancels the previous task) |
| `.onAppear { }` | Sync UI only (animation, focus) — **never** spawn `Task { await … }` |
| `Task { }` in a button / gesture | User-driven actions (send, delete, retry) — OK |

---

### 6.2 — Structured Concurrency for Parallel Work

When two independent async operations can run at the same time, use `async let` — never sequential `await`.

```swift
// ✅ Correct — both run in parallel, total time = max(a, b)
func handleMixedQuery(question: String) async throws -> String {
    async let memoryAnswer = queryMemoryUseCase.execute(question: question)
    async let generalAnswer = llmService.generalKnowledge(question: question)

    let (memory, general) = try await (memoryAnswer, generalAnswer)
    return try await mergeAnswers(memory: memory, general: general)
}

// ❌ Wrong — sequential, total time = a + b
func handleMixedQuery(question: String) async throws -> String {
    let memoryAnswer = try await queryMemoryUseCase.execute(question: question)
    let generalAnswer = try await llmService.generalKnowledge(question: question)
    return try await mergeAnswers(memory: memoryAnswer, general: generalAnswer)
}
```

---

### 6.3 — TaskGroup for Dynamic Parallelism

When you have a dynamic number of items to process in parallel (e.g. embedding multiple summary bullets at session close):

```swift
// ✅ Correct — embed all bullets in parallel with TaskGroup
func embedSummaryBullets(_ bullets: [String]) async throws -> [(String, [Float])] {
    try await withThrowingTaskGroup(of: (String, [Float]).self) { group in
        for bullet in bullets {
            group.addTask {
                let embedding = try await self.llmService.embed(bullet)
                return (bullet, embedding)
            }
        }
        var results: [(String, [Float])] = []
        for try await result in group {
            results.append(result)
        }
        return results
    }
}
```

---

### 6.4 — Async Sequences for Streaming

LLM responses stream token-by-token. Use `AsyncStream` or `AsyncThrowingStream` to bridge callback-based streaming APIs into the structured concurrency world.

```swift
// LLMService — returns an async stream of tokens
func stream(prompt: String) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
        Task {
            do {
                // Each token from OpenAI's streaming API
                for try await token in openAIStreamingCall(prompt: prompt) {
                    continuation.yield(token)
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}

// ViewModel consumes the stream — view updates incrementally
func sendMessage() async {
    var accumulated = ""
    do {
        for try await token in llmService.stream(prompt: builtPrompt) {
            accumulated += token
            // Update @Published property — triggers view re-render per token
            streamingReply = accumulated
        }
        finaliseReply(accumulated)
    } catch {
        errorMessage = "Stream interrupted."
    }
}
```

---

### 6.5 — Defer for Cleanup

Use `defer` to guarantee `isLoading = false` runs even if the async function throws.

```swift
// ✅ Correct — isLoading always resets, even on error
func sendMessage() async {
    isLoading = true
    defer { isLoading = false }     // ← guaranteed to run

    do {
        let result = try await someUseCase.execute()
        applyResult(result)
    } catch {
        errorMessage = error.localizedDescription
    }
}

// ❌ Wrong — isLoading stays true forever if an error is thrown
func sendMessage() async {
    isLoading = true
    let result = try? await someUseCase.execute()
    isLoading = false               // ← never reached on throw
}
```

---

### 6.6 — Cooperative Cancellation

Long-running operations should check for cancellation at natural checkpoints.

```swift
func embedAllMemories(memories: [Memory]) async throws {
    for memory in memories {
        // Check before each expensive operation — allows the task to be cancelled cleanly
        try Task.checkCancellation()
        let embedding = try await llmService.embed(memory.cleanText)
        try await vectorRepository.save(embedding, memoryId: memory.id)
    }
}
```

---

### 6.7 — LLM Model Fallback (Primary → Fallback)

All LLM calls go through `LLMClient` using a **tier** (`.nano`, `.mini`, `.full`, `.embed`). Each tier maps to a **primary** and **fallback** model in `LLMModelConfig`. Use cases never pass raw model name strings.

`LLMClient` is **`nonisolated`** (same idea as `DatabaseManager` / `RateLimiter`) so `nonisolated` use cases can call it without MainActor hops that hang mid-pipeline. Do not put network I/O on MainActor.

**When to retry:** Primary fails with rate limit (HTTP 429) or quota exceeded (402/403, `resource_exhausted`, `insufficient_quota`) → retry **once** with fallback. If both fail → throw `AppError.llmCallFailed`.

```swift
// ✅ Correct — use tier; fallback is automatic via Edge Function + LLMClient
let intent = try await LLMClient.shared.complete(
    tier: .nano,
    messages: [LLMMessage(role: "user", content: prompt)],
    maxTokens: 5,
    temperature: 0
)

// ❌ Wrong — raw model string in a use case; no fallback mapping
let intent = try await LLMClient.shared.complete(
    model: "gemini-2.0-flash",
    messages: [...]
)
```

**Config lives in one place** (`LLMModelConfig`) — swap Gemini dev models for OpenAI prod models without touching use cases:

| Tier | Dev primary | Dev fallback |
|---|---|---|
| `.nano` | `gemini-3.5-flash-lite` (500 RPD) | `gemini-2.5-flash-lite` (20 RPD) |
| `.mini` | `gemini-3.5-flash-lite` (500 RPD) | `gemini-3.6-flash` (20 RPD) |
| `.full` | `gemini-3.6-flash` (20 RPD) | `gemini-2.5-flash` (20 RPD) |
| `.embed` | `gemini-embedding-001` | `gemini-embedding-001` |

> Model IDs live only in `LLMModelConfig`. Use **exact** free-tier quota model names from AI Studio — avoid `*-latest` aliases and `gemini-2.0-flash*` (`limit: 0`).

Log which model succeeded (primary vs fallback) in debug builds for troubleshooting.

---

## 7. Error Handling

### 7.1 — Define Typed App Errors

Never surface raw `Error` or `URLError` strings to the user. Define a typed error hierarchy for each layer.

```swift
// Domain/Models/AppError.swift
enum AppError: LocalizedError {

    // Input validation
    case inputTooLong
    case inputOutOfScope(reason: String)
    case rateLimitExceeded(retryAfter: TimeInterval)

    // LLM errors
    case llmCallFailed(underlying: Error)
    case llmResponseInvalid
    case llmContextWindowExceeded

    // Data errors
    case saveFailed(underlying: Error)
    case notFound(entityType: String, id: String)
    case embeddingFailed

    // Auth errors
    case notAuthenticated
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .inputTooLong:
            return "Please keep messages under 500 characters."
        case .inputOutOfScope(let reason):
            return reason
        case .rateLimitExceeded(let seconds):
            return "Please wait \(Int(seconds)) seconds before sending another message."
        case .llmCallFailed:
            return "Couldn't reach the AI. Check your connection and try again."
        case .notAuthenticated:
            return "Please sign in to continue."
        case .notFound(let type, _):
            return "Could not find \(type). It may have been deleted."
        default:
            return "Something went wrong. Please try again."
        }
    }

    // Whether to show a retry button in the UI
    var isRetryable: Bool {
        switch self {
        case .llmCallFailed, .saveFailed, .embeddingFailed: return true
        default: return false
        }
    }
}
```

---

### 7.2 — Error Handling in ViewModels

```swift
// ✅ Correct — all errors caught at ViewModel boundary, never crash
func sendMessage() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
        let result = try await saveMemoryUseCase.execute(text: inputText, sessionId: sessionId)
        appendMessage(result)
    } catch let error as AppError {
        errorMessage = error.errorDescription
        canRetry = error.isRetryable
    } catch {
        // Unexpected error — log it, show generic message
        errorMessage = AppError.llmCallFailed(underlying: error).errorDescription
    }
}
```

---

### 7.3 — Result Type for Non-Throwing Async (Optional Pattern)

For operations where partial success matters (e.g. batch processing), use `Result` instead of `throws`:

```swift
func batchEmbed(texts: [String]) async -> [Result<[Float], AppError>] {
    await withTaskGroup(of: Result<[Float], AppError>.self) { group in
        for text in texts {
            group.addTask {
                do {
                    let embedding = try await self.llmService.embed(text)
                    return .success(embedding)
                } catch {
                    return .failure(.embeddingFailed)
                }
            }
        }
        var results: [Result<[Float], AppError>] = []
        for await result in group { results.append(result) }
        return results
    }
}
```

---

## 8. Dependency Injection

### 8.1 — AppContainer (Single Composition Root)

All dependencies are wired once in a single `AppContainer`. Nothing inside the app calls `SomeClass()` directly — it gets its dependencies from the container.

```swift
// Core/DI/AppContainer.swift
@MainActor
final class AppContainer: ObservableObject {

    // MARK: — Infrastructure (created once, shared)
    /// Injected from `MindMapperApp` only after `DatabaseManager.shared` succeeds (no `try!`).
    let database: DatabaseManager
    lazy var supabaseClient = SupabaseClientWrapper()

    init(database: DatabaseManager) {
        self.database = database
    }

    // MARK: — Repositories
    lazy var sessionRepository: SessionRepositoryProtocol = SessionRepository(database: database)
    lazy var memoryRepository: MemoryRepositoryProtocol = MemoryRepository(database: database)
    lazy var vectorRepository: VectorRepositoryProtocol = VectorRepository(database: database)

    // MARK: — Services
    lazy var llmService: LLMServiceProtocol = LLMService(client: supabaseClient)
    lazy var authManager: AuthManagerProtocol = AuthManager(client: supabaseClient)

    // MARK: — Guards
    lazy var scopeGuard: ScopeGuardProtocol = ScopeGuard(llmService: llmService)
    lazy var rateLimiter: RateLimiterProtocol = RateLimiter()

    // MARK: — Use Cases / RAG (created fresh per use — cheap structs/finals)
    func makeSaveMemoryUseCase() -> SaveMemoryUseCaseProtocol {
        SaveMemoryUseCase(
            memoryRepository: memoryRepository,
            vectorRepository: vectorRepository,
            memoryExtractor: MemoryExtractor(llmClient: LLMClient.shared),
            llmClient: LLMClient.shared
        )
    }

    /// Stage 1–3 hybrid retrieval + temporal helpers. Inject into `RAGAnswerService`.
    func makeRAGRetriever() -> RAGRetriever {
        RAGRetriever(
            llmClient: LLMClient.shared,
            vectorStore: VectorStore(database: database),
            database: database
        )
    }

    func makeRAGAnswerService() -> RAGAnswerServiceProtocol {
        RAGAnswerService(
            retriever: makeRAGRetriever(),
            llmClient: LLMClient.shared,
            database: database
        )
    }

    func makeQueryMemoryUseCase() -> QueryMemoryUseCaseProtocol {
        QueryMemoryUseCase(answerService: makeRAGAnswerService())
    }

    func makeMixedQueryUseCase() -> MixedQueryUseCaseProtocol {
        MixedQueryUseCase(
            service: MixedQueryService(
                ragAnswerService: makeRAGAnswerService(),
                llmClient: LLMClient.shared
            )
        )
    }

    func makeCloseSessionUseCase() -> CloseSessionUseCaseProtocol {
        CloseSessionUseCase(
            messageRepository: messageRepository,
            sessionRepository: sessionRepository,
            memoryRepository: memoryRepository,
            vectorRepository: vectorRepository,
            llmClient: LLMClient.shared
        )
    }

    func makeChatViewModel(sessionId: String, router: AppRouter) -> ChatViewModel? {
        guard let userId = authManager.currentUser?.id else { return nil }
        return ChatViewModel(
            sessionId: sessionId,
            userId: userId,
            dependencies: makeChatDependencies(),
            router: router
        )
    }

    private func makeChatDependencies() -> ChatDependencies {
        ChatDependencies(
            rateLimiter: rateLimiter,
            scopeGuard: scopeGuard,
            classifyIntentUseCase: makeClassifyIntentUseCase(),
            saveMemoryUseCase: makeSaveMemoryUseCase(),
            queryMemoryUseCase: makeQueryMemoryUseCase(),
            mixedQueryUseCase: makeMixedQueryUseCase(),
            closeSessionUseCase: makeCloseSessionUseCase(),
            llmClient: LLMClient.shared,
            messageRepository: messageRepository,
            sessionRepository: sessionRepository,
            notificationService: localNotificationService
        )
    }

    // Also: makeRemindersListViewModel / makeReminderEditorViewModel / reminder use cases /
    // makeChatSessionListViewModel / makeDeleteSessionUseCase / makeSettingsViewModel — see AppContainer.swift
}
```

```swift
// Injecting into a View via @EnvironmentObject
struct ChatView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var router: AppRouter

    let sessionId: String

    // ViewModel is created using the container — never with ChatViewModel()
    @StateObject private var viewModel: ChatViewModel

    init(sessionId: String) {
        self.sessionId = sessionId
        // Can't use @EnvironmentObject in init — use the factory pattern below
        self._viewModel = StateObject(wrappedValue: ChatViewModel.placeholder)
    }

    var body: some View {
        ChatContentView(viewModel: viewModel)
            .onAppear {
                // Wire up the real ViewModel on appear using the container
                viewModel.configure(container.makeChatViewModel(
                    sessionId: sessionId, router: router))
            }
    }
}
```

> **Simpler alternative:** Pass the ViewModel directly in the `navigationDestination` closure where you have access to the environment, and use `@StateObject` with the wrappedValue approach:
>
> ```swift
> .navigationDestination(for: AppRouter.Destination.self) { destination in
>     switch destination {
>     case .chat(let sessionId):
>         ChatView(
>             viewModel: container.makeChatViewModel(sessionId: sessionId, router: router)
>         )
>     }
> }
> ```

---

## 9. State Management

### 9.1 — State Ownership Rules

| State type | Where it lives | Example |
|---|---|---|
| Local UI state | `@State` in View | Input text, sheet presented, keyboard focus |
| Shared UI state | `@StateObject` (owner) / `@ObservedObject` (child observer) | Screen ViewModel |
| App-wide state | `@EnvironmentObject` | AppRouter, AppContainer, AuthManager |
| Persistent state | Database / UserDefaults | Messages, memories, user preferences |
| Server state | Repository + ViewModel | Session list, memory list |

**ViewModel ownership (Apple `StateObject`):** the screen that is the single source of truth uses `@StateObject`. With DI, take ownership in `init` via `_viewModel = StateObject(wrappedValue:)` — even though the factory created the instance. Use `@ObservedObject` only when a **parent** already owns the object and a child merely observes it. When `sessionId` (or similar identity) changes, apply `.id(sessionId)` so SwiftUI recreates the `StateObject`.

```swift
struct ChatView: View {
    // ✅ Local UI state only — doesn't leave the view
    @State private var isKeyboardVisible = false
    @FocusState private var inputFocused: Bool

    // ✅ ViewModel — this screen owns the data state
    @StateObject private var viewModel: ChatViewModel

    // ✅ App-wide — injected from environment
    @EnvironmentObject private var router: AppRouter

    init(viewModel: ChatViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
}
```

---

### 9.2 — Avoid Prop Drilling

If a piece of state needs to be accessed more than two views deep, use `@EnvironmentObject` rather than passing it through every intermediate view.

```swift
// ❌ Prop drilling — passing router through views that don't need it
ChatSessionListView(viewModel: …)
    → ChatSessionRowView(…)
        → SessionMenuView(router: router)    // only this view needs it

// ✅ EnvironmentObject — inject once, access anywhere
ChatSessionListView(viewModel: …)
    .environmentObject(router)
// Then in SessionMenuView:
@EnvironmentObject private var router: AppRouter
```

---

## 10. Concurrency & Thread Safety

### 10.1 — @MainActor on ViewModels

All ViewModels must be marked `@MainActor`. This guarantees all `@Published` property mutations happen on the main thread, preventing the "Publishing changes from background threads is not allowed" crash.

```swift
@MainActor                              // ← required on every ViewModel
final class ChatViewModel: ObservableObject {
    @Published var messages: [MessageDisplayModel] = []
    @Published var isLoading = false
}
```

### 10.2 — Isolating Background Work

Heavy computation (cosine similarity across thousands of vectors) should move off the main actor:

```swift
// VectorRepository — search runs in a background context
func search(query: [Float], topK: Int) async throws -> [VectorSearchResult] {
    // GRDB DatabaseQueue.read already dispatches off the main thread
    let rows = try await database.dbQueue.read { db in
        try VectorRecord.fetchAll(db)
    }
    // CPU-heavy work — move to background explicitly
    return await Task.detached(priority: .userInitiated) {
        self.computeSimilarity(query: query, candidates: rows, topK: topK)
    }.value
}
```

### 10.3 — Never Call `DispatchQueue.main.async` in New Code

With `@MainActor`, you do not need `DispatchQueue.main.async`. If you find yourself writing it, the `@MainActor` annotation is missing somewhere.

```swift
// ❌ Old pattern — do not use
DispatchQueue.main.async {
    self.isLoading = false
}

// ✅ New pattern — @MainActor on ViewModel guarantees main thread
isLoading = false
```

---

## 11. Naming Conventions

| Thing | Convention | Example |
|---|---|---|
| Protocol | `PascalCase` + suffix `Protocol` | `MemoryRepositoryProtocol` |
| Use Case | `VerbNounUseCase` | `SaveMemoryUseCase`, `DeleteSessionUseCase` |
| ViewModel | `FeatureNameViewModel` | `ChatViewModel`, `ChatSessionListViewModel` |
| View | `FeatureNameView` | `ChatView`, `ChatSessionListView` |
| Repository (protocol) | `NounRepositoryProtocol` | `MemoryRepositoryProtocol` |
| Repository (impl) | `NounRepository` | `MemoryRepository` |
| Display model | `NounDisplayModel` | `MessageDisplayModel`, `ChatSessionDisplayModel` |
| Domain model | Plain noun | `Memory`, `Session`, `Message` |
| Async function | Verb-first, no "async" suffix | `func loadMessages()`, `func sendMessage()` |
| Bool property | `is`, `has`, `can`, `should` prefix | `isLoading`, `hasError`, `canRetry` |
| Enum case | `lowerCamelCase` | `.inScope`, `.outOfScope`, `.store`, `.query` |

---

## 12. Code Style Rules

### 12.1 — File Layout (every Swift file follows this order)

```swift
import Foundation         // 1. System imports first
import SwiftUI            // 2. Apple framework imports
import GRDB               // 3. Third-party imports (alphabetical)

// MARK: — Main declaration
final class SomeViewModel: ObservableObject {

    // MARK: — Published properties
    @Published var messages: [MessageDisplayModel] = []

    // MARK: — Private properties
    private let useCase: SomeUseCaseProtocol

    // MARK: — Init
    init(useCase: SomeUseCaseProtocol) {
        self.useCase = useCase
    }

    // MARK: — Public methods
    func sendMessage() async { }

    // MARK: — Private methods
    private func buildPrompt() -> String { "" }
}

// MARK: — Extensions (separate logical groupings)
extension SomeViewModel {
    func additionalBehaviour() { }
}
```

### 12.2 — Function Length

- A function longer than **30 lines** is doing too much. Extract to private helpers.
- A file longer than **300 lines** is doing too much. Split into extensions or separate types.

### 12.3 — Access Control

Default to `private`. Only expose what other types genuinely need.

```swift
// ✅ Restrictive by default
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [MessageDisplayModel] = [] // read publicly, write privately
    private let useCase: SaveMemoryUseCaseProtocol
    private func buildPrompt() -> String { "" }
    func sendMessage() async { }   // public — the view calls this
}
```

### 12.4 — No Force Unwrapping

```swift
// ❌ Never
let url = URL(string: "https://api.openai.com")!
static let shared = try! DatabaseManager()

// ✅ Always — guard / throws for recoverable typed errors
guard let url = URL(string: "https://api.openai.com") else {
    throw AppError.llmCallFailed(underlying: URLError(.badURL))
}

// ✅ Always — do/catch + AppLogger for bootstrap / infrastructure failures
static let shared: DatabaseManager? = {
    do {
        return try DatabaseManager()
    } catch {
        AppLogger.error("Failed to open or migrate memory.db", error: error)
        return nil
    }
}()
```

Do not use `try!`, `as!`, or implicitly unwrapped optionals to “keep bootstrap simple.” Log via `AppLogger` (`NSLog` in development; wire to Sentry before release — see `docs/pre-release-checklist.md`).

### 12.5 — Trailing Closures and Clarity

Trailing closure syntax is good for single-closure calls. Avoid it when the context is ambiguous.

```swift
// ✅ Clear with trailing closure
viewModel.messages
    .filter { $0.isUser }
    .map { $0.content }

// ❌ Ambiguous with trailing closure
performAction { result in
    handle(result)
} completion: {       // ← two trailing closures — use explicit labels instead
    finish()
}
```

---

## 13. Testing Conventions

### 13.1 — Unit Test Structure (AAA Pattern)

Every unit test follows **Arrange / Act / Assert**:

```swift
final class SaveMemoryUseCaseTests: XCTestCase {

    func test_execute_savesCleanTextToRepository() async throws {
        // Arrange
        let mockMemoryRepo = MockMemoryRepository()
        let mockVectorRepo = MockVectorRepository()
        let mockLLMService = MockLLMService()
        mockLLMService.extractResult = ExtractionResult(
            cleanText: "Passport is in the top drawer",
            entities: [],
            supersedesHint: nil
        )
        let sut = SaveMemoryUseCase(
            memoryRepository: mockMemoryRepo,
            vectorRepository: mockVectorRepo,
            llmService: mockLLMService,
            scopeGuard: MockScopeGuard(result: .inScope)
        )

        // Act
        _ = try await sut.execute(text: "My passport is in the top drawer", sessionId: "s1")

        // Assert
        XCTAssertEqual(mockMemoryRepo.savedMemories.count, 1)
        XCTAssertEqual(mockMemoryRepo.savedMemories.first?.cleanText,
                       "Passport is in the top drawer")
    }
}
```

### 13.2 — What to Test

| Layer | Test target | How |
|---|---|---|
| Use Cases | Business logic, orchestration | Unit tests with mock repositories |
| Repositories | SQL queries, data mapping | Integration tests with in-memory SQLite |
| ViewModels | State transitions, error handling | Unit tests with mock use cases |
| Guards | Scope/sanitise logic | Unit tests — pure functions |
| Views | Snapshot, no logic | SwiftUI Previews are sufficient |

### 13.3 — Mocks via Protocols

Because every dependency is protocol-backed, mocking is trivial:

```swift
final class MockMemoryRepository: MemoryRepositoryProtocol {
    var savedMemories: [Memory] = []
    var shouldThrow = false

    func save(_ memory: Memory) async throws {
        if shouldThrow { throw AppError.saveFailed(underlying: URLError(.unknown)) }
        savedMemories.append(memory)
    }

    func fetchAll(for userId: String) async throws -> [Memory] { savedMemories }
    func delete(_ id: String) async throws { savedMemories.removeAll { $0.id == id } }
    func markSuperseded(_ id: String) async throws { }
}
```

---

## 14. What Not To Do

These are the most common mistakes. Treat each as a hard rule.

| ❌ Never do this | ✅ Do this instead |
|---|---|
| Call `LLMClient.shared` from a View | Call a use case from the ViewModel |
| Pass raw model name strings (`"gemini-2.0-flash"`) in use cases | Use `LLMClient.complete(tier: .nano)` — fallback is automatic |
| Call `DatabaseManager.shared` from a ViewModel | Call a repository method |
| Use `@ObservedObject` for a ViewModel the **screen owns** | Use `@StateObject` (Apple: single source of truth) |
| Use `@StateObject` for a ViewModel a **parent already owns** and only shares | Use `@ObservedObject` or `@EnvironmentObject` |
| Hardcode user-visible English in Views / `AppError` | Add a key to `Localizable.xcstrings` + `L10n.*` |
| Hardcode `Color(hex: "#3478F6")` in a View | Use `Color.theme.accent` |
| Use `DispatchQueue.main.async` | Use `@MainActor` |
| Use `NavigationView` | Use `NavigationStack` |
| Force unwrap with `!` / `try!` / `as!` | Use `guard let`, `do/catch`, and `AppLogger` |
| Write business logic in a View's `body` | Move it to a ViewModel method |
| Share a ViewModel between two Views | Give each View its own ViewModel |
| Create a dependency with `SomeService()` inside a ViewModel | Inject via `init` |
| Catch `Error` and show `error.localizedDescription` raw | Map to typed `AppError` first |
| Mark a ViewModel `class` without `@MainActor` | Always add `@MainActor` |
| Use `await` for two independent operations sequentially | Use `async let` for parallelism |
| Put GRDB or Supabase imports in a domain model | Keep domain models framework-free |
| Navigate with `NavigationLink` programmatically inside a View | Use `AppRouter.navigate(to:)` from ViewModel |
| `.onAppear { Task { await viewModel.load… } }` | `.task { await … }` or `.task(id:) { await … }` |

---

## Quick Reference Card

```
User action
    │
    ▼
View (SwiftUI)
    │ calls viewModel.someAction()
    ▼
ViewModel (@MainActor, @Published state)
    │ calls useCase.execute()
    ▼
Use Case (pure Swift, protocol-backed)
    │ calls repository.method()
    ▼
Repository (conforms to protocol)
    │ reads/writes
    ▼
Database (GRDB/SQLite) or API (LLMClient/Supabase)
```

**Files to touch when adding a new feature:**
1. `Domain/Models/` — add or update the domain model
2. `Domain/Repositories/` — add the protocol method if needed
3. `Data/Repositories/` — implement the protocol method
4. `Domain/UseCases/` — write the use case
5. `Features/FeatureName/FeatureNameViewModel.swift` — call the use case
6. `Features/FeatureName/FeatureNameView.swift` — render the state
7. `Core/DI/AppContainer.swift` — wire the new dependencies
