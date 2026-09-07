import Foundation
import UserNotifications
import UIKit

/// UNUserNotificationCenter delegate — foreground banners + tap routing.
/// Not a ViewModel/use-case singleton; set once from `AppDelegate`.
final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationCenterDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        NotificationTapRouter.post(userInfo: response.notification.request.content.userInfo)
    }
}

enum NotificationTapRouter {
    static func post(userInfo: [AnyHashable: Any]) {
        let sessionId = userInfo[OpenMemoryUserInfoKey.sessionId] as? String
        let memoryId = userInfo[OpenMemoryUserInfoKey.memoryId] as? String
        if sessionId != nil || memoryId != nil {
            NotificationCenter.default.post(name: .openMemory, object: nil, userInfo: userInfo)
            return
        }
        NotificationCenter.default.post(name: .openReminder, object: nil, userInfo: userInfo)
    }
}
