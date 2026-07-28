# Localization (English-first String Catalog)

MindMapper ships user-facing copy from a **String Catalog** so new locales can be added without hunting string literals.

**Files**
- `iOSApp/MindMapper/MindMapper/Resources/Localizable.xcstrings` — source of truth (English today)
- `iOSApp/MindMapper/MindMapper/Core/Localization/L10n.swift` — typed keys for Views / ViewModels / errors

**Usage**

```swift
Text(L10n.Tab.chats)
PrimaryButton(title: L10n.Auth.signIn) { … }
errorMessage = L10n.Error.llmFailed
```

**Rules**
1. Do **not** put user-visible English literals in Views or `AppError` — add a key to the catalog, then an `L10n` accessor.
2. Keep keys stable and namespaced: `auth.sign_in`, `error.no_internet`, `sessions.empty`.
3. Format strings use `%lld` / `%@` in the catalog and `String(format:locale:arguments:)` in `L10n` (see `L10n.Error.rateLimit`).
4. LLM **system prompts** stay as code strings (not localized) — they are model instructions, not UI.
5. When adding a language: open the catalog in Xcode → localize → translate values; no `L10n` API change needed if keys stay the same.

**Related:** `Domain/Models/AppError.swift`, feature Views under `Features/`.
