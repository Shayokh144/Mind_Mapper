import Combine
import Foundation

struct ReminderDisplayModel: Identifiable, Equatable {
    let id: String
    let title: String
    let timeText: String
    let recurrenceText: String
    let isPast: Bool
}

@MainActor
final class RemindersListViewModel: ObservableObject {
    @Published private(set) var reminders: [ReminderDisplayModel] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let userId: String
    private let reminderRepository: ReminderRepositoryProtocol
    private let deleteReminderUseCase: DeleteReminderUseCaseProtocol
    private let router: AppRouter
    private var reminderById: [String: Reminder] = [:]

    init(
        userId: String,
        reminderRepository: ReminderRepositoryProtocol,
        deleteReminderUseCase: DeleteReminderUseCaseProtocol,
        router: AppRouter
    ) {
        self.userId = userId
        self.reminderRepository = reminderRepository
        self.deleteReminderUseCase = deleteReminderUseCase
        self.router = router
    }

    func loadReminders() async {
        isLoading = reminders.isEmpty
        errorMessage = nil
        defer { isLoading = false }
        do {
            let stored = try await reminderRepository.fetchAll(for: userId)
            reminderById = Dictionary(uniqueKeysWithValues: stored.map { ($0.id, $0) })
            reminders = stored.map { Self.displayModel(from: $0) }
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = AppError.loadFailed(underlying: error).errorDescription
        }
    }

    func addReminder() {
        router.present(.reminderEditor(.blank()))
    }

    func editReminder(id: String) {
        guard let reminder = reminderById[id] else { return }
        router.present(.reminderEditor(.fromReminder(reminder)))
    }

    func deleteReminder(id: String) async {
        do {
            try await deleteReminderUseCase.execute(id: id)
            await loadReminders()
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = AppError.saveFailed(underlying: error).errorDescription
        }
    }

    private static func displayModel(from reminder: Reminder) -> ReminderDisplayModel {
        ReminderDisplayModel(
            id: reminder.id,
            title: reminder.title,
            timeText: fireAtFormatter.string(from: reminder.fireAt),
            recurrenceText: L10n.Reminders.recurrenceTitle(reminder.recurrence),
            isPast: reminder.fireAt < Date() && reminder.recurrence == .once
        )
    }

    private static let fireAtFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
