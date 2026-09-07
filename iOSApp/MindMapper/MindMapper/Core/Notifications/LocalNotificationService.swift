import Foundation
import UserNotifications

enum NotificationAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
}

protocol LocalNotificationServiceProtocol: Sendable {
    func authorizationStatus() async -> NotificationAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func schedule(_ reminder: Reminder) async throws
    func cancel(notificationId: String)
    func reschedule(_ reminder: Reminder) async throws
}

/// Builds calendar triggers for once / daily / weekly / monthly.
enum ReminderNotificationTriggerFactory {
    static func makeTrigger(
        fireAt: Date,
        recurrence: ReminderRecurrence,
        calendar: Calendar = .current
    ) -> UNCalendarNotificationTrigger {
        let parts = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .weekday],
            from: fireAt
        )
        var components = DateComponents()
        switch recurrence {
        case .once:
            components.year = parts.year
            components.month = parts.month
            components.day = parts.day
            components.hour = parts.hour
            components.minute = parts.minute
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        case .daily:
            components.hour = parts.hour
            components.minute = parts.minute
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        case .weekly:
            components.weekday = parts.weekday
            components.hour = parts.hour
            components.minute = parts.minute
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        case .monthly:
            // Months without this day-of-month (e.g. 31) are skipped by iOS.
            components.day = parts.day
            components.hour = parts.hour
            components.minute = parts.minute
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        }
    }
}

nonisolated struct LocalNotificationService: LocalNotificationServiceProtocol {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> NotificationAuthorizationStatus {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .provisional:
            return .provisional
        case .ephemeral:
            return .ephemeral
        @unknown default:
            return .denied
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func schedule(_ reminder: Reminder) async throws {
        guard reminder.isEnabled else {
            cancel(notificationId: reminder.notificationId)
            return
        }
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        content.userInfo = Self.userInfo(for: reminder)

        let trigger = ReminderNotificationTriggerFactory.makeTrigger(
            fireAt: reminder.fireAt,
            recurrence: reminder.recurrence
        )
        let request = UNNotificationRequest(
            identifier: reminder.notificationId,
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }

    func cancel(notificationId: String) {
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])
        center.removeDeliveredNotifications(withIdentifiers: [notificationId])
    }

    func reschedule(_ reminder: Reminder) async throws {
        cancel(notificationId: reminder.notificationId)
        try await schedule(reminder)
    }

    static func userInfo(for reminder: Reminder) -> [AnyHashable: Any] {
        var info: [String: String] = [
            OpenReminderUserInfoKey.reminderId: reminder.id,
        ]
        if let sessionId = reminder.sessionId {
            info[OpenMemoryUserInfoKey.sessionId] = sessionId
        }
        if let memoryId = reminder.memoryId {
            info[OpenMemoryUserInfoKey.memoryId] = memoryId
        }
        return info
    }
}
