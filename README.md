# Mind Mapper — Memory App

A personal AI memory assistant for iOS. You talk to it naturally, and it remembers everything across conversations.

## Repository Layout

```
Mind_Mapper/
├── README.md           ← you are here
├── iOSApp/             ← Xcode project and all Swift source code
│   └── AGENT.md        ← architecture rules (read before writing Swift)
└── docs/               ← planning docs and implementation tasks
    ├── planning/
    ├── design/
    └── tasks/
        └── phase_1/    ← all build tasks (setup, iOS, backend)
```

## Start Here

1. Read [docs/planning/execution-plan.md](docs/planning/execution-plan.md) for the full project overview and phase order.
2. Read [iOSApp/AGENT.md](iOSApp/AGENT.md) before writing any Swift code.
3. Work through tasks in order, starting with [docs/tasks/phase_1/01-install-xcode_setup.md](docs/tasks/phase_1/01-install-xcode_setup.md).

## Reference Docs

| Document | Purpose |
|---|---|
| [iOSApp/AGENT.md](iOSApp/AGENT.md) | MVVM + Clean Architecture rules, naming, DI, testing |
| [docs/planning/execution-plan.md](docs/planning/execution-plan.md) | Complete build plan with phases and checkpoints |
| [docs/design/theme-guide.md](docs/design/theme-guide.md) | Color tokens, typography, and reusable SwiftUI components |
| [docs/pre-release-checklist.md](docs/pre-release-checklist.md) | Locked-in decisions, API key options, pre-release checklist |

## Task Index (Phase 1)

| # | Task | Type |
|---|---|---|
| 01 | [Install Xcode & Apple Developer Account](docs/tasks/phase_1/01-install-xcode_setup.md) | setup |
| 02 | [Get LLM API Key (Gemini for Dev)](docs/tasks/phase_1/02-llm-api-key_setup.md) | setup |
| 03 | [Create Supabase Project & Install CLI](docs/tasks/phase_1/03-supabase-project_backend.md) | backend |
| 04 | [Create Xcode Project & Folder Structure](docs/tasks/phase_1/04-create-xcode-project_setup.md) | setup |
| 05 | [Build Theme System](docs/tasks/phase_1/05-theme-system_iOS.md) | iOS |
| 06 | [Build SQLite Database Layer](docs/tasks/phase_1/06-database-layer_iOS.md) | iOS |
| 07 | [Implement Authentication](docs/tasks/phase_1/07-authentication_iOS.md) | iOS |
| 08 | [Build Supabase Edge Functions](docs/tasks/phase_1/08-edge-functions_backend.md) | backend |
| 09 | [Build Input Guards](docs/tasks/phase_1/09-input-guards_iOS.md) | iOS |
| 10 | [Build Intent Classifier](docs/tasks/phase_1/10-intent-classifier_iOS.md) | iOS |
| 11 | [Build Memory Save Pipeline](docs/tasks/phase_1/11-memory-save-pipeline_iOS.md) | iOS |
| 12 | [RAG Pipeline — Hybrid Retrieval](docs/tasks/phase_1/12-rag-retrieval_iOS.md) | iOS |
| 13 | [RAG Pipeline — Temporal Resolution & Synthesis](docs/tasks/phase_1/13-rag-synthesis_iOS.md) | iOS |
| 14 | [Mixed Query Pipeline & Chat Orchestrator](docs/tasks/phase_1/14-mixed-query-chat_iOS.md) | iOS |
| 15 | [Session Close Pipeline](docs/tasks/phase_1/15-session-close-pipeline_iOS.md) | iOS |
| 16 | [Navigation System & App Router](docs/tasks/phase_1/16-navigation-router_iOS.md) | iOS |
| 17 | [Session List UI](docs/tasks/phase_1/17-session-list-ui_iOS.md) | iOS |
| 18 | [Chat UI](docs/tasks/phase_1/18-chat-ui_iOS.md) | iOS |
| 19 | [Delete Feature](docs/tasks/phase_1/19-delete-feature_iOS.md) | iOS |
| 20 | [Full Test Suite](docs/tasks/phase_1/20-test-suite_iOS.md) | iOS |
| 21 | [Polish & Portfolio Prep](docs/tasks/phase_1/21-polish-portfolio_iOS.md) | iOS |

## Inspect local `memory.db` (Simulator)

Run the app once on a simulator so the database is created, then:

```bash
# 1) Find a booted simulator UDID
xcrun simctl list devices booted

# 2) Resolve the app data container (replace UDID)
DATA=$(xcrun simctl get_app_container <UDID> abu.taher.com.MindMapper data)
DB="$DATA/Documents/memory.db"

# 3a) Open in DB Browser for SQLite (install: brew install --cask db-browser-for-sqlite)
open -a "/Applications/DB Browser for SQLite.app" "$DB"

# 3b) Or inspect from Terminal
sqlite3 "$DB" ".tables"
sqlite3 "$DB" "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%';"
sqlite3 "$DB" ".schema"
```

If `open -a "DB Browser for SQLite"` fails after a fresh install, use the full app path as in `3a` above (Launch Services may not have indexed the name yet).
