import Foundation

/// Local logging facade. Swap the body of these methods for Sentry (or similar) later
/// without touching call sites.
nonisolated enum AppLogger {
    nonisolated static func error(
        _ message: String,
        error: Error? = nil,
        file: String = #fileID,
        function: String = #function
    ) {
        if let error {
            NSLog(
                "[MindMapper][ERROR] %@ — %@ [%@ %@]",
                message,
                String(describing: error),
                file,
                function
            )
        } else {
            NSLog("[MindMapper][ERROR] %@ [%@ %@]", message, file, function)
        }
        // Future: SentrySDK.capture(error) / captureMessage(message)
    }

    nonisolated static func info(_ message: String) {
        NSLog("[MindMapper][INFO] %@", message)
    }

    /// Verbose diagnostics — compiled out of Release / App Store builds.
    nonisolated static func debug(_ message: String) {
        #if DEBUG
        NSLog("[MindMapper][DEBUG] %@", message)
        #endif
    }
}
