import SwiftUI

struct ReminderEditorView: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel: ReminderEditorViewModel

    init(viewModel: ReminderEditorViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    titleField
                    bodyField
                    dateSection
                    recurrenceSection

                    if let errorMessage = viewModel.errorMessage {
                        ThemeBadge(text: errorMessage, icon: "xmark.circle", role: .danger)
                    }

                    PrimaryButton(
                        title: L10n.Common.save,
                        isLoading: viewModel.isSaving,
                        isEnabled: !viewModel.isSaving
                    ) {
                        Task {
                            if await viewModel.save() {
                                router.dismissSheet()
                            }
                        }
                    }
                }
                .padding(Spacing.xl)
            }
            .background(Color.theme.background.ignoresSafeArea())
            .navigationTitle(L10n.Reminders.editorTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) {
                        viewModel.cancel()
                        router.dismissSheet()
                    }
                }
            }
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(L10n.Reminders.titleLabel)
                .captionStyle()
            ThemeTextField(
                text: $viewModel.title,
                placeholder: L10n.Reminders.titlePlaceholder,
                maxLength: 80
            )
            if let titleError = viewModel.titleError {
                ThemeBadge(text: titleError, role: .danger)
            }
        }
    }

    private var bodyField: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(L10n.Reminders.bodyLabel)
                .captionStyle()
            ThemeTextField(
                text: $viewModel.body,
                placeholder: L10n.Reminders.bodyPlaceholder,
                maxLength: 200
            )
            if let bodyError = viewModel.bodyError {
                ThemeBadge(text: bodyError, role: .danger)
            }
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(L10n.Reminders.dateLabel)
                .captionStyle()
            if viewModel.didSelectDate {
                DatePicker(
                    "",
                    selection: $viewModel.fireAt,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .tint(Color.theme.accent)
            } else {
                GhostButton(title: L10n.Reminders.pickDate) {
                    viewModel.pickDate()
                }
            }
            if let dateError = viewModel.dateError {
                ThemeBadge(text: dateError, role: .danger)
            }
        }
    }

    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(L10n.Reminders.recurrenceLabel)
                .captionStyle()
            if !viewModel.didSelectRecurrence {
                Text(L10n.Reminders.recurrencePlaceholder)
                    .secondaryStyle()
            }
            HStack(spacing: Spacing.sm) {
                ForEach(ReminderRecurrence.allCases, id: \.self) { option in
                    recurrenceChip(option)
                }
            }
            if let recurrenceError = viewModel.recurrenceError {
                ThemeBadge(text: recurrenceError, role: .danger)
            }
        }
    }

    private func recurrenceChip(_ option: ReminderRecurrence) -> some View {
        let isSelected = viewModel.didSelectRecurrence && viewModel.recurrence == option
        return Button {
            viewModel.selectRecurrence(option)
        } label: {
            ThemeBadge(
                text: L10n.Reminders.recurrenceTitle(option),
                role: isSelected ? .accent : .neutral
            )
        }
        .buttonStyle(.plain)
    }
}
