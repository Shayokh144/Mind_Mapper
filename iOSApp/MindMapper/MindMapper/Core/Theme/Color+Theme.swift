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

        /// Text/icons on a filled accent (or danger) background — always white.
        static let onAccent = Color.white
    }
}
