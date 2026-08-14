import SwiftUI

struct ChatSessionListView: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel: ChatSessionListViewModel

    init(viewModel: ChatSessionListViewModel) {
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
            isPresented: $viewModel.isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(L10n.Sessions.deleteConfirm, role: .destructive) {
                Task { await viewModel.confirmDelete() }
            }
            Button(L10n.Common.close, role: .cancel) {
                viewModel.cancelDelete()
            }
        } message: {
            Text(L10n.Sessions.deleteMessage)
        }
        .sheet(isPresented: $viewModel.isEditSheetPresented, onDismiss: {
            viewModel.clearEditState()
        }) {
            editSessionSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        // Root stays mounted under NavigationStack — .task(id:) reloads when path
        // returns to empty after pop (plain .task would only run once).
        .task(id: router.path.count) {
            guard router.path.isEmpty else { return }
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
                ChatSessionRowView(
                    session: session,
                    onOpen: { viewModel.openSession(session) },
                    onMenuRename: { viewModel.presentEditSheet(for: session) },
                    onMenuUpdateTag: { viewModel.presentEditSheet(for: session) }
                )
                .listRowBackground(Color.theme.background)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.requestDelete(session)
                    } label: {
                        Label(L10n.Sessions.deleteAction, systemImage: "trash")
                    }
                    .tint(Color.theme.danger)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        Task { await viewModel.togglePin(session) }
                    } label: {
                        Label(
                            session.isPinned ? L10n.Sessions.unpinAction : L10n.Sessions.pinAction,
                            systemImage: session.isPinned ? "pin.slash" : "pin"
                        )
                    }
                    .tint(Color.theme.accent)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var editSessionSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(L10n.Sessions.editTitleLabel)
                        .captionStyle()
                    ThemeTextField(
                        text: $viewModel.editTitleText,
                        placeholder: L10n.Sessions.editTitlePlaceholder,
                        maxLength: ChatSessionListViewModel.maxTitleLength
                    )
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(L10n.Sessions.editTagLabel)
                        .captionStyle()
                    ThemeTextField(
                        text: $viewModel.editTagText,
                        placeholder: L10n.Sessions.editTagPlaceholder,
                        maxLength: ChatSessionListViewModel.maxTagLength
                    )
                }

                Spacer(minLength: 0)

                PrimaryButton(
                    title: L10n.Sessions.editSave,
                    isLoading: viewModel.isSavingEdit,
                    isEnabled: viewModel.canSaveEdit && !viewModel.isSavingEdit
                ) {
                    Task { await viewModel.saveEdit() }
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.theme.background.ignoresSafeArea())
            .navigationTitle(L10n.Sessions.editSheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) {
                        viewModel.cancelEdit()
                    }
                }
            }
        }
    }
}
