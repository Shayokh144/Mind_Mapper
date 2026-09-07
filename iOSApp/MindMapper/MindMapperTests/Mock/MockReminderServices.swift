import Foundation
@testable import MindMapper

nonisolated final class MockLocalNotificationService: LocalNotificationServiceProtocol, @unchecked Sendable {
    var status: NotificationAuthorizationStatus = .authorized
    var requestResult = true
    var requestError: Error?
    private(set) var scheduled: [Reminder] = []
    private(set) var cancelledIds: [String] = []
    private(set) var requestCallCount = 0

    func authorizationStatus() async -> NotificationAuthorizationStatus {
        status
    }

    func requestAuthorization() async throws -> Bool {
        requestCallCount += 1
        if let requestError { throw requestError }
        if requestResult { status = .authorized }
        return requestResult
    }

    func schedule(_ reminder: Reminder) async throws {
        scheduled.append(reminder)
    }

    func cancel(notificationId: String) {
        cancelledIds.append(notificationId)
    }

    func reschedule(_ reminder: Reminder) async throws {
        cancelledIds.append(reminder.notificationId)
        scheduled.append(reminder)
    }
}

nonisolated final class MockReminderRepository: ReminderRepositoryProtocol, @unchecked Sendable {
    var reminders: [Reminder] = []
    var saveError: Error?
    var fetchError: Error?

    func save(_ reminder: Reminder) async throws {
        if let saveError { throw saveError }
        reminders.append(reminder)
    }

    func update(_ reminder: Reminder) async throws {
        if let saveError { throw saveError }
        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[index] = reminder
        } else {
            reminders.append(reminder)
        }
    }

    func fetch(id: String) async throws -> Reminder? {
        if let fetchError { throw fetchError }
        return reminders.first { $0.id == id }
    }

    func fetchAll(for userId: String) async throws -> [Reminder] {
        if let fetchError { throw fetchError }
        return reminders.filter { $0.userId == userId }
    }

    func fetchAll(sessionId: String) async throws -> [Reminder] {
        if let fetchError { throw fetchError }
        return reminders.filter { $0.sessionId == sessionId }
    }

    func fetchAll(memoryId: String) async throws -> [Reminder] {
        if let fetchError { throw fetchError }
        return reminders.filter { $0.memoryId == memoryId }
    }

    func delete(id: String) async throws {
        if let saveError { throw saveError }
        reminders.removeAll { $0.id == id }
    }

    func deleteAll(sessionId: String) async throws {
        reminders.removeAll { $0.sessionId == sessionId }
    }

    func deleteAll(memoryId: String) async throws {
        reminders.removeAll { $0.memoryId == memoryId }
    }
}
