import Foundation

protocol DeleteMemoryUseCaseProtocol: Sendable {
    func execute(memoryId: String) async throws
}

/// Deletes one memory and its children. If this memory replaced an older fact
/// (`supersedes_id`), the older memory is restored to RAG visibility.
nonisolated struct DeleteMemoryUseCase: DeleteMemoryUseCaseProtocol {
    private let memoryRepository: MemoryRepositoryProtocol
    private let reminderRepository: ReminderRepositoryProtocol
    private let notificationService: LocalNotificationServiceProtocol

    init(
        memoryRepository: MemoryRepositoryProtocol,
        reminderRepository: ReminderRepositoryProtocol,
        notificationService: LocalNotificationServiceProtocol
    ) {
        self.memoryRepository = memoryRepository
        self.reminderRepository = reminderRepository
        self.notificationService = notificationService
    }

    func execute(memoryId: String) async throws {
        let reminders = try await reminderRepository.fetchAll(memoryId: memoryId)
        for reminder in reminders {
            notificationService.cancel(notificationId: reminder.notificationId)
        }
        try await memoryRepository.delete(memoryId)
    }
}
