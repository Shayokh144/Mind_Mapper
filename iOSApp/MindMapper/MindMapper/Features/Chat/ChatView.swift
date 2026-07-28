import SwiftUI

/// Chat shell — full bubbles / input bar land in task 18.
struct ChatView: View {
    /// Owned by this screen — SwiftUI keeps one instance for the view's lifetime.
    /// See https://developer.apple.com/documentation/swiftui/stateobject
    @StateObject private var viewModel: ChatViewModel
    @EnvironmentObject private var router: AppRouter

    init(viewModel: ChatViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            if viewModel.isLoading && viewModel.messages.isEmpty {
                ProgressView()
            } else if viewModel.messages.isEmpty {
                Text(L10n.Chat.empty)
                    .secondaryStyle()
            } else {
                List(viewModel.messages) { message in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(message.role)
                            .captionStyle()
                        Text(message.content)
                            .bodyStyle()
                    }
                    .padding(.vertical, Spacing.xs)
                }
                .listStyle(.plain)
            }

            if let errorMessage = viewModel.errorMessage {
                ThemeBadge(text: errorMessage, icon: "exclamationmark.triangle", role: .warning)
                    .padding(.horizontal, Spacing.lg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.theme.background.ignoresSafeArea())
        .navigationTitle(viewModel.currentSession?.title ?? L10n.Chat.titleFallback)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L10n.Common.done) {
                    router.navigateToRoot()
                }
            }
        }
        .task {
            await viewModel.loadSession()
        }
        .onDisappear {
            Task {
                await viewModel.closeSession()
            }
        }
        .onAppBackground {
            Task {
                await viewModel.closeSession()
            }
        }
    }
}
