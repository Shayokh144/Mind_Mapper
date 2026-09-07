import Foundation

protocol ScheduleReminderUseCaseProtocol: Sendable {
    func execute(_ reminder: Reminder) async throws
}

nonisolated struct ScheduleReminderUseCase: ScheduleReminderUseCaseProtocol {
    private let reminderRepository: ReminderRepositoryProtocol
    private let notificationService: LocalNotificationServiceProtocol

    init(
        reminderRepository: ReminderRepositoryProtocol,
        notificationService: LocalNotificationServiceProtocol
    ) {
        self.reminderRepository = reminderRepository
        self.notificationService = notificationService
    }

    func execute(_ reminder: Reminder) async throws {
        guard ReminderValidation.isFireAtValid(reminder.fireAt) else {
            throw AppError.saveFailed(underlying: ReminderScheduleError.fireAtInPast)
        }
        try await reminderRepository.save(reminder)
        do {
            try await notificationService.schedule(reminder)
        } catch {
            try await reminderRepository.delete(id: reminder.id)
            throw error
        }
    }
}

enum ReminderScheduleError: Error {
    case fireAtInPast
}

protocol UpdateReminderUseCaseProtocol: Sendable {
    func execute(_ reminder: Reminder) async throws
}

nonisolated struct UpdateReminderUseCase: UpdateReminderUseCaseProtocol {
    private let reminderRepository: ReminderRepositoryProtocol
    private let notificationService: LocalNotificationServiceProtocol

    init(
        reminderRepository: ReminderRepositoryProtocol,
        notificationService: LocalNotificationServiceProtocol
    ) {
        self.reminderRepository = reminderRepository
        self.notificationService = notificationService
    }

    func execute(_ reminder: Reminder) async throws {
        guard ReminderValidation.isFireAtValid(reminder.fireAt) else {
            throw AppError.saveFailed(underlying: ReminderScheduleError.fireAtInPast)
        }
        var updated = reminder
        updated.updatedAt = Date()
        try await reminderRepository.update(updated)
        try await notificationService.reschedule(updated)
    }
}

protocol DeleteReminderUseCaseProtocol: Sendable {
    func execute(id: String) async throws
}

nonisolated struct DeleteReminderUseCase: DeleteReminderUseCaseProtocol {
    private let reminderRepository: ReminderRepositoryProtocol
    private let notificationService: LocalNotificationServiceProtocol

    init(
        reminderRepository: ReminderRepositoryProtocol,
        notificationService: LocalNotificationServiceProtocol
    ) {
        self.reminderRepository = reminderRepository
        self.notificationService = notificationService
    }

    func execute(id: String) async throws {
        guard let existing = try await reminderRepository.fetch(id: id) else {
            throw AppError.notFound(entityType: "reminder", id: id)
        }
        notificationService.cancel(notificationId: existing.notificationId)
        try await reminderRepository.delete(id: id)
    }
}
