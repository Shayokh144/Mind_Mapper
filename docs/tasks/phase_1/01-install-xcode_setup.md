# Install Xcode & Configure Apple Developer Account

---

## Category

`ios`

## Estimated Time

⏱️ 1 hour

## Depends On

None — this is the first task

## Related Plan Section

📄 `../planning/execution-plan.md` → Phase 0 — Environment Setup › Step 0.1

## Related UI

None — no UI built in this task

---

## What To Do

- [x] **1.** Install Xcode 16 or later from the Mac App Store. Do not proceed with an older version.
- [x] **2.** Launch Xcode → Settings → Accounts → sign in with your Apple ID.
- [x] **3.** *(Optional for now)* Enrol in the Apple Developer Program at developer.apple.com ($99/year) — only needed for App Store submission or TestFlight. A free Apple ID is enough to run on your own iPhone during development.
- [x] **4.** Connect your physical iPhone via USB. In Xcode → Devices and Simulators, confirm the device is listed and trusted.
- [x] **5.** Create a blank SwiftUI project (File → New Project → iOS → App) to verify the setup. Product name: `HelloTest`. Run it on your physical iPhone.
- [x] **6.** Confirm your iPhone is running iOS 18.1 or later (required for Apple Foundation Models). Check in Settings → General → About.
- [x] **7.** Delete the test project after verification — it was only for confirming your setup works.

---



## ✅ Done When

- [x] Xcode 16+ opens without errors.
- [x] Your Apple Developer account appears under Xcode → Settings → Accounts.
- [x] A blank SwiftUI app builds and runs on your physical iPhone without errors.

---



## 📝 Notes

If your iPhone is older than iPhone 15 Pro or iPhone 16, you can still build the full app — it will use OpenAI via API instead of on-device Foundation Models. The app logic is identical either way.