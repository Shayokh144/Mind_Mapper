import Foundation

enum ReminderRecurrence: String, Codable, Equatable, Sendable, CaseIterable {
    case once
    case daily
    case weekly
    case monthly
}

nonisolated struct Reminder: Equatable, Identifiable, Sendable {
    var id: String
    var userId: String
    var memoryId: String?
    var sessionId: String?
    var title: String
    var body: String
    var fireAt: Date
    var recurrence: ReminderRecurrence
    var notificationId: String
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        userId: String,
        memoryId: String? = nil,
        sessionId: String? = nil,
        title: String,
        body: String,
        fireAt: Date,
        recurrence: ReminderRecurrence,
        notificationId: String = UUID().uuidString,
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.memoryId = memoryId
        self.sessionId = sessionId
        self.title = title
        self.body = body
        self.fireAt = fireAt
        self.recurrence = recurrence
        self.notificationId = notificationId
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct ReminderProposal: Equatable, Sendable {
    let shouldSetNotification: Bool
    let title: String?
    let description: String?
    let fireAt: Date?
    let recurrence: ReminderRecurrence?
}

struct SaveMemoryResult: Equatable, Sendable {
    let ackText: String
    let memoryId: String
    let reminderProposal: ReminderProposal?
}

enum ReminderValidation {
    static let minimumLead: TimeInterval = 60

    static func isFireAtValid(_ fireAt: Date, now: Date = Date()) -> Bool {
        fireAt.timeIntervalSince(now) >= minimumLead
    }
}

enum ReminderDateParser {
    static func parse(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: trimmed) { return date }

        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: trimmed) { return date }

        let local = DateFormatter()
        local.calendar = Calendar.current
        local.locale = Locale(identifier: "en_US_POSIX")
        local.timeZone = TimeZone.current
        local.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return local.date(from: trimmed)
    }
}
