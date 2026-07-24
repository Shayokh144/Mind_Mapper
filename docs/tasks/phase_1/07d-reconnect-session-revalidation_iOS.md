# Reconnect Revalidation + Offline API Gates

---

## Category
`ios`

## Estimated Time
⏱️ 2–3 hours

## Depends On
Task 07b (`needsRemoteRevalidation` / `revalidateSessionIfNeeded`), Task 07c (shared `NetworkReachabilityService` + `AppError.noInternet`)

## Related Plan Section
When the path becomes satisfied, finish deferred remote session checks. Block network-bound actions while offline.

## Related UI
Auth screens (login / forgot password / set password) and future LLM/chat call sites — show `AppError.noInternet` instead of firing doomed requests.

## Status
**Implemented.**

---

## What To Do

- [x] **1.** On `AppRootHost` (or a small coordinator owned by the container), when reachability transitions to `.connected`, call `await authManager.revalidateSessionIfNeeded()`.
- [x] **2.** Confirm hard auth failure after reconnect still clears session (deleted user / revoked refresh); transient failures leave the user signed in and may leave `needsRemoteRevalidation` true for another retry.
- [x] **3.** Inject `NetworkReachabilityProtocol` into ViewModels that perform network work (`LoginViewModel`, `ForgotPasswordViewModel`, `SetNewPasswordViewModel`, and later chat/LLM VMs).
- [x] **4.** Before each API call: `guard reachability.isConnected else { throw AppError.noInternet }` (or set `errorMessage` from that error). Prefer failing fast over relying only on the banner.
- [x] **5.** Optional defense-in-depth: a tiny `NetworkGate` helper used by remote clients so new call sites inherit the check.
- [x] **6.** Unit-test ViewModel (or gate) behavior with `MockNetworkPathMonitor` / mock reachability: disconnected → no auth manager call + `noInternet` surfaced; connected → proceeds.

---

## ✅ Done When

- [x] Offline after login → stay signed in (07b); go online → remote validation runs once without forcing logout on success.
- [x] Tapping Sign In / Reset Password with no network → `AppError.noInternet` UI, zero Supabase request attempted.
- [x] Deleted Supabase user + reconnect → signed out after revalidation.
- [x] Tests cover connected vs disconnected gates.

---

## 📝 Notes

- Banner (07c) = awareness; call-site gate (this task) = correctness.
- Avoid N simultaneous alerts from N ViewModels — keep the global banner as the primary disconnect signal; ViewModels only set inline errors when the user *tries* an action offline.
