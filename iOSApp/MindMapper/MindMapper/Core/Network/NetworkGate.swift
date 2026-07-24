import Foundation

enum NetworkGate {
    /// Throws `AppError.noInternet` when the path is not `.connected`.
    @MainActor
    static func requireConnection(_ reachability: NetworkReachabilityProtocol) throws {
        guard reachability.isConnected else {
            throw AppError.noInternet
        }
    }
}
