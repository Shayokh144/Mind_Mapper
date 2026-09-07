import Foundation
import GRDB

nonisolated struct ReminderRecord: Codable, FetchableRecord, PersistableRecord, Equatable, Sendable {
    var id: String
    var userId: String
    var memoryId: String?
    var sessionId: String?
    var title: String
    var body: String
    var fireAt: Date
    var recurrence: String
    var notificationId: String
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    static let databaseTableName = "reminders"
    static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { GRDBSnakeCase.decoding }
    static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { GRDBSnakeCase.encoding }

    init(from reminder: Reminder) {
        id = reminder.id
        userId = reminder.userId
        memoryId = reminder.memoryId
        sessionId = reminder.sessionId
        title = reminder.title
        body = reminder.body
        fireAt = reminder.fireAt
        recurrence = reminder.recurrence.rawValue
        notificationId = reminder.notificationId
        isEnabled = reminder.isEnabled
        createdAt = reminder.createdAt
        updatedAt = reminder.updatedAt
    }

    var domainModel: Reminder {
        Reminder(
            id: id,
            userId: userId,
            memoryId: memoryId,
            sessionId: sessionId,
            title: title,
            body: body,
            fireAt: fireAt,
            recurrence: ReminderRecurrence(rawValue: recurrence) ?? .once,
            notificationId: notificationId,
            isEnabled: isEnabled,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
