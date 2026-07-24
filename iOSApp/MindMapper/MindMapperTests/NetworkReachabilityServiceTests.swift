import XCTest
import Network
@testable import MindMapper

@MainActor
final class NetworkReachabilityServiceTests: XCTestCase {
    func test_start_mapsSatisfiedToConnected() async {
        let mock = MockNetworkPathMonitor(currentNetworkStatus: .satisfied)
        let sut = NetworkReachabilityService(monitor: mock)

        await waitForStatus(sut, expected: .connected)
        XCTAssertTrue(mock.isStartCalled)
        XCTAssertTrue(sut.isConnected)
    }

    func test_start_mapsUnsatisfiedToDisconnected() async {
        let mock = MockNetworkPathMonitor(currentNetworkStatus: .unsatisfied)
        let sut = NetworkReachabilityService(monitor: mock)

        await waitForStatus(sut, expected: .disconnected)
        XCTAssertFalse(sut.isConnected)
    }

    func test_emit_updatesStatus() async {
        let mock = MockNetworkPathMonitor(currentNetworkStatus: .satisfied)
        let sut = NetworkReachabilityService(monitor: mock)
        await waitForStatus(sut, expected: .connected)

        mock.emit(.unsatisfied)
        await waitForStatus(sut, expected: .disconnected)

        mock.emit(.satisfied)
        await waitForStatus(sut, expected: .connected)
    }

    private func waitForStatus(
        _ sut: NetworkReachabilityService,
        expected: NetworkStatus
    ) async {
        for _ in 0..<50 {
            if sut.status == expected { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for status \(expected), got \(sut.status)")
    }
}
