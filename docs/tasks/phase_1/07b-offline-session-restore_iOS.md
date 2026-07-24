# Offline-Safe Session Restore

---

## Category
`ios`

## Estimated Time
⏱️ 1–2 hours

## Depends On
Task 7 (email auth — `AuthManager.restoreSession`)

## Related Plan Section
Session restore must stay local-first: network failures must not clear a valid stored Supabase session.

## Status
**Implemented** with Task 07a follow-up (Part A). This doc records the done work for history / regression.

---

## What Was Done

- [x] **1.** Prefer `client.auth.currentSession` on launch (local storage) instead of `client.auth.session` (may refresh over the network).
- [x] **2.** Apply local SQLite user and set `isAuthenticated = true` **before** any remote check.
- [x] **3.** Defer remote validation (`session` refresh + `user()`) into `validateSessionRemotely()`; on network/transient errors keep local auth and set `needsRemoteRevalidation = true`.
- [x] **4.** Only call `signOut` / clear local auth on hard auth failures (`sessionMissing`, 401/403) or missing local session.
- [x] **5.** Expose `needsRemoteRevalidation` + `revalidateSessionIfNeeded()` on `AuthManagerProtocol` for Task 07c.
- [x] **6.** Unit-test `AuthNetworkErrorClassifier` (transient vs hard failures).

---

## ✅ Done When

- [x] Quit app while logged in → relaunch with **no internet** → still signed in (local session).
- [x] Online relaunch with a user deleted in Supabase dashboard → session cleared / signed out.
- [x] Classifier tests pass.

---

## 📝 Notes

Follow-ups: [07c-network-reachability_iOS.md](07c-network-reachability_iOS.md) (global monitor + banner), [07d-reconnect-session-revalidation_iOS.md](07d-reconnect-session-revalidation_iOS.md) (call `revalidateSessionIfNeeded` when path becomes satisfied + API gates).
