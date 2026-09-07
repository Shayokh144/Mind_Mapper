import SwiftUI

struct RemindersListView: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel: RemindersListViewModel

    init(viewModel: RemindersListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.reminders.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.reminders.isEmpty {
                emptyState
            } else {
                reminderList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.theme.background.ignoresSafeArea())
        .navigationTitle(L10n.Reminders.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.addReminder()
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Color.theme.accent)
                }
                .accessibilityLabel(L10n.Reminders.addAccessibility)
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
            await viewModel.loadReminders()
        }
        .onReceive(NotificationCenter.default.publisher(for: .reminderEditorDidFinish)) { _ in
            Task { await viewModel.loadReminders() }
        }
        .onChange(of: router.selectedTab) { tab in
            if tab == .reminders {
                Task { await viewModel.loadReminders() }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "bell")
                .font(.theme.largeTitle)
                .foregroundStyle(Color.theme.textMuted)
            Text(L10n.Reminders.empty)
                .secondaryStyle()
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
        }
    }

    private var reminderList: some View {
        List {
            ForEach(viewModel.reminders) { reminder in
                Button {
                    viewModel.editReminder(id: reminder.id)
                } label: {
                    ReminderRowView(reminder: reminder)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.theme.background)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await viewModel.deleteReminder(id: reminder.id) }
                    } label: {
                        Label(L10n.Reminders.deleteAction, systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

struct ReminderRowView: View {
    let reminder: ReminderDisplayModel

    var body: some View {
        ThemeCard {
            HStack(alignment: .center, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(reminder.title)
                        .headlineStyle()
                        .lineLimit(2)
                    Text(reminder.timeText)
                        .captionStyle()
                }
                Spacer(minLength: Spacing.sm)
                ThemeBadge(
                    text: reminder.recurrenceText,
                    role: reminder.isPast ? .neutral : .accent
                )
            }
        }
    }
}
