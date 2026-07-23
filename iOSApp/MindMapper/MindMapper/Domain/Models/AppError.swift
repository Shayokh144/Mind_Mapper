import Foundation

enum AppError: LocalizedError {
    // Input validation
    case inputTooLong
    case inputOutOfScope(reason: String)
    case rateLimitExceeded(retryAfter: TimeInterval)

    // LLM errors
    case llmCallFailed(underlying: Error)
    case llmResponseInvalid
    case llmContextWindowExceeded

    // Data errors
    case saveFailed(underlying: Error)
    case loadFailed(underlying: Error)
    case notFound(entityType: String, id: String)
    case embeddingFailed

    // Auth errors
    case notAuthenticated
    case sessionExpired
    case invalidCredentials
    case emailConfirmationRequired
    case authFailed(underlying: Error)

    var errorDescription: String? {
        inputErrorDescription
            ?? authErrorDescription
            ?? dataErrorDescription
            ?? llmErrorDescription
            ?? "Something went wrong. Please try again."
    }

    var isRetryable: Bool {
        switch self {
        case .llmCallFailed, .saveFailed, .loadFailed, .embeddingFailed, .authFailed:
            return true
        default:
            return false
        }
    }

    // MARK: - Description helpers (keeps cyclomatic complexity low)

    private var inputErrorDescription: String? {
        switch self {
        case .inputTooLong:
            return "Please keep messages under 500 characters."
        case .inputOutOfScope(let reason):
            return reason
        case .rateLimitExceeded(let seconds):
            return "Please wait \(Int(seconds)) seconds before sending another message."
        default:
            return nil
        }
    }

    private var authErrorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to continue."
        case .sessionExpired:
            return "Your session expired. Please sign in again."
        case .invalidCredentials:
            return "Incorrect email or password."
        case .emailConfirmationRequired:
            return "Check your email to confirm your account, then sign in."
        case .authFailed:
            return "Couldn't sign in. Please try again."
        default:
            return nil
        }
    }

    private var dataErrorDescription: String? {
        switch self {
        case .notFound(let type, _):
            return "Could not find \(type). It may have been deleted."
        case .saveFailed, .loadFailed:
            return "Couldn't update local data. Please try again."
        case .embeddingFailed:
            return "Something went wrong. Please try again."
        default:
            return nil
        }
    }

    private var llmErrorDescription: String? {
        switch self {
        case .llmCallFailed:
            return "Couldn't reach the AI. Check your connection and try again."
        case .llmResponseInvalid, .llmContextWindowExceeded:
            return "Something went wrong. Please try again."
        default:
            return nil
        }
    }
}
