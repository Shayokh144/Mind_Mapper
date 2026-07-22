import SwiftUI

/// Press feedback that never washes out filled-button label colors.
/// Filled: darken slightly. Outline: slight opacity only.
struct ThemePressButtonStyle: ButtonStyle {
    var filled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(filled && configuration.isPressed ? -0.12 : 0)
            .opacity(!filled && configuration.isPressed ? 0.72 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
