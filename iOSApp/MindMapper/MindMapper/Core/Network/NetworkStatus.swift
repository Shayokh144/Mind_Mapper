import Foundation

/// App-facing connectivity — no `Network` / `NWPath` types.
enum NetworkStatus: Equatable {
    case undetermined
    case connected
    case disconnected
}
