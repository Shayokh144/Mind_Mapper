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
            bootFailureMessage(L10n.Boot.storageFailed)
        } else {
            bootFailureMessage(L10n.Boot.configFailed)
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

/// Owns `AppContainer` + `AppRouter` for the lifetime of a successful database + config open.
private struct AppRootHost: View {
    @StateObject private var container: AppContainer
    @StateObject private var router: AppRouter
    @ObservedObject private var authManager: AuthManager
    @ObservedObject private var networkReachability: NetworkReachabilityService

    init(container: AppContainer) {
        _container = StateObject(wrappedValue: container)
        _router = StateObject(wrappedValue: AppRouter())
        _authManager = ObservedObject(wrappedValue: container.authManager)
        _networkReachability = ObservedObject(wrappedValue: container.networkReachability)
    }

    var body: some View {
        Group {
            if authManager.isRestoringSession {
                SessionRestoreView()
            } else if authManager.pendingPasswordReset {
                SetNewPasswordView(viewModel: container.makeSetNewPasswordViewModel())
            } else if authManager.isAuthenticated {
                RootView()
            } else {
                OnboardingView()
            }
        }
        .environmentObject(container)
        .environmentObject(router)
        .environmentObject(authManager)
        .animation(.easeInOut, value: authManager.isAuthenticated)
        .animation(.easeInOut, value: authManager.pendingPasswordReset)
        .task {
            await authManager.restoreSession()
        }
        .onChange(of: networkReachability.status) { newStatus in
            guard newStatus == .connected else { return }
            Task {
                await authManager.revalidateSessionIfNeeded()
            }
        }
        .onOpenURL { url in
            Task {
                await authManager.handleAuthCallback(url: url)
            }
        }
        .overlay(alignment: .top) {
            if networkReachability.status == .disconnected {
                ThemeBadge(
                    text: AppError.noInternet.errorDescription ?? L10n.Boot.offlineBanner,
                    icon: "wifi.slash",
                    role: .warning
                )
                .padding(Spacing.lg)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: networkReachability.status)
        .overlay(alignment: .bottom) {
            if let message = authManager.deepLinkErrorMessage {
                ThemeBadge(text: message, icon: "xmark.circle", role: .danger)
                    .padding(Spacing.lg)
                    .onTapGesture {
                        authManager.clearDeepLinkError()
                    }
            }
        }
    }
}
