import SwiftUI

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
        .confirmationDialog(
            L10n.Sessions.deleteTitle,
            isPresented: Binding(
                get: { viewModel.isDeleteConfirmationPresented },
                set: { viewModel.isDeleteConfirmationPresented = $0 }
            ),
            titleVisibility: .visible
        ) {
            Button(L10n.Sessions.deleteConfirm, role: .destructive) {
                Task { await viewModel.confirmDelete() }
            }
            Button(L10n.Common.close, role: .cancel) {}
        } message: {
            Text(L10n.Sessions.deleteMessage)
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
        List {
            Section {
                ThemeTextField(
                    text: $viewModel.searchText,
                    placeholder: L10n.Sessions.searchPlaceholder,
                    maxLength: 100
                )
                .listRowInsets(EdgeInsets(
                    top: Spacing.sm,
                    leading: Spacing.lg,
                    bottom: Spacing.sm,
                    trailing: Spacing.lg
                ))
                .listRowBackground(Color.theme.background)
                .listRowSeparator(.hidden)
            }

            ForEach(viewModel.filteredSessions) { session in
                Button {
                    viewModel.openSession(session)
                } label: {
                    SessionRowView(session: session)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.theme.background)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.requestDelete(session)
                    } label: {
                        Label(L10n.Sessions.deleteAction, systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}
