# Build the Theme System (Colors, Fonts, Spacing, Components)

---

## Category
`ios`

## Estimated Time
⏱️ 3–4 hours

## Depends On
Task 4 (Xcode project created)

## Related Plan Section
📄 `../planning/execution-plan.md` → Phase 0 (project setup) | ../design/theme-guide.md — all sections

## Related UI
Every screen — the theme system underpins all UI. Onboarding, Session List, Chat View all use these tokens.

---

## What To Do

- [ ] **1.** Read ../design/theme-guide.md fully before writing any code. The three-layer token system (raw values → semantic tokens → components) is the core concept.
- [ ] **2.** In Assets.xcassets, create Color Sets for all 11 semantic colors: ThemeAccent, ThemeBackground, ThemeSurface, ThemeSurfaceSecondary, ThemeTextPrimary, ThemeTextSecondary, ThemeTextMuted, ThemeBorder, ThemeSuccess, ThemeWarning, ThemeDanger. For each, set Appearances to 'Any, Dark' and fill in both light and dark values from the guide.
- [ ] **3.** Create `Core/Theme/Color+Theme.swift` with the `Color.theme` enum exposing all 11 color tokens as static properties reading from the asset catalog.
- [ ] **4.** Create `Core/Theme/Font+Theme.swift` with the `Font.theme` enum exposing all 8 type scale roles: largeTitle, title, headline, body, callout, subheadline, footnote, caption, plus bodyBold and headlineBold variants.
- [ ] **5.** Create `Core/Theme/TextStyles.swift` with SwiftUI View extension modifiers: `.titleStyle()`, `.headlineStyle()`, `.bodyStyle()`, `.secondaryStyle()`, `.captionStyle()`.
- [ ] **6.** Create `Core/Theme/Spacing.swift` with the `Spacing` enum (xs=4, sm=8, md=12, lg=16, xl=24, xxl=32) and `Radius` enum (sm=8, md=12, lg=16, xl=24, pill=999).
- [ ] **7.** Create `Core/Theme/Components/PrimaryButton.swift` — filled accent background, 48pt height, supports icon, loading state, disabled state.
- [ ] **8.** Create `Core/Theme/Components/SecondaryButton.swift` — outline style, 48pt height, supports icon.
- [ ] **9.** Create `Core/Theme/Components/GhostButton.swift` — text only, configurable color, used for tertiary actions.
- [ ] **10.** Create `Core/Theme/Components/DestructiveButton.swift` — danger color, supports filled and outlined styles.
- [ ] **11.** Create `Core/Theme/Components/ThemeCard.swift` — generic container with surface background and rounded corners.
- [ ] **12.** Create `Core/Theme/Components/ThemeTextField.swift` — multiline-capable text input with surfaceSecondary background, 500 char limit built in.
- [ ] **13.** Create `Core/Theme/Components/ChatBubble.swift` — user (right-aligned, accent fill) and assistant (left-aligned, surface fill) variants with asymmetric corner radii.
- [ ] **14.** Create `Core/Theme/Components/ThemeBadge.swift` — pill shape with icon support, five role variants (accent, success, warning, danger, neutral).
- [ ] **15.** Write a `#Preview` block for each component showing light and dark mode side by side using `.preferredColorScheme(.light)` and `.preferredColorScheme(.dark)`.

---

## ✅ Done When

- [ ] All color assets render correctly in both light and dark mode in Xcode Canvas (toggle with the sun/moon icon).
- [ ] Changing ThemeAccent color asset updates PrimaryButton, ThemeBadge accent, and any other component using `Color.theme.accent` — without touching component files.
- [ ] All 8 components have `#Preview` blocks showing both light and dark mode.
- [ ] No raw `Color(hex:)` or `.font(.system(size:))` calls exist outside of `Color+Theme.swift` and `Font+Theme.swift`.

---

## 📝 Notes

This task must be completed before any feature UI is built. It is the foundation every screen rests on. The time invested here saves hours of refactoring later.
