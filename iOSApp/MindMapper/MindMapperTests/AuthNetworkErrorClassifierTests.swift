import XCTest
import Auth
@testable import MindMapper

final class AuthNetworkErrorClassifierTests: XCTestCase {
    func test_isTransientNetworkError_notConnected() {
        let error = URLError(.notConnectedToInternet)
        XCTAssertTrue(AuthNetworkErrorClassifier.isTransientNetworkError(error))
        XCTAssertFalse(AuthNetworkErrorClassifier.isHardAuthFailure(error))
    }

    func test_isTransientNetworkError_timedOut() {
        XCTAssertTrue(
            AuthNetworkErrorClassifier.isTransientNetworkError(URLError(.timedOut))
        )
    }

    func test_isTransientNetworkError_wrappedUnderlying() {
        let underlying = URLError(.networkConnectionLost)
        let wrapped = NSError(
            domain: "Auth.HTTPClient",
            code: -1,
            userInfo: [NSUnderlyingErrorKey: underlying]
        )
        XCTAssertTrue(AuthNetworkErrorClassifier.isTransientNetworkError(wrapped))
    }

    func test_isTransientNetworkError_serverBlip() {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 503,
            httpVersion: nil,
            headerFields: nil
        )!
        let error = AuthError.api(
            message: "unavailable",
            errorCode: .unknown,
            underlyingData: Data(),
            underlyingResponse: response
        )
        XCTAssertTrue(AuthNetworkErrorClassifier.isTransientNetworkError(error))
        XCTAssertFalse(AuthNetworkErrorClassifier.isHardAuthFailure(error))
    }

    func test_isHardAuthFailure_sessionMissing() {
        XCTAssertTrue(AuthNetworkErrorClassifier.isHardAuthFailure(AuthError.sessionMissing))
        XCTAssertFalse(AuthNetworkErrorClassifier.isTransientNetworkError(AuthError.sessionMissing))
    }

    func test_isHardAuthFailure_unauthorized() {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )!
        let error = AuthError.api(
            message: "unauthorized",
            errorCode: .unknown,
            underlyingData: Data(),
            underlyingResponse: response
        )
        XCTAssertTrue(AuthNetworkErrorClassifier.isHardAuthFailure(error))
        XCTAssertFalse(AuthNetworkErrorClassifier.isTransientNetworkError(error))
    }

    func test_isHardAuthFailure_userNotFound() {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil
        )!
        let error = AuthError.api(
            message: "User not found",
            errorCode: .userNotFound,
            underlyingData: Data(),
            underlyingResponse: response
        )
        XCTAssertTrue(AuthNetworkErrorClassifier.isHardAuthFailure(error))
    }
}
