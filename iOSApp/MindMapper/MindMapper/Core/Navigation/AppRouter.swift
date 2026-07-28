import Foundation
import SwiftUI
import Combine

/// Typed navigation source of truth for `NavigationStack` (expanded in task 16).
@MainActor
final class AppRouter: ObservableObject {
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

    func present(_ sheet: Sheet) {
        presentedSheet = sheet
    }

    func dismissSheet() {
        presentedSheet = nil
    }
}
