import Foundation

protocol DeleteSessionUseCaseProtocol: Sendable {
    func execute(sessionId: String) async throws
}

/// Deletes a session and all dependent rows in FK-safe order (single write transaction).
nonisolated struct DeleteSessionUseCase: DeleteSessionUseCaseProtocol {
    private let sessionRepository: SessionRepositoryProtocol
    private let reminderRepository: ReminderRepositoryProtocol
    private let notificationService: LocalNotificationServiceProtocol

    init(
        sessionRepository: SessionRepositoryProtocol,
        reminderRepository: ReminderRepositoryProtocol,
        notificationService: LocalNotificationServiceProtocol
    ) {
        self.sessionRepository = sessionRepository
        self.reminderRepository = reminderRepository
        self.notificationService = notificationService
    }

    func execute(sessionId: String) async throws {
        let reminders = try await reminderRepository.fetchAll(sessionId: sessionId)
        for reminder in reminders {
            notificationService.cancel(notificationId: reminder.notificationId)
        }
        try await sessionRepository.deleteCascade(id: sessionId)
    }
}
