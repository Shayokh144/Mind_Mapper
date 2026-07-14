# Memory App — iOS Theme & Component System Guide

> **Purpose of this document:** A single reference to keep while writing SwiftUI code. It defines the color system, typography system, and reusable component library so that the entire app stays visually consistent and changing one value (e.g. the primary color) updates every screen automatically.

---

## Core Principle — The Three-Layer Token System

Never write a raw color or font value directly in a view. Every visual decision flows through three layers:

```
LAYER 1 — Raw values         LAYER 2 — Semantic tokens        LAYER 3 — Components
(the actual hex/font)        (what it MEANS)                  (what you use in views)
─────────────────────        ──────────────────────           ─────────────────────
Color(hex: "#3478F6")   →    Color.theme.accent          →    PrimaryButton()
Color(hex: "#1C1C1E")   →    Color.theme.textPrimary     →    Text("Hello").primaryText()
"SF Pro" 17pt 600        →    Font.theme.headline          →   Text("Title").headlineStyle()
```

**Why this matters:** If you hardcode `Color(hex: "#3478F6")` in 40 different buttons across the app, changing your brand color means editing 40 files. If every button instead reads `Color.theme.accent`, changing one line in `Theme.swift` updates all 40 buttons instantly.

> **Rule of thumb:** If you ever type `Color(red:`, `Color(hex:`, or a raw `.font(.system(size: 17))` inside a screen file (not inside `Theme.swift` itself), stop — you're breaking the system.

---

## Part 1 — Color System

### Step 1.1 — Define Semantic Color Roles

Before writing code, decide what *roles* colors play in your app. Do not think in terms of "blue" or "gray" — think in terms of *purpose*. This app needs:

| Role | Purpose | Example usage |
|---|---|---|
| `accent` | Primary brand color, calls to action | Send button, links, selected states |
| `background` | Screen background | Behind everything |
| `surface` | Card / elevated content background | Chat bubbles, list rows, cards |
| `surfaceSecondary` | Slightly different elevation | Input field background |
| `textPrimary` | Main readable text | Message content, titles |
| `textSecondary` | Supporting text | Timestamps, subtitles |
| `textMuted` | Least important text | Placeholders, hints |
| `border` | Hairline dividers | Card borders, separators |
| `success` | Positive states | "Saved" confirmations |
| `warning` | Caution states | Scope-blocked messages |
| `danger` | Destructive states | Delete buttons, errors |

