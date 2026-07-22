import SwiftUI

@main
struct MindMapperApp: App {
    /// Opens Documents/`memory.db` and runs migrations on launch (`nil` if that failed).
    private let database = DatabaseManager.shared

    var body: some Scene {
        WindowGroup {
            if database != nil {
                ContentView()
            } else {
                Text("Couldn't open local storage. Please reinstall the app.")
                    .bodyStyle()
                    .multilineTextAlignment(.center)
                    .padding(Spacing.lg)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.theme.background)
            }
        }
    }
}
