# Register a Custom URL Scheme in Xcode (MindMapper)

How to add the `mindmapper` URL scheme so Supabase auth emails (confirm / forgot password) can open the iOS app via `mindmapper://auth-callback`.

**Requires:** Free Apple ID is enough — no paid Developer Program.  
**Related task:** [`docs/tasks/phase_1/07a-forgot-password_iOS.md`](../tasks/phase_1/07a-forgot-password_iOS.md)

---

## Why we need this

Supabase auth emails (confirm signup, reset password) contain a link. After Supabase verifies the token, it **redirects** the browser to a URL you configure (Site URL / Redirect URLs).

For a **website**, that redirect is something like `https://myapp.com/auth/callback`.  
For a **native iOS app**, there is no website — the redirect must open **your installed app** instead.

A **custom URL scheme** teaches iOS: “URLs that start with `mindmapper://` belong to MindMapper.” When the user taps the email link and lands on:

```text
mindmapper://auth-callback?...
```

iOS launches (or foregrounds) the app and hands over that URL. The app then finishes the Auth flow (session-from-URL).

Without registering the scheme:

- Supabase may still redirect to `http://localhost:3000` (useless on a phone), or  
- The `mindmapper://…` link does nothing / fails to open MindMapper.

**Note:** Registering the scheme only makes the OS open the app. Handling the URL in Swift (extract session, update password, mark signed-in) is separate app code (task 07a).

This approach works with a **free** Apple ID. **Universal Links** (`https://yourdomain.com/...`) are a stronger production alternative and need a paid Developer account + your domain.

---

## Register `mindmapper` URL scheme in Xcode (UI)

1. Open `iOSApp/MindMapper/MindMapper.xcodeproj` in Xcode.
2. Select the **MindMapper** project (blue icon) in the navigator.
3. Select the **MindMapper** **target** (not the Tests target).
4. Open the **Info** tab.
5. Find **URL Types** (scroll down). If it’s collapsed, expand it.
6. Click **+** to add a URL Type.
7. Fill in:

| Field | Value |
|--------|--------|
| **Identifier** | `abu.taher.com.MindMapper` (or `com.mindmapper.auth` — any unique string) |
| **URL Schemes** | `mindmapper` ← **no** `://` |
| **Role** | Editor (default is fine) |

8. Leave **Icon** empty.
9. Build/run once so the change is picked up.

---

## What you should end up with

- Scheme name: `mindmapper`
- Full callback (also configure in Supabase → Authentication → URL Configuration): `mindmapper://auth-callback`

### Supabase (manual)

| Field | Value |
|--------|--------|
| **Site URL** | `mindmapper://auth-callback` |
| **Redirect URLs** | `mindmapper://auth-callback` |

---

## Quick check (optional)

On Simulator with the app installed, in Terminal:

```bash
xcrun simctl openurl booted "mindmapper://auth-callback"
```

The app should come to the foreground.

> Deep-link **handling** in Swift (`.onOpenURL` → Supabase session-from-URL) is implemented as part of task 07a — registering the scheme alone only opens the app.
