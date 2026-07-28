import SwiftUI

/// Shell list — task 17 adds display models, search, icon tiles, swipe-to-delete.
struct SessionListView: View {
    @StateObject private var viewModel: SessionListViewModel

    init(viewModel: SessionListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.sessions.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.sessions.isEmpty {
                emptyState
            } else {
                sessionList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.theme.background.ignoresSafeArea())
        .navigationTitle(L10n.Sessions.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.startNewSession() }
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Color.theme.accent)
                }
                .accessibilityLabel(L10n.Sessions.newAccessibility)
            }
        }
        .overlay(alignment: .top) {
            if let errorMessage = viewModel.errorMessage {
                ThemeBadge(text: errorMessage, icon: "xmark.circle", role: .danger)
                    .padding(Spacing.lg)
                    .onTapGesture { viewModel.errorMessage = nil }
            }
        }
        .task {
            await viewModel.loadSessions()
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "message.circle")
                .font(.theme.largeTitle)
                .foregroundStyle(Color.theme.textMuted)
            Text(L10n.Sessions.empty)
                .secondaryStyle()
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
        }
    }

    private var sessionList: some View {
        List(viewModel.sessions) { session in
            Button {
                viewModel.openSession(session)
            } label: {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(session.title ?? L10n.Common.newConversation)
                        .headlineStyle()
                    if let tag = session.topicTag {
                        Text(tag.rawValue)
                            .captionStyle()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
    }
}