This is the same pattern used by every mature design system (including Apple's own Human Interface Guidelines color roles) — name colors by what they *do*, not what they *look like*.

---

### Step 1.2 — Create Color Assets in Xcode (Recommended Approach)

The cleanest way to support light/dark mode automatically in iOS is using **Color Assets** in `Assets.xcassets`, because Xcode handles the light/dark switching natively without any code.

**How to set this up:**

1. Open `Assets.xcassets` in Xcode
2. Right-click → New Color Set, name it `AccentColor` (repeat for each role below)
3. In the inspector, set **Appearances** to "Any, Dark" — this gives you two color wells: one for light mode, one for dark mode
4. Pick your colors for each

**Create these Color Sets:**

| Color Set name | Light mode value | Dark mode value |
|---|---|---|
| `ThemeAccent` | `#3478F6` (blue) | `#5E9FFF` (lighter blue — more legible on dark) |
| `ThemeBackground` | `#FFFFFF` | `#000000` |
| `ThemeSurface` | `#F5F5F7` | `#1C1C1E` |
| `ThemeSurfaceSecondary` | `#EFEFF1` | `#2C2C2E` |
| `ThemeTextPrimary` | `#1C1C1E` | `#FFFFFF` |
| `ThemeTextSecondary` | `#6E6E73` | `#A1A1A6` |
| `ThemeTextMuted` | `#AEAEB2` | `#6E6E73` |
| `ThemeBorder` | `#E5E5EA` (0.5pt alpha) | `#38383A` |
| `ThemeSuccess` | `#34C759` | `#30D158` |
| `ThemeWarning` | `#FF9F0A` | `#FFD60A` |
| `ThemeDanger` | `#FF3B30` | `#FF453A` |

> **Why darker colors get lighter in dark mode:** A saturated blue (`#3478F6`) looks vivid on white but loses contrast and feels muddy on black. Always slightly lighten/desaturate accent colors for dark mode — this is standard practice (Apple does this with their own system colors too).

---

### Step 1.3 — Create the Swift Color Theme Wrapper

This is the file every other file in the app will reference. Create `Core/Theme/Color+Theme.swift`:

```swift
import SwiftUI

extension Color {
    /// Single namespace for every themed color in the app.
    /// Never reference Color Assets directly elsewhere — always go through this.
    enum theme {
        static let accent = Color("ThemeAccent")
        static let background = Color("ThemeBackground")
        static let surface = Color("ThemeSurface")
        static let surfaceSecondary = Color("ThemeSurfaceSecondary")

        static let textPrimary = Color("ThemeTextPrimary")
        static let textSecondary = Color("ThemeTextSecondary")
        static let textMuted = Color("ThemeTextMuted")

        static let border = Color("ThemeBorder")

        static let success = Color("ThemeSuccess")
        static let warning = Color("ThemeWarning")
        static let danger = Color("ThemeDanger")

        // Colors that are always the same regardless of accent (e.g. text on a filled accent button)
        static let onAccent = Color.white
    }
}
```

**Usage anywhere in the app:**

```swift
Text("Hello")
    .foregroundStyle(Color.theme.textPrimary)

Rectangle()
    .fill(Color.theme.surface)
```

That's it. SwiftUI automatically switches between the light/dark values defined in the asset catalog — **zero conditional code needed.**

---

### Step 1.4 — Alternative Approach (No Asset Catalog — Pure Swift)

If you prefer everything to live in code (easier to see at a glance, no jumping to Xcode's asset editor), use this pattern instead. This is a valid alternative — pick one approach and stay consistent.

Create `Core/Theme/AppTheme.swift`:

```swift
import SwiftUI

struct AppTheme {

    // MARK: — Color pairs (light, dark)
    private struct ColorPair {
        let light: Color
        let dark: Color

        func resolve(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? dark : light
        }
    }

    private static let accentPair = ColorPair(
        light: Color(hex: "#3478F6"),
        dark: Color(hex: "#5E9FFF")
    )
    private static let backgroundPair = ColorPair(
        light: Color(hex: "#FFFFFF"),
        dark: Color(hex: "#000000")
    )
    private static let surfacePair = ColorPair(
        light: Color(hex: "#F5F5F7"),
        dark: Color(hex: "#1C1C1E")
    )
    private static let textPrimaryPair = ColorPair(
        light: Color(hex: "#1C1C1E"),
        dark: Color(hex: "#FFFFFF")
    )
    private static let textSecondaryPair = ColorPair(
        light: Color(hex: "#6E6E73"),
        dark: Color(hex: "#A1A1A6")
    )
    private static let borderPair = ColorPair(
        light: Color(hex: "#E5E5EA"),
        dark: Color(hex: "#38383A")
    )

    // MARK: — Public resolver (call with current color scheme)
    static func accent(_ scheme: ColorScheme) -> Color { accentPair.resolve(scheme) }
    static func background(_ scheme: ColorScheme) -> Color { backgroundPair.resolve(scheme) }
    static func surface(_ scheme: ColorScheme) -> Color { surfacePair.resolve(scheme) }
    static func textPrimary(_ scheme: ColorScheme) -> Color { textPrimaryPair.resolve(scheme) }
    static func textSecondary(_ scheme: ColorScheme) -> Color { textSecondaryPair.resolve(scheme) }
    static func border(_ scheme: ColorScheme) -> Color { borderPair.resolve(scheme) }
}

// Helper to create Color from hex string
extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: .init(charactersIn: "#")))
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
```

**Usage in a view (requires reading the environment's color scheme):**

```swift
struct SomeView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Text("Hello")
            .foregroundStyle(AppTheme.textPrimary(colorScheme))
    }
}
```

> **Recommendation: use the Color Assets approach (Step 1.3), not this one.** It requires zero `@Environment` boilerplate in every view, SwiftUI handles the switching natively, and it's the approach Apple's own HIG recommends. Use Step 1.4 only if your team strongly prefers everything in code.

---

### Step 1.5 — Changing the Primary Color (Proof the System Works)

To rebrand the entire app's accent color, you change exactly **one place**:

**If using Color Assets:** Open `Assets.xcassets` → `ThemeAccent` → change the light and dark color wells.

**If using pure Swift:** Open `AppTheme.swift` → change `accentPair`'s `light:` and `dark:` values.

Every `PrimaryButton`, every selected tab icon, every link, every "Send" button across the entire app updates immediately — because they all reference `Color.theme.accent`, never a raw hex value.

---

## Part 2 — Typography System

### Step 2.1 — Define the Type Scale

Just like colors, typography needs semantic names, not raw font sizes scattered everywhere.

| Role | Size | Weight | Usage |
|---|---|---|---|
| `largeTitle` | 28pt | Bold (700) | Onboarding headlines |
| `title` | 22pt | Semibold (600) | Screen titles ("My memory") |
| `headline` | 17pt | Semibold (600) | Section headers, session titles |
| `body` | 16pt | Regular (400) | Chat message content |
| `callout` | 15pt | Regular (400) | Secondary chat content |
| `subheadline` | 14pt | Regular (400) | Session preview text |
| `footnote` | 13pt | Regular (400) | Timestamps, metadata |
| `caption` | 11pt | Regular (400) | Smallest hints, character counts |

This follows Apple's own Dynamic Type naming convention (`largeTitle`, `title`, `headline`, `body`, etc.) — using the same names as iOS system fonts means your app automatically benefits from Dynamic Type accessibility scaling.

---

### Step 2.2 — Create the Typography Theme File

Create `Core/Theme/Font+Theme.swift`:

```swift
import SwiftUI

extension Font {
    enum theme {
        static let largeTitle = Font.system(size: 28, weight: .bold)
        static let title = Font.system(size: 22, weight: .semibold)
        static let headline = Font.system(size: 17, weight: .semibold)
        static let body = Font.system(size: 16, weight: .regular)
        static let callout = Font.system(size: 15, weight: .regular)
        static let subheadline = Font.system(size: 14, weight: .regular)
        static let footnote = Font.system(size: 13, weight: .regular)
        static let caption = Font.system(size: 11, weight: .regular)

        // Emphasis variants — used sparingly
        static let bodyBold = Font.system(size: 16, weight: .semibold)
        static let headlineBold = Font.system(size: 17, weight: .bold)
    }
}
```

**Usage anywhere in the app:**

```swift
Text("My memory")
    .font(.theme.title)
    .foregroundStyle(Color.theme.textPrimary)
```

---

### Step 2.3 — Supporting Dynamic Type (Accessibility — Strongly Recommended)

Apple's accessibility guidelines expect text to scale when the user increases their system font size (Settings → Accessibility → Display & Text Size). The simple `Font.system(size:)` above does **not** automatically scale. To support this properly, use `.relativeTo` instead:

```swift
extension Font {
    enum theme {
        static let largeTitle = Font.system(size: 28, weight: .bold, design: .default)
            .leading(.standard)
        // Better — scales with Dynamic Type:
        static let title = Font.custom("SF Pro", size: 22, relativeTo: .title)
            .weight(.semibold)
        static let headline = Font.custom("SF Pro", size: 17, relativeTo: .headline)
            .weight(.semibold)
        static let body = Font.custom("SF Pro", size: 16, relativeTo: .body)
        static let footnote = Font.custom("SF Pro", size: 13, relativeTo: .footnote)
    }
}
```

> **Recommendation for this app:** Start with the simpler fixed-size approach (Step 2.2) to ship faster. Upgrade to `relativeTo` scaling before App Store submission — Apple reviewers and accessibility-conscious users notice when text doesn't scale.

---

### Step 2.4 — Reusable Text Style Modifiers

To avoid writing `.font(.theme.body).foregroundStyle(Color.theme.textPrimary)` repeatedly, wrap common combinations into view modifiers. Create `Core/Theme/TextStyles.swift`:

```swift
import SwiftUI

extension View {
    func titleStyle() -> some View {
        self.font(.theme.title)
            .foregroundStyle(Color.theme.textPrimary)
    }

    func headlineStyle() -> some View {
        self.font(.theme.headline)
            .foregroundStyle(Color.theme.textPrimary)
    }

    func bodyStyle() -> some View {
        self.font(.theme.body)
            .foregroundStyle(Color.theme.textPrimary)
    }

    func secondaryStyle() -> some View {
        self.font(.theme.subheadline)
            .foregroundStyle(Color.theme.textSecondary)
    }

    func captionStyle() -> some View {
        self.font(.theme.caption)
            .foregroundStyle(Color.theme.textMuted)
    }
}
```

**Usage:**

```swift
Text("My memory").titleStyle()
Text("Gift ideas for wife").headlineStyle()
Text("You decided on a watch...").secondaryStyle()
Text("2h ago").captionStyle()
```

This is dramatically cleaner in actual view code and guarantees consistency — nobody can accidentally use the wrong color with the wrong font size.

---

## Part 3 — Spacing & Sizing Tokens

Colors and fonts aren't the only things that should be tokenized. Spacing should be too, or you'll end up with inconsistent padding (`12`, `14`, `16`, `18` used randomly for the "same" gap).

Create `Core/Theme/Spacing.swift`:

```swift
import SwiftUI

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let pill: CGFloat = 999   // fully rounded
}
```

**Usage:**

```swift
VStack(spacing: Spacing.md) {
    Text("Title")
    Text("Subtitle")
}
.padding(Spacing.lg)
.background(Color.theme.surface)
.clipShape(RoundedRectangle(cornerRadius: Radius.lg))
```

---

## Part 4 — Reusable Component Library

This is the payoff of the token system. Every component below uses **only** `Color.theme`, `Font.theme`, `Spacing`, and `Radius` — never a raw value. Change any token, and every component updates everywhere it's used.

---

### Step 4.1 — Primary Button

The main call-to-action style — filled background, used sparingly (one per screen, following Apple's own restraint principle: at most one primary action visible at a time).

Create `Core/Theme/Components/PrimaryButton.swift`:

```swift
import SwiftUI

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(Color.theme.onAccent)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(title)
                        .font(.theme.headline)
                }
            }
            .foregroundStyle(Color.theme.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(isEnabled ? Color.theme.accent : Color.theme.textMuted)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .disabled(!isEnabled || isLoading)
    }
}

// MARK: — Preview
#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "Continue", action: {})
        PrimaryButton(title: "Save memory", icon: "checkmark", action: {})
        PrimaryButton(title: "Loading...", isLoading: true, action: {})
        PrimaryButton(title: "Disabled", isEnabled: false, action: {})
    }
    .padding()
}
```

---

### Step 4.2 — Secondary Button

Lower-emphasis action — outlined, not filled. Use for anything that isn't the single most important action on screen.

```swift
struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                }
                Text(title)
                    .font(.theme.headline)
            }
            .foregroundStyle(Color.theme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Color.theme.border, lineWidth: 1)
            )
        }
    }
}

#Preview {
    SecondaryButton(title: "Cancel", action: {})
        .padding()
}
```

---

### Step 4.3 — Ghost / Text Button

The lowest-emphasis action — no background, no border. Used for tertiary actions like "Skip" or inline links.

```swift
struct GhostButton: View {
    let title: String
    var color: Color = Color.theme.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.theme.subheadline)
                .foregroundStyle(color)
        }
    }
}

#Preview {
    GhostButton(title: "Skip for now", action: {})
}
```

---

### Step 4.4 — Destructive Button

For delete / sign-out / irreversible actions. Uses the danger color role.

```swift
struct DestructiveButton: View {
    let title: String
    var style: Style = .filled
    let action: () -> Void

    enum Style { case filled, outlined }

    var body: some View {
        Button(role: .destructive, action: action) {
            Text(title)
                .font(.theme.headline)
                .foregroundStyle(style == .filled ? Color.theme.onAccent : Color.theme.danger)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(style == .filled ? Color.theme.danger : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(style == .outlined ? Color.theme.danger : Color.clear, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        DestructiveButton(title: "Delete conversation", action: {})
        DestructiveButton(title: "Delete conversation", style: .outlined, action: {})
    }
    .padding()
}
```

---

### Step 4.5 — Card Container

A reusable surface wrapper used for session list rows, memory cards, and any "boxed" content.

```swift
struct ThemeCard<Content: View>: View {
    @ViewBuilder let content: Content
    var padding: CGFloat = Spacing.lg

    var body: some View {
        content
            .padding(padding)
            .background(Color.theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    }
}

#Preview {
    ThemeCard {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Gift ideas for wife").headlineStyle()
            Text("You decided on a watch and a scarf").secondaryStyle()
        }
    }
    .padding()
}
```

---

### Step 4.6 — Text Field (Chat Input Style)

```swift
struct ThemeTextField: View {
    @Binding var text: String
    let placeholder: String
    var maxLength: Int = 500

    var body: some View {
        HStack(spacing: Spacing.sm) {
            TextField(placeholder, text: $text, axis: .vertical)
                .font(.theme.body)
                .foregroundStyle(Color.theme.textPrimary)
                .lineLimit(1...4)
                .onChange(of: text) { _, newValue in
                    if newValue.count > maxLength {
                        text = String(newValue.prefix(maxLength))
                    }
                }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(Color.theme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
    }
}

#Preview {
    ThemeTextField(text: .constant(""), placeholder: "Tell me something or ask...")
        .padding()
}
```

---

### Step 4.7 — Chat Bubble Component

```swift
struct ChatBubble: View {
    let text: String
    let isUser: Bool

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }

            Text(text)
                .font(.theme.body)
                .foregroundStyle(isUser ? Color.theme.onAccent : Color.theme.textPrimary)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(isUser ? Color.theme.accent : Color.theme.surface)
                .clipShape(
                    .rect(
                        topLeadingRadius: Radius.lg,
                        bottomLeadingRadius: isUser ? Radius.lg : 4,
                        bottomTrailingRadius: isUser ? 4 : Radius.lg,
                        topTrailingRadius: Radius.lg
                    )
                )

            if !isUser { Spacer(minLength: 40) }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ChatBubble(text: "Where is my blue T-shirt?", isUser: true)
        ChatBubble(text: "Your blue T-shirt is in the 3rd drawer.", isUser: false)
    }
    .padding()
    .background(Color.theme.background)
}
```

---

### Step 4.8 — Badge / Pill (Status Indicators)

Used for things like "Found across 2 conversations" or topic tags.

```swift
struct ThemeBadge: View {
    let text: String
    var icon: String? = nil
    var role: Role = .accent

    enum Role {
        case accent, success, warning, danger, neutral

        var color: Color {
            switch self {
            case .accent: return Color.theme.accent
            case .success: return Color.theme.success
            case .warning: return Color.theme.warning
            case .danger: return Color.theme.danger
            case .neutral: return Color.theme.textSecondary
            }
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
            }
            Text(text)
                .font(.theme.caption)
        }
        .foregroundStyle(role.color)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 4)
        .background(role.color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
    }
}

#Preview {
    VStack(spacing: 8) {
        ThemeBadge(text: "Found across 2 conversations", icon: "sparkles", role: .accent)
        ThemeBadge(text: "Saved", icon: "checkmark", role: .success)
        ThemeBadge(text: "Out of scope", icon: "exclamationmark.triangle", role: .warning)
    }
}
```

---

## Part 5 — Project File Structure

Organize all theme files under one clear folder so they're easy to find:

```
MindMapper/
└── Core/
    └── Theme/
        ├── Color+Theme.swift          ← semantic color tokens
        ├── Font+Theme.swift           ← semantic typography tokens
        ├── TextStyles.swift           ← reusable text view modifiers
        ├── Spacing.swift              ← spacing & radius tokens
        └── Components/
            ├── PrimaryButton.swift
            ├── SecondaryButton.swift
            ├── GhostButton.swift
            ├── DestructiveButton.swift
            ├── ThemeCard.swift
            ├── ThemeTextField.swift
            ├── ChatBubble.swift
            └── ThemeBadge.swift
```

---

## Part 6 — Rules to Follow While Coding

Keep this checklist visible while building screens:

| ✅ Do | ❌ Don't |
|---|---|
| `Color.theme.accent` | `Color(hex: "#3478F6")` typed directly in a view |
| `Font.theme.headline` | `.font(.system(size: 17, weight: .semibold))` typed directly in a view |
| `Spacing.lg` | `.padding(16)` typed directly in a view |
| `PrimaryButton(title: "Save", action: {})` | A custom one-off `Button` styled inline |
| One `PrimaryButton` per screen | Multiple filled accent buttons competing for attention |
| Add new tokens to `Theme` files when a new need arises | Add a "just this once" raw color/font for a single screen |

> **The "one place" test:** Before shipping a screen, ask — "If I had to change this app's accent color from blue to purple right now, would it just work by editing one line in `Color+Theme.swift`?" If the answer is no, find the raw value and replace it with a token.

---

## Part 7 — Testing Dark Mode While Building

In every SwiftUI `#Preview`, test both modes side by side:

```swift
#Preview("Light") {
    ChatBubble(text: "Hello", isUser: false)
        .padding()
        .background(Color.theme.background)
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    ChatBubble(text: "Hello", isUser: false)
        .padding()
        .background(Color.theme.background)
        .preferredColorScheme(.dark)
}
```

Xcode shows both previews simultaneously in the canvas — catch contrast issues before running on a device.

You can also toggle the whole simulator's appearance live: **Settings app → Developer → Dark Appearance**, or in Xcode's canvas, the sun/moon icon in the preview toolbar.

---

## Summary

| Layer | File | What it controls |
|---|---|---|
| Colors | `Color+Theme.swift` + Asset Catalog | All colors in the app, light/dark automatic |
| Typography | `Font+Theme.swift` | All font sizes/weights |
| Text styles | `TextStyles.swift` | Combined font + color shortcuts |
| Spacing | `Spacing.swift` | All padding, gaps, corner radii |
| Components | `Core/Theme/Components/` | Every reusable button, card, badge, input |

Once this system is in place, building any new screen becomes assembly — pick the right components, pass them text and actions, and the entire visual language (colors, fonts, spacing, dark mode) comes along automatically and consistently.
