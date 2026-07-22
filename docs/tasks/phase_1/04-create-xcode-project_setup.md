# Create Xcode Project & Folder Structure

---

## Category

`ios`

## Estimated Time

⏱️ 1–2.5 hours

## Depends On

Task 1 (Xcode installed)

## Related Plan Section

📄 `../planning/execution-plan.md` → Phase 0 — Environment Setup › Step 0.4 | ../../iOSApp/AGENT.md › Section 2 — Folder Structure

## Related UI

None — no UI built in this task, but this structure hosts all future UI screens

---

## What To Do

- [x] **1.** Open Xcode → File → New → Project → iOS → App.
- [x] **2.** Set Product Name: `MindMapper`, Interface: SwiftUI, Language: Swift, Bundle Identifier: `com.yourname.MindMapper` (replace yourname with your actual name or handle).
- [x] **3.** Save the project inside the repository's `iOSApp/` folder (e.g. `Mind_Mapper/iOSApp/MindMapper.xcodeproj`). Do not create a separate Git repository — this repo already has one.
- [x] **4.** Create the full folder structure inside the project by adding Groups (not just folders): App/, Core/Theme/, Core/Database/, Core/Network/, Core/DI/, Core/Guards/, Domain/Models/, Domain/Repositories/, Domain/UseCases/, Data/Repositories/, Data/Local/, Data/Remote/, Features/Onboarding/, Features/Auth/, Features/Sessions/, Features/Chat/, Features/Memories/, Features/Settings/, Resources/.
- [x] **5.** Add Swift Package dependencies via File → Add Package Dependencies: Add `https://github.com/groue/GRDB.swift` (version 6.0.0 or later) and `https://github.com/supabase/supabase-swift` (version 2.0.0 or later).
- [x] **6.** Add a `.gitignore` file to the project root. Include: `.env`, `*.xcuserstate`, `xcuserdata/`, `DerivedData/`, `Pods/`. Commit this file first before any other files.
- [x] **7.** Verify `iOSApp/AGENT.md` is present (architecture guide — already in the repo). Commit the initial project structure.
- [x] **8.** Verify the project builds cleanly with both SPM packages added — no red errors in the build log.
- [x] **9.** Read ../../iOSApp/AGENT.md and ../design/theme-guide.md before writing any Swift code in future tasks — all architecture decisions are documented there.

---



## ✅ Done When

- [x] Project builds with zero errors and zero warnings.
- [x] Both GRDB and Supabase packages appear under Package Dependencies in the Xcode navigator.
- [x] All folder groups exist in the project navigator matching the structure in ../../iOSApp/AGENT.md Section 2.
- [x] `.gitignore` is committed and no sensitive files are tracked.

---



## 📝 Notes

This project uses Xcode’s filesystem-synchronized root folder (`PBXFileSystemSynchronizedRootGroup`). Creating real directories under `iOSApp/MindMapper/MindMapper/` is enough for them to appear in the navigator — no manual yellow-group wiring is required.

Empty feature/layer folders keep uniquely named `*Folder.swift` comment placeholders so Git tracks the directories and the synchronized target does not collide on duplicate basenames. Remove each placeholder when real source lands in that folder.

SPM products currently linked: `GRDB`, `Auth`, `Functions` (from supabase-swift).
