import Foundation
@testable import MindMapper

@MainActor
final class MockNetworkReachability: NetworkReachabilityProtocol {
    var status: NetworkStatus

    var isConnected: Bool { status == .connected }

    init(status: NetworkStatus = .connected) {
        self.status = status
    }
}
