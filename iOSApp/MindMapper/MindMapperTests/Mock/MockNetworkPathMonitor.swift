import Foundation
import Network
@testable import MindMapper

final class MockNetworkPathMonitor: NetworkPathMonitorProtocol {
    var pathUpdateHandler: ((NWPath.Status) -> Void)?
    var currentNetworkStatus: NWPath.Status
    private(set) var isStartCalled = false
    private(set) var isCancelCalled = false

    init(currentNetworkStatus: NWPath.Status = .unsatisfied) {
        self.currentNetworkStatus = currentNetworkStatus
    }

    func start(queue: DispatchQueue) {
        isStartCalled = true
        pathUpdateHandler?(currentNetworkStatus)
    }

    func cancel() {
        isCancelCalled = true
    }

    func emit(_ status: NWPath.Status) {
        currentNetworkStatus = status
        pathUpdateHandler?(status)
    }
}
