import Foundation

extension ChatViewModel {
    func declineReminderOffer() {
        pendingReminderOffer = nil
        showReminderPermissionPrePrompt = false
        showNotificationDeniedHelp = false
    }

    func acceptReminderOffer() async {
        guard pendingReminderOffer != nil else { return }
        let status = await dependencies.notificationService.authorizationStatus()
        switch status {
        case .notDetermined:
            showReminderPermissionPrePrompt = true
        case .denied:
            showNotificationDeniedHelp = true
        case .authorized, .provisional, .ephemeral:
            presentReminderEditor()
        }
    }

    func confirmReminderPermissionRequest() async {
        showReminderPermissionPrePrompt = false
        do {
            let granted = try await dependencies.notificationService.requestAuthorization()
            if granted {
                presentReminderEditor()
            } else {
                showNotificationDeniedHelp = true
            }
        } catch {
            AppLogger.error("Notification authorization request failed", error: error)
            showNotificationDeniedHelp = true
        }
    }

    func handleReminderEditorFinished(didSave: Bool) {
        pendingReminderOffer = nil
        showReminderPermissionPrePrompt = false
        if didSave {
            showNotificationDeniedHelp = false
        }
    }

    func applyReminderProposal(_ proposal: ReminderProposal?, memoryId: String) {
        guard let proposal, proposal.shouldSetNotification else {
            pendingReminderOffer = nil
            return
        }
        pendingReminderOffer = ReminderOfferDisplayModel(
            memoryId: memoryId,
            sessionId: sessionId,
            title: proposal.title,
            description: proposal.description,
            fireAt: proposal.fireAt,
            recurrence: proposal.recurrence
        )
    }

    private func presentReminderEditor() {
        guard let offer = pendingReminderOffer else { return }
        router.present(.reminderEditor(.fromOffer(offer)))
    }
}
