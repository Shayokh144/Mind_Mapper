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
    case passwordResetEmailSent
    case passwordsDoNotMatch
    case passwordTooShort
    case authDeepLinkFailed
    case authFailed(underlying: Error)
    case noInternet

    var errorDescription: String? {
        inputErrorDescription
            ?? authErrorDescription
            ?? dataErrorDescription
            ?? llmErrorDescription
            ?? L10n.Error.generic
    }

    var isRetryable: Bool {
        switch self {
        case .llmCallFailed, .saveFailed, .loadFailed, .embeddingFailed, .authFailed, .noInternet:
            return true
        default:
            return false
        }
    }

    // MARK: - Description helpers (keeps cyclomatic complexity low)

    private var inputErrorDescription: String? {
        switch self {
        case .inputTooLong:
            return L10n.Error.inputTooLong
        case .inputOutOfScope(let reason):
            return reason
        case .rateLimitExceeded(let seconds):
            return L10n.Error.rateLimit(seconds: Int(seconds))
        default:
            return nil
        }
    }

    private var authErrorDescription: String? {
        switch self {
        case .notAuthenticated:
            return L10n.Error.notAuthenticated
        case .sessionExpired:
            return L10n.Error.sessionExpired
        case .invalidCredentials:
            return L10n.Error.invalidCredentials
        case .emailConfirmationRequired:
            return L10n.Error.emailConfirmation
        case .passwordResetEmailSent:
            return L10n.Error.passwordResetSent
        case .passwordsDoNotMatch:
            return L10n.Error.passwordsMismatch
        case .passwordTooShort:
            return L10n.Error.passwordTooShort
        case .authDeepLinkFailed:
            return L10n.Error.authDeepLink
        case .authFailed:
            return L10n.Error.authFailed
        case .noInternet:
            return L10n.Error.noInternet
        default:
            return nil
        }
    }

    private var dataErrorDescription: String? {
        switch self {
        case .notFound(let type, _):
            return L10n.Error.notFound(entityType: type)
        case .saveFailed, .loadFailed:
            return L10n.Error.dataFailed
        case .embeddingFailed:
            return L10n.Error.generic
        default:
            return nil
        }
    }

    private var llmErrorDescription: String? {
        switch self {
        case .llmCallFailed:
            return L10n.Error.llmFailed
        case .llmResponseInvalid, .llmContextWindowExceeded:
            return L10n.Error.generic
        default:
            return nil
        }
    }
}
