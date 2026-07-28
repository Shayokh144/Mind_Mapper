import SwiftUI
import UIKit

/// Invokes `onBackground` when the app enters background (not merely resigns active).
/// Prefer `didEnterBackground` over `willResignActive` so Control Center / switching to
/// Xcode does not start session-close LLM work while a chat send/retry is in flight.
struct AppLifecycleListener: ViewModifier {
    let onBackground: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIApplication.didEnterBackgroundNotification
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
