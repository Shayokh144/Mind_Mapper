import SwiftUI

@main
struct MindMapperApp: App {
    private let database = DatabaseManager.shared

    var body: some Scene {
        WindowGroup {
            rootContent
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if let database, let container = AppContainer.make(database: database) {
            AppRootHost(container: container)
        } else if database == nil {
            bootFailureMessage("Couldn't open local storage. Please reinstall the app.")
        } else {
            bootFailureMessage("Couldn't configure the backend. Please reinstall the app.")
        }
    }

    private func bootFailureMessage(_ text: String) -> some View {
        Text(text)
            .bodyStyle()
            .multilineTextAlignment(.center)
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.theme.background)
    }
}

/// Owns `AppContainer` for the lifetime of a successful database + config open.
private struct AppRootHost: View {
    @StateObject private var container: AppContainer
    @ObservedObject private var authManager: AuthManager

    init(container: AppContainer) {
        _container = StateObject(wrappedValue: container)
        _authManager = ObservedObject(wrappedValue: container.authManager)
    }

    var body: some View {
        Group {
            if authManager.isRestoringSession {
                ProgressView()
                    .tint(Color.theme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.theme.background)
            } else if authManager.isAuthenticated {
                RootView(viewModel: container.makeRootViewModel())
            } else {
                OnboardingView()
            }
        }
        .environmentObject(container)
        .environmentObject(authManager)
        .animation(.easeInOut, value: authManager.isAuthenticated)
        .task {
            await authManager.restoreSession()
        }
    }
}
