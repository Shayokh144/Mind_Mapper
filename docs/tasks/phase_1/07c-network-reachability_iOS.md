# Network Reachability (NWPathMonitor)

---

## Category
`ios`

## Estimated Time
⏱️ 2–3 hours

## Depends On
Task 7 (AppContainer DI), Task 07b (offline session restore — local auth must survive offline)

## Related Plan Section
Scalable path monitoring: one shared monitor, many listeners. Reference pattern: `iOSEssentials/DemoApps/MockNWPathMonitor` (`NetworkPathMonitorProtocol` + mock).

## Related UI
App-wide offline banner / alert on `AppRootHost` (not one alert per ViewModel).

## Status
**Implemented** — continue with [07d-reconnect-session-revalidation_iOS.md](07d-reconnect-session-revalidation_iOS.md).

---

## What To Do

- [x] **1.** Add `Core/Network/NetworkPathMonitorProtocol.swift` with `pathUpdateHandler`, `start(queue:)`, `cancel()` — same shape as the MockNWPathMonitor demo.
- [x] **2.** Add `Core/Network/NetworkPathMonitor.swift` wrapping a single `NWPathMonitor` (injectable for tests).
- [x] **3.** Add domain-friendly `NetworkStatus` (`.undetermined` / `.connected` / `.disconnected`) and `NetworkReachabilityProtocol` + `NetworkReachabilityService` (`@MainActor ObservableObject`) that owns the monitor, publishes `@Published private(set) var status` / `isConnected`, starts once, cancels on deinit.
- [x] **4.** Keep `NWPath` / `Network` imports inside Core — Domain and ViewModels only see `NetworkStatus` / the reachability protocol.
- [x] **5.** Create **one** instance in `AppContainer` and expose it (e.g. `container.networkReachability`). Never construct `NWPathMonitor` inside a ViewModel.
- [x] **6.** In `AppRootHost`, observe reachability and show a single theme-aligned offline banner/alert when status becomes `.disconnected`; hide when `.connected`.
- [x] **7.** Add `MockNetworkPathMonitor` under tests and unit-test that the service maps `.satisfied` → `.connected` and unsatisfied → `.disconnected`.
- [x] **8.** Add `AppError.noInternet` with user-facing copy and `isRetryable == true` (gating API calls is Task 07d).

---

## ✅ Done When

- [x] Airplane mode while in the app → one offline banner appears promptly.
- [x] Connectivity restored → banner dismisses.
- [x] ViewModels receive reachability via DI only (no `.shared` monitor, no per-screen `NWPathMonitor`).
- [x] Mock-based unit tests pass.

---

## 📝 Notes

- Path “satisfied” ≠ guaranteed internet (captive portals). Good enough for Phase 1; true probes can come later.
- Do **not** have each ViewModel own an `NWPathMonitor`. Subscribe to the shared `NetworkReachabilityService` publisher / `isConnected` instead.
- Wire reconnect revalidation + pre-API guards in [07d-reconnect-session-revalidation_iOS.md](07d-reconnect-session-revalidation_iOS.md).
