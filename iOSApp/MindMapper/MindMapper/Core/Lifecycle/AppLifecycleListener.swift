import SwiftUI
import UIKit

/// Invokes `onBackground` when the app resigns active / enters background.
/// Attach on ChatView so session close runs without navigating away.
struct AppLifecycleListener: ViewModifier {
    let onBackground: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.willResignActiveNotification
                )
            ) { _ in
                onBackground()
            }
    }
}

extension View {
    func onAppBackground(_ action: @escaping () -> Void) -> some View {
        modifier(AppLifecycleListener(onBackground: action))
    }
}
