# Build the SQLite Database Layer

---

## Category
`ios`

## Estimated Time
⏱️ 4–6 hours

## Depends On
Task 4 (Xcode project with GRDB package)

## Related Plan Section
📄 `../planning/execution-plan.md` → Phase 1 — Database Layer › Steps 1.1 and 1.2 | ../../iOSApp/AGENT.md › Section 4.4 (Repository Implementations)

## Related UI
None — no UI built in this task. This layer powers the Session List (sessions table), Chat View (messages table), and all RAG features (memories, vectors, entities tables).

---

## What To Do

- [x] **1.** Read ../../iOSApp/AGENT.md Section 4 (Clean Architecture Layers) before starting — specifically the distinction between domain models and GRDB records.
- [x] **2.** Create `Core/Database/DatabaseManager.swift`. Implement a singleton with a `DatabaseQueue`. On init, resolve the SQLite file path in the app's Documents directory as `memory.db`.
- [x] **3.** Implement GRDB migrations using `DatabaseMigrator`. Register migration `v1_initial` that creates all six tables in the correct order: users, sessions, messages, memories, memory_entities, vectors. Include all columns and foreign key references exactly as specified in the execution plan.
- [x] **4.** Add the three performance indexes: `idx_messages_session` on messages(session_id), `idx_memories_user` on memories(user_id), and `idx_entities_lookup` on memory_entities(entity_type, entity_value).
- [x] **5.** Create `Domain/Models/AppModels.swift` with pure Swift structs for all six entities: User, Session, Message, Memory, MemoryEntity, Vector. *(Deviation from task wording: GRDB `FetchableRecord` / `PersistableRecord` live in `Data/Local/GRDBRecords.swift` so Domain stays framework-free per AGENT.md §4.1 / §4.4.)*
- [x] **6.** Add a `TopicTag` enum inside the Session model with cases: wardrobe, plans, locations, people, ideas, gifts, work, health, other.
- [x] **7.** Write a unit test file `DatabaseManagerTests.swift`. Test: insert a Session row and fetch it back, insert a Memory with entities and verify foreign key integrity, insert a Vector and verify the blob roundtrips correctly (serialize [Float] → Data → [Float] and compare).
- [x] **8.** Verify the migration runs on a fresh install by deleting the app from the simulator and relaunching — all tables should be created automatically.
- [x] **9.** Open the `memory.db` file in DB Browser for SQLite or TablePlus to visually confirm all tables, columns, indexes, and foreign keys are correct. *(Verified via `sqlite3` `.tables` / `.schema`.)*

---

## ✅ Done When

- [x] App launches without crash. `memory.db` exists at the documents path.
- [x] All 6 tables exist with correct columns when inspected in a SQLite browser.
- [x] All 3 indexes exist and are named correctly.
- [x] Unit tests for insert/fetch pass on all models.
- [x] Vector blob round-trip test passes: `[Float] → Data → [Float]` produces identical values.

---

## 📝 Notes

The `vectors` table stores embeddings as a binary blob (Data). Each embedding is 1536 floats × 4 bytes = 6,144 bytes (~6 KB) per memory. Use `array.withUnsafeBufferPointer { Data(buffer: $0) }` to serialize and `data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }` to deserialize.
