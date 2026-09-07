import Foundation

/// Payload for the shared reminder editor sheet (chat confirm + Reminders tab).
struct ReminderEditorDraft: Equatable, Hashable, Identifiable {
    enum Mode: Equatable, Hashable {
        case create
        case edit(reminderId: String)
    }

    var mode: Mode
    var memoryId: String?
    var sessionId: String?
    var title: String
    var body: String
    var fireAt: Date?
    var recurrence: ReminderRecurrence?
    var notificationId: String?
    var didSelectDate: Bool
    var didSelectRecurrence: Bool

    var id: String {
        switch mode {
        case .create:
            return "create-\(memoryId ?? "manual")-\(sessionId ?? "none")"
        case let .edit(reminderId):
            return "edit-\(reminderId)"
        }
    }

    static func fromOffer(_ offer: ReminderOfferDisplayModel) -> ReminderEditorDraft {
        ReminderEditorDraft(
            mode: .create,
            memoryId: offer.memoryId,
            sessionId: offer.sessionId,
            title: offer.title ?? "",
            body: offer.description ?? "",
            fireAt: offer.fireAt,
            recurrence: offer.recurrence,
            notificationId: nil,
            didSelectDate: offer.fireAt != nil,
            didSelectRecurrence: offer.recurrence != nil
        )
    }

    static func fromReminder(_ reminder: Reminder) -> ReminderEditorDraft {
        ReminderEditorDraft(
            mode: .edit(reminderId: reminder.id),
            memoryId: reminder.memoryId,
            sessionId: reminder.sessionId,
            title: reminder.title,
            body: reminder.body,
            fireAt: reminder.fireAt,
            recurrence: reminder.recurrence,
            notificationId: reminder.notificationId,
            didSelectDate: true,
            didSelectRecurrence: true
        )
    }

    static func blank(sessionId: String? = nil) -> ReminderEditorDraft {
        ReminderEditorDraft(
            mode: .create,
            memoryId: nil,
            sessionId: sessionId,
            title: "",
            body: "",
            fireAt: nil,
            recurrence: nil,
            notificationId: nil,
            didSelectDate: false,
            didSelectRecurrence: false
        )
    }
}

struct ReminderOfferDisplayModel: Equatable, Sendable {
    let memoryId: String
    let sessionId: String
    let title: String?
    let description: String?
    let fireAt: Date?
    let recurrence: ReminderRecurrence?
}
