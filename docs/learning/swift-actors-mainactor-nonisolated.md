# Actors, MainActor, and `nonisolated` (Swift Concurrency)

A short guide for MindMapper: why the project uses `nonisolated` on domain models and the database layer, and how that relates to Apple’s concurrency defaults.

**Related code:** `Domain/Models/*.swift`, `Core/Database/DatabaseManager.swift`, `Data/Local/GRDBRecords.swift`, `Core/Logging/AppLogger.swift`  
**Related setting:** `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` in the Xcode target

---

## The problem these features solve

SwiftUI / UIKit UI **must** update on the **main thread**.  
SQLite (GRDB), networking, and heavy work often run on **background** threads.

If two threads touch the same mutable state at once → data races and subtle bugs.  
**Actors** are Swift’s way to serialize access to that state.

---

## `actor` — your own isolation domain

An `actor` is a type that owns mutable state and allows only **one task at a time** to touch it.

```swift
actor Counter {
    private var value = 0

    func increment() {
        value += 1
    }

    func current() -> Int {
        value
    }
}

let counter = Counter()
await counter.increment()          // must await — may hop to the actor
let n = await counter.current()
```

**Mental model:** like a private serial queue baked into the type. Callers use `await` to enter.

Use a custom `actor` when **you** own shared mutable state that isn’t UI (caches, rate limiters, in-memory stores).

MindMapper today prefers **GRDB’s `DatabaseQueue`** (thread-safe by design) plus `Sendable` value types, rather than wrapping everything in a custom actor — but the same idea applies.

---

## `MainActor` — the UI’s actor

`MainActor` is the system actor tied to the **main thread**.

```swift
@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [String] = []

    func append(_ text: String) {
        messages.append(text)   // safe: always on main
    }
}

@MainActor
func updateUI() {
    // Also always on main
}
```

**Rules of thumb:**

| Put on `MainActor` | Keep off `MainActor` |
|---|---|
| ViewModels (`ObservableObject`) | Domain models (plain data) |
| SwiftUI views / UI updates | GRDB records / DB I/O |
| Navigation routers that drive UI | Embedding math, file codecs |

AGENT.md already says ViewModels are `@MainActor` — that matches this.

---

## Project default: everything is MainActor unless opted out

New Xcode iOS app templates often set:

```text
SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor
```

**Meaning:** unmarked types and functions are treated as `@MainActor` by default.

That is **Apple’s default for new apps**, not a hard OS requirement. You can change it; MindMapper currently keeps it.

So without an opt-out:

```swift
struct User { ... }           // implicitly MainActor-isolated
final class DatabaseManager { ... }  // same
```

Those types then **cannot** freely cross into GRDB’s `dbQueue.read` / `write` closures (background, `Sendable`-oriented). The compiler complains about main-actor-isolated conformances vs `Sendable`.

---

## `nonisolated` — opt out of the actor

`nonisolated` means: *this declaration is **not** isolated to the enclosing (or default) actor.*

```swift
// Domain model — plain data, safe on any thread
nonisolated struct User: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var email: String
}

// DB layer — must run with GRDB off the main thread
nonisolated final class DatabaseManager: Sendable {
    let dbQueue: DatabaseQueue
    // ...
}

nonisolated enum AppLogger {
    nonisolated static func error(_ message: String, error: Error? = nil) {
        NSLog("[MindMapper][ERROR] %@", message)
    }
}
```

**When to use it in this project:**

1. **Domain models** — pure values; no UI; passed into repositories and DB code  
2. **GRDB records / `DatabaseManager`** — used from DB queues  
3. **`AppLogger`** — must be callable from nonisolated bootstrap (e.g. opening the DB)  
4. Methods on a `@MainActor` type that are **pure** and don’t touch main-actor state (rarer)

```swift
@MainActor
final class SettingsViewModel: ObservableObject {
    nonisolated static func formatVersion(_ v: String) -> String {
        "v\(v)"   // no UI state — OK to be nonisolated
    }
}
```

---

## `Sendable` — safe to cross isolation boundaries

A `Sendable` type can be passed between actors / concurrency domains without data races.

- Structs of `Sendable` stored properties → usually fine (`String`, `Int`, `Date`, `Data`, …)  
- Classes → harder; often need careful design or `@unchecked Sendable` (use sparingly)

MindMapper domain models are `nonisolated` **and** `Sendable` so they can move:

```text
MainActor (ViewModel)  ←→  GRDB DatabaseQueue (background)
```

---

## How the three fit together

```text
┌─────────────────────────────────────────────────────────┐
│  MainActor (default for this target)                    │
│  Views, ViewModels, most unmarked app code              │
└──────────────────────────┬──────────────────────────────┘
                           │ pass Sendable values
                           ▼
┌─────────────────────────────────────────────────────────┐
│  nonisolated types                                      │
│  User, Session, Memory, DatabaseManager, AppLogger, …   │
└──────────────────────────┬──────────────────────────────┘
                           │ used by
                           ▼
┌─────────────────────────────────────────────────────────┐
│  Other isolation (GRDB queue / custom actor / Task)     │
│  dbQueue.read { … } / write { … }                       │
└─────────────────────────────────────────────────────────┘
```

| Keyword | Role |
|---|---|
| `actor` | Define a **new** isolation domain you own |
| `@MainActor` / `MainActor` | Use the **UI / main-thread** isolation domain |
| `nonisolated` | **Leave** an actor (or the default MainActor) for that declaration |
| `Sendable` | Value is safe to **carry across** domains |

---

## Quick decision guide

1. **Touches `@Published` / SwiftUI / UIKit?** → `@MainActor` (ViewModel / view).  
2. **Plain data struct for Domain?** → `nonisolated` + `Sendable`.  
3. **Talks to GRDB / files / crypto off UI?** → `nonisolated` types + call from `async` / DB queue.  
4. **Shared mutable state that isn’t UI?** → consider a custom `actor` (or a proven thread-safe type like `DatabaseQueue`).  
5. **Compiler says “main actor-isolated … Sendable”?** → you probably need `nonisolated` on that model/record (given this project’s default isolation).

---

## What not to do

- Don’t sprinkle `@MainActor` on Domain models “to silence warnings” — that pushes DB work onto the main thread or creates isolation conflicts.  
- Don’t use `nonisolated` on a ViewModel method that mutates `@Published` state — that’s a bug.  
- Don’t treat `nonisolated` as “runs in background by itself” — it only means **not actor-isolated**; you still choose *where* the work runs (`Task`, GRDB queue, etc.).

---

## See also

- [Swift.org — Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)  
- Project rules: `.cursor/rules/ios-swift-conventions.mdc` (ViewModels `@MainActor`)  
- `iOSApp/AGENT.md` §6 / §10 (async & concurrency)
