import Foundation
import Combine

@MainActor
final class ReminderEditorViewModel: ObservableObject {
    @Published var title: String
    @Published var body: String
    @Published var fireAt: Date
    @Published var recurrence: ReminderRecurrence?
    @Published var didSelectDate: Bool
    @Published var didSelectRecurrence: Bool
    @Published var didAttemptSave = false
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?

    private let userId: String
    private let draft: ReminderEditorDraft
    private let scheduleReminderUseCase: ScheduleReminderUseCaseProtocol
    private let updateReminderUseCase: UpdateReminderUseCaseProtocol

    init(
        userId: String,
        draft: ReminderEditorDraft,
        scheduleReminderUseCase: ScheduleReminderUseCaseProtocol,
        updateReminderUseCase: UpdateReminderUseCaseProtocol
    ) {
        self.userId = userId
        self.draft = draft
        self.scheduleReminderUseCase = scheduleReminderUseCase
        self.updateReminderUseCase = updateReminderUseCase
        self.title = draft.title
        self.body = draft.body
        self.fireAt = draft.fireAt ?? Date().addingTimeInterval(3_600)
        self.recurrence = draft.recurrence
        self.didSelectDate = draft.didSelectDate
        self.didSelectRecurrence = draft.didSelectRecurrence
    }

    var canSave: Bool {
        isTitleValid && isBodyValid && isDateValid && isRecurrenceValid
    }

    var isTitleValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isBodyValid: Bool {
        !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isDateValid: Bool {
        didSelectDate && ReminderValidation.isFireAtValid(fireAt)
    }

    var isRecurrenceValid: Bool {
        didSelectRecurrence && recurrence != nil
    }

    var titleError: String? {
        didAttemptSave && !isTitleValid ? L10n.Reminders.titleRequired : nil
    }

    var bodyError: String? {
        didAttemptSave && !isBodyValid ? L10n.Reminders.bodyRequired : nil
    }

    var dateError: String? {
        guard didAttemptSave else { return nil }
        if !didSelectDate { return L10n.Reminders.dateRequired }
        if !ReminderValidation.isFireAtValid(fireAt) { return L10n.Reminders.dateMustBeFuture }
        return nil
    }

    var recurrenceError: String? {
        didAttemptSave && !isRecurrenceValid ? L10n.Reminders.recurrenceRequired : nil
    }

    func pickDate() {
        didSelectDate = true
        if fireAt.timeIntervalSinceNow < ReminderValidation.minimumLead {
            fireAt = Date().addingTimeInterval(3_600)
        }
    }

    func selectRecurrence(_ value: ReminderRecurrence) {
        recurrence = value
        didSelectRecurrence = true
    }

    func save() async -> Bool {
        didAttemptSave = true
        errorMessage = nil
        guard canSave, let recurrence else { return false }

        isSaving = true
        defer { isSaving = false }

        let reminder = makeReminder(recurrence: recurrence)
        do {
            switch draft.mode {
            case .create:
                try await scheduleReminderUseCase.execute(reminder)
            case .edit:
                try await updateReminderUseCase.execute(reminder)
            }
            NotificationCenter.default.post(
                name: .reminderEditorDidFinish,
                object: nil,
                userInfo: [ReminderEditorFinishUserInfoKey.didSave: true]
            )
            return true
        } catch let error as AppError {
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = AppError.saveFailed(underlying: error).errorDescription
            return false
        }
    }

    func cancel() {
        NotificationCenter.default.post(
            name: .reminderEditorDidFinish,
            object: nil,
            userInfo: [ReminderEditorFinishUserInfoKey.didSave: false]
        )
    }

    private func makeReminder(recurrence: ReminderRecurrence) -> Reminder {
        let reminderId: String
        let notificationId: String
        switch draft.mode {
        case .create:
            reminderId = UUID().uuidString
            notificationId = UUID().uuidString
        case let .edit(existingId):
            reminderId = existingId
            notificationId = draft.notificationId ?? existingId
        }
        return Reminder(
            id: reminderId,
            userId: userId,
            memoryId: draft.memoryId,
            sessionId: draft.sessionId,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: body.trimmingCharacters(in: .whitespacesAndNewlines),
            fireAt: fireAt,
            recurrence: recurrence,
            notificationId: notificationId
        )
    }
}
