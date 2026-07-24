import Foundation
import Auth

/// Classifies auth/network failures during session restore so offline errors
/// do not wipe a still-valid local Supabase session.
enum AuthNetworkErrorClassifier {
    static func isTransientNetworkError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return isTransientURLError(urlError)
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return isTransientURLError(URLError(URLError.Code(rawValue: nsError.code)))
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return isTransientNetworkError(underlying)
        }

        if case let .api(_, _, _, response) = error as? AuthError {
            // Server blips should not force sign-out; retry when online.
            return response.statusCode >= 500
        }

        let message = String(describing: error).lowercased()
        return message.contains("not connected")
            || message.contains("network connection lost")
            || message.contains("timed out")
            || message.contains("offline")
            || message.contains("internet connection appears to be offline")
    }

    /// Failures that mean the stored credentials are no longer valid.
    static func isHardAuthFailure(_ error: Error) -> Bool {
        guard let authError = error as? AuthError else { return false }
        switch authError {
        case .sessionMissing:
            return true
        case let .api(_, errorCode, _, response):
            if response.statusCode == 401 || response.statusCode == 403 {
                return true
            }
            return Self.hardAuthErrorCodes.contains(errorCode)
        default:
            return false
        }
    }

    private static let hardAuthErrorCodes: Set<ErrorCode> = [
        .sessionNotFound,
        .sessionExpired,
        .refreshTokenNotFound,
        .refreshTokenAlreadyUsed,
        .userNotFound,
        .userBanned,
        .badJWT,
        .noAuthorization,
    ]

    private static func isTransientURLError(_ error: URLError) -> Bool {
        switch error.code {
        case .notConnectedToInternet,
             .networkConnectionLost,
             .timedOut,
             .cannotFindHost,
             .cannotConnectToHost,
             .dnsLookupFailed,
             .internationalRoamingOff,
             .dataNotAllowed,
             .secureConnectionFailed:
            return true
        default:
            return false
        }
    }
}
