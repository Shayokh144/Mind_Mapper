import Foundation

/// Client-facing Supabase config (publishable / anon key — safe in the app binary; RLS protects data).
/// Values mirror root `.env` (`SUPABASE_URL`, `SUPABASE_ANON_KEY`).
enum AppConfig {
    static let supabaseAnonKey = "sb_publishable_IbGanstBrZex0xRudX6Lbg_CwesZRvT"

    private static let supabaseURLString = "https://uhkiqfmziggrgxbamzoy.supabase.co"

    /// `nil` only if `supabaseURLString` is malformed.
    static var supabaseURL: URL? {
        guard let url = URL(string: supabaseURLString) else {
            AppLogger.error("AppConfig.supabaseURLString is not a valid URL")
            return nil
        }
        return url
    }
}
