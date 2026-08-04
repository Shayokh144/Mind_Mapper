import SwiftUI

/// Authenticated app shell: Chats / Memories / Settings tabs + chat navigation stack.
struct RootView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            chatsTab
                .tabItem {
                    Label(L10n.Tab.chats, systemImage: "message.circle")
                }
                .tag(AppRouter.Tab.chats)

            NavigationStack {
                MemoryListView(sessionId: nil)
            }
            .tabItem {
                Label(L10n.Tab.memories, systemImage: "lightbulb")
            }
            .tag(AppRouter.Tab.memories)

            SettingsView(viewModel: container.makeSettingsViewModel())
                .tabItem {
                    Label(L10n.Tab.settings, systemImage: "gear")
                }
                .tag(AppRouter.Tab.settings)
        }
        .tint(Color.theme.accent)
        .onReceive(NotificationCenter.default.publisher(for: .openMemory)) { notification in
            Task {
                await handleOpenMemory(notification)
            }
        }
    }

    private var chatsTab: some View {
        NavigationStack(path: $router.path) {
            sessionListRoot
                .navigationDestination(for: AppRouter.Destination.self) { destination in
                    switch destination {
                    case let .chat(sessionId):
                        chatDestination(sessionId: sessionId)
                    case let .memoryList(sessionId):
                        MemoryListView(sessionId: sessionId)
                    case .settings:
                        SettingsView(viewModel: container.makeSettingsViewModel())
                    }
                }
        }
        .sheet(item: $router.presentedSheet) { sheet in
            switch sheet {
            case .newSession:
                NewSessionSheet()
            case let .memoryDetail(memoryId):
                MemoryDetailPlaceholder(memoryId: memoryId)
            }
        }
    }

    @ViewBuilder
    private var sessionListRoot: some View {
        if let viewModel = container.makeChatSessionListViewModel(router: router) {
            ChatSessionListView(viewModel: viewModel)
        } else {
            Text(L10n.Sessions.signInRequired)
                .bodyStyle()
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.theme.background)
        }
    }

    @ViewBuilder
    private func chatDestination(sessionId: String) -> some View {
        if let viewModel = container.makeChatViewModel(sessionId: sessionId, router: router) {
            // `.id(sessionId)` forces a new @StateObject when pushing a different chat.
            ChatView(viewModel: viewModel)
                .id(sessionId)
        } else {
            Text(L10n.Chat.signInRequired)
                .bodyStyle()
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.theme.background)
        }
    }

    private func handleOpenMemory(_ notification: Notification) async {
        if let sessionId = notification.userInfo?[OpenMemoryUserInfoKey.sessionId] as? String {
            router.openChat(sessionId: sessionId)
            return
        }

        let memoryId = (notification.userInfo?[OpenMemoryUserInfoKey.memoryId] as? String)
            ?? (notification.object as? String)
        guard let memoryId else { return }

        do {
            if let memory = try await container.memoryRepository.fetch(id: memoryId) {
                router.openChat(sessionId: memory.sessionId)
            } else {
                AppLogger.error("openMemory: no memory for id \(memoryId)")
            }
        } catch {
            AppLogger.error("openMemory: failed to resolve memory \(memoryId)", error: error)
        }
    }
}
