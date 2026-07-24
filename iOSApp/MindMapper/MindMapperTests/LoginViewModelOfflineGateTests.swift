import XCTest
@testable import MindMapper

@MainActor
final class LoginViewModelOfflineGateTests: XCTestCase {
    func test_submit_whenDisconnected_surfacesNoInternet_andDoesNotCallAuth() async {
        let auth = MockAuthManager()
        let reachability = MockNetworkReachability(status: .disconnected)
        let sut = LoginViewModel(authManager: auth, networkReachability: reachability)
        sut.email = "user@example.com"
        sut.password = "secret1"

        await sut.submit()

        XCTAssertEqual(sut.errorMessage, AppError.noInternet.errorDescription)
        XCTAssertEqual(auth.signInCallCount, 0)
        XCTAssertEqual(auth.signUpCallCount, 0)
    }

    func test_submit_whenConnected_callsSignIn() async {
        let auth = MockAuthManager()
        let reachability = MockNetworkReachability(status: .connected)
        let sut = LoginViewModel(authManager: auth, networkReachability: reachability)
        sut.email = "user@example.com"
        sut.password = "secret1"

        await sut.submit()

        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(auth.signInCallCount, 1)
    }

    func test_networkGate_throwsWhenDisconnected() async {
        let reachability = MockNetworkReachability(status: .disconnected)
        var didThrow = false
        do {
            try NetworkGate.requireConnection(reachability)
        } catch let error as AppError {
            if case .noInternet = error { didThrow = true }
        } catch {
            XCTFail("Unexpected error \(error)")
        }
        XCTAssertTrue(didThrow)
    }

    func test_networkGate_passesWhenConnected() async throws {
        let reachability = MockNetworkReachability(status: .connected)
        try NetworkGate.requireConnection(reachability)
    }
}
