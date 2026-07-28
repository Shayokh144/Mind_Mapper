import Foundation

/// Typed accessors for `Resources/Localizable.xcstrings` (English today; add locales later).
/// Prefer `L10n.*` over string literals in Views, ViewModels, and user-facing errors.
enum L10n {
    // MARK: - Common

    enum Common {
        static var close: String { tr("common.close") }
        static var done: String { tr("common.done") }
        static var loading: String { tr("common.loading") }
        static var genericError: String { tr("common.generic_error") }
        static var newConversation: String { tr("common.new_conversation") }
    }

    enum Brand {
        static var name: String { tr("brand.name") }
    }

    // MARK: - Tabs

    enum Tab {
        static var chats: String { tr("tab.chats") }
        static var memories: String { tr("tab.memories") }
        static var settings: String { tr("tab.settings") }
    }

    // MARK: - Boot

    enum Boot {
        static var storageFailed: String { tr("boot.storage_failed") }
        static var configFailed: String { tr("boot.config_failed") }
        static var offlineBanner: String { tr("boot.offline_banner") }
    }

    // MARK: - Onboarding

    enum Onboarding {
        static var tagline: String { tr("onboarding.tagline") }
        static var featureChat: String { tr("onboarding.feature_chat") }
        static var featureRecall: String { tr("onboarding.feature_recall") }
        static var featurePrivacy: String { tr("onboarding.feature_privacy") }
        static var continueEmail: String { tr("onboarding.continue_email") }
        static var legal: String { tr("onboarding.legal") }
    }

    // MARK: - Auth

    enum Auth {
        static var welcomeBack: String { tr("auth.welcome_back") }
        static var createAccount: String { tr("auth.create_account") }
        static var signInSubtitle: String { tr("auth.sign_in_subtitle") }
        static var signUpSubtitle: String { tr("auth.sign_up_subtitle") }
        static var email: String { tr("auth.email") }
        static var password: String { tr("auth.password") }
        static var forgotPassword: String { tr("auth.forgot_password") }
        static var signIn: String { tr("auth.sign_in") }
        static var signUp: String { tr("auth.sign_up") }
        static var needAccount: String { tr("auth.need_account") }
        static var haveAccount: String { tr("auth.have_account") }
        static var resetPassword: String { tr("auth.reset_password") }
        static var resetSubtitle: String { tr("auth.reset_subtitle") }
        static var sendResetLink: String { tr("auth.send_reset_link") }
        static var chooseNewPassword: String { tr("auth.choose_new_password") }
        static var chooseNewPasswordSubtitle: String { tr("auth.choose_new_password_subtitle") }
        static var newPassword: String { tr("auth.new_password") }
        static var confirmPassword: String { tr("auth.confirm_password") }
        static var updatePassword: String { tr("auth.update_password") }
    }

    // MARK: - Settings

    enum Settings {
        static var title: String { tr("settings.title") }
        static var signOut: String { tr("settings.sign_out") }
    }

    // MARK: - Sessions

    enum Sessions {
        static var title: String { tr("sessions.title") }
        static var empty: String { tr("sessions.empty") }
        static var newAccessibility: String { tr("sessions.new_a11y") }
        static var searchPlaceholder: String { tr("sessions.search_placeholder") }
        static var loadFailed: String { tr("sessions.load_failed") }
        static var startFailed: String { tr("sessions.start_failed") }
        static var signInRequired: String { tr("sessions.sign_in_required") }
        static var deleteAction: String { tr("sessions.delete_action") }
        static var deleteTitle: String { tr("sessions.delete_title") }
        static var deleteMessage: String { tr("sessions.delete_message") }
        static var deleteConfirm: String { tr("sessions.delete_confirm") }
        static var deleteFailed: String { tr("sessions.delete_failed") }
    }

    // MARK: - Chat

    enum Chat {
        static var titleFallback: String { tr("chat.title_fallback") }
        static var empty: String { tr("chat.empty") }
        static var signInRequired: String { tr("chat.sign_in_required") }
    }

    // MARK: - Memories

    enum Memories {
        static var title: String { tr("memories.title") }
        static var chatTitle: String { tr("memories.chat_title") }
        static var all: String { tr("memories.all") }
        static var forChat: String { tr("memories.for_chat") }
        static var placeholder: String { tr("memories.placeholder") }
        static var detailTitle: String { tr("memories.detail_title") }
        static var detailPlaceholder: String { tr("memories.detail_placeholder") }
    }

    // MARK: - Sheets

    enum Sheet {
        static var newSessionBody: String { tr("sheet.new_session_body") }
    }

    // MARK: - Errors

    enum Error {
        static var inputTooLong: String { tr("error.input_too_long") }
        static var notAuthenticated: String { tr("error.not_authenticated") }
        static var sessionExpired: String { tr("error.session_expired") }
        static var invalidCredentials: String { tr("error.invalid_credentials") }
        static var emailConfirmation: String { tr("error.email_confirmation") }
        static var passwordResetSent: String { tr("error.password_reset_sent") }
        static var passwordsMismatch: String { tr("error.passwords_mismatch") }
        static var passwordTooShort: String { tr("error.password_too_short") }
        static var authDeepLink: String { tr("error.auth_deep_link") }
        static var authFailed: String { tr("error.auth_failed") }
        static var noInternet: String { tr("error.no_internet") }
        static var dataFailed: String { tr("error.data_failed") }
        static var llmFailed: String { tr("error.llm_failed") }
        static var generic: String { tr("common.generic_error") }

        static func rateLimit(seconds: Int) -> String {
            String(format: tr("error.rate_limit"), locale: .current, seconds)
        }

        static func notFound(entityType: String) -> String {
            String(format: tr("error.not_found"), locale: .current, entityType)
        }
    }

    // MARK: - Guards

    enum Guard {
        static var codeBlocked: String { tr("guard.code_blocked") }
        static var notesOnly: String { tr("guard.notes_only") }
        static var scopeBlocked: String { tr("guard.scope_blocked") }
        static var rateHourly: String { tr("guard.rate_hourly") }

        static func rateOutOfScope(seconds: Int) -> String {
            String(format: tr("guard.rate_out_of_scope"), locale: .current, seconds)
        }
    }

    // MARK: - Helper

    private static func tr(_ key: String.LocalizationValue) -> String {
        String(localized: key)
    }
}
