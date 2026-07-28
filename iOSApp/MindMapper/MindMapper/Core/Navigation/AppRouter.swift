import Foundation
import SwiftUI
import Combine

/// Typed navigation source of truth for `NavigationStack` + tab selection.
@MainActor
final class AppRouter: ObservableObject {
    enum Tab: Hashable {
        case chats
        case memories
        case settings
    }

    enum Destination: Hashable {
        case chat(sessionId: String)
        case memoryList(sessionId: String)
        case settings
    }

    enum Sheet: Identifiable {
        case newSession
        case memoryDetail(memoryId: String)

        var id: String {
            switch self {
            case .newSession:
                return "newSession"
            case let .memoryDetail(memoryId):
                return "memoryDetail-\(memoryId)"
            }
        }
    }

    @Published var selectedTab: Tab = .chats
    @Published var path = NavigationPath()
    @Published var presentedSheet: Sheet?

    func navigate(to destination: Destination) {
        path.append(destination)
    }

    func navigateBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func navigateToRoot() {
        path = NavigationPath()
    }

    /// Switch to Chats, clear the stack, then push chat (notification / deep link).
    func openChat(sessionId: String) {
        selectedTab = .chats
        navigateToRoot()
        navigate(to: .chat(sessionId: sessionId))
    }

    func present(_ sheet: Sheet) {
        presentedSheet = sheet
    }

    func dismissSheet() {
        presentedSheet = nil
    }
}

extension Notification.Name {
    /// Posted by the notification delegate (task 20) when the user taps a memory reminder.
    /// Prefer `userInfo["session_id"]`, or `userInfo["memory_id"]` / `object` as a memory id to resolve.
    static let openMemory = Notification.Name("com.mindmapper.openMemory")
}

enum OpenMemoryUserInfoKey {
    static let sessionId = "session_id"
    static let memoryId = "memory_id"
}
