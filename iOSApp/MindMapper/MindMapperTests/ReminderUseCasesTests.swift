import XCTest
@testable import MindMapper

final class ReminderUseCasesTests: XCTestCase {
    private var repository: MockReminderRepository!
    private var notifications: MockLocalNotificationService!
    private var reminder = Reminder(
        userId: "user-1",
        title: "Ask HR",
        body: "Leave policy",
        fireAt: Date().addingTimeInterval(3_600),
        recurrence: .once
    )

    override func setUp() {
        super.setUp()
        repository = MockReminderRepository()
        notifications = MockLocalNotificationService()
        reminder = Reminder(
            userId: "user-1",
            title: "Ask HR",
            body: "Leave policy",
            fireAt: Date().addingTimeInterval(3_600),
            recurrence: .once
        )
    }

    func test_schedule_savesThenSchedules() async throws {
        let sut = ScheduleReminderUseCase(
            reminderRepository: repository,
            notificationService: notifications
        )
        try await sut.execute(reminder)
        XCTAssertEqual(repository.reminders.count, 1)
        XCTAssertEqual(notifications.scheduled.count, 1)
        XCTAssertEqual(notifications.scheduled.first?.id, reminder.id)
    }

    func test_schedule_rejectsPastFireAt() async {
        reminder.fireAt = Date().addingTimeInterval(-120)
        let sut = ScheduleReminderUseCase(
            reminderRepository: repository,
            notificationService: notifications
        )
        do {
            try await sut.execute(reminder)
            XCTFail("Expected failure")
        } catch {
            XCTAssertTrue(repository.reminders.isEmpty)
            XCTAssertTrue(notifications.scheduled.isEmpty)
        }
    }

    func test_delete_cancelsNotificationId() async throws {
        repository.reminders = [reminder]
        let sut = DeleteReminderUseCase(
            reminderRepository: repository,
            notificationService: notifications
        )
        try await sut.execute(id: reminder.id)
        XCTAssertEqual(notifications.cancelledIds, [reminder.notificationId])
        XCTAssertTrue(repository.reminders.isEmpty)
    }

    func test_update_reschedules() async throws {
        repository.reminders = [reminder]
        var updated = reminder
        updated.title = "Ask payroll"
        let sut = UpdateReminderUseCase(
            reminderRepository: repository,
            notificationService: notifications
        )
        try await sut.execute(updated)
        XCTAssertEqual(notifications.cancelledIds, [reminder.notificationId])
        XCTAssertEqual(notifications.scheduled.last?.title, "Ask payroll")
    }
}

final class ReminderNotificationTriggerTests: XCTestCase {
    func test_once_doesNotRepeat() {
        let date = Date(timeIntervalSince1970: 1_787_000_000)
        let trigger = ReminderNotificationTriggerFactory.makeTrigger(
            fireAt: date,
            recurrence: .once,
            calendar: Calendar(identifier: .gregorian)
        )
        XCTAssertFalse(trigger.repeats)
        XCTAssertNotNil(trigger.dateComponents.year)
        XCTAssertNotNil(trigger.dateComponents.day)
    }

    func test_daily_hourMinuteOnly() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone(identifier: "UTC") ?? .current
        let date = Date(timeIntervalSince1970: 1_787_000_000)
        let trigger = ReminderNotificationTriggerFactory.makeTrigger(
            fireAt: date,
            recurrence: .daily,
            calendar: calendar
        )
        XCTAssertTrue(trigger.repeats)
        XCTAssertNil(trigger.dateComponents.year)
        XCTAssertNotNil(trigger.dateComponents.hour)
        XCTAssertNotNil(trigger.dateComponents.minute)
    }

    func test_weekly_includesWeekday() {
        let trigger = ReminderNotificationTriggerFactory.makeTrigger(
            fireAt: Date(),
            recurrence: .weekly
        )
        XCTAssertTrue(trigger.repeats)
        XCTAssertNotNil(trigger.dateComponents.weekday)
    }

    func test_monthly_includesDayOfMonth() {
        let trigger = ReminderNotificationTriggerFactory.makeTrigger(
            fireAt: Date(),
            recurrence: .monthly
        )
        XCTAssertTrue(trigger.repeats)
        XCTAssertNotNil(trigger.dateComponents.day)
        XCTAssertNil(trigger.dateComponents.month)
    }
}

@MainActor
final class ReminderEditorViewModelTests: XCTestCase {
    func test_canSave_falseUntilAllFieldsValid() async {
        let sut = makeSUT(draft: .blank())
        XCTAssertFalse(sut.canSave)

        sut.title = "Title"
        sut.body = "Body"
        XCTAssertFalse(sut.canSave)

        sut.pickDate()
        sut.fireAt = Date().addingTimeInterval(3_600)
        XCTAssertFalse(sut.canSave)

        sut.selectRecurrence(.once)
        XCTAssertTrue(sut.canSave)
    }

    func test_nullDatetimeDraft_requiresExplicitPick() async {
        let offer = ReminderOfferDisplayModel(
            memoryId: "m1",
            sessionId: "s1",
            title: "Ask HR",
            description: "Leave policy",
            fireAt: nil,
            recurrence: nil
        )
        let sut = makeSUT(draft: .fromOffer(offer))
        XCTAssertFalse(sut.didSelectDate)
        XCTAssertFalse(sut.canSave)
        sut.pickDate()
        sut.fireAt = Date().addingTimeInterval(3_600)
        sut.selectRecurrence(.once)
        XCTAssertTrue(sut.canSave)
    }

    func test_save_create_callsSchedule() async {
        let schedule = CountingSchedule()
        let sut = ReminderEditorViewModel(
            userId: "user-1",
            draft: .blank(),
            scheduleReminderUseCase: schedule,
            updateReminderUseCase: CountingUpdate()
        )
        sut.title = "Title"
        sut.body = "Body"
        sut.pickDate()
        sut.fireAt = Date().addingTimeInterval(3_600)
        sut.selectRecurrence(.weekly)
        let saved = await sut.save()
        XCTAssertTrue(saved)
        XCTAssertEqual(schedule.callCount, 1)
    }

    private func makeSUT(draft: ReminderEditorDraft) -> ReminderEditorViewModel {
        ReminderEditorViewModel(
            userId: "user-1",
            draft: draft,
            scheduleReminderUseCase: CountingSchedule(),
            updateReminderUseCase: CountingUpdate()
        )
    }
}

nonisolated final class CountingSchedule: ScheduleReminderUseCaseProtocol, @unchecked Sendable {
    private(set) var callCount = 0
    func execute(_ reminder: Reminder) async throws {
        callCount += 1
        _ = reminder
    }
}

nonisolated final class CountingUpdate: UpdateReminderUseCaseProtocol, @unchecked Sendable {
    func execute(_ reminder: Reminder) async throws {
        _ = reminder
    }
}

