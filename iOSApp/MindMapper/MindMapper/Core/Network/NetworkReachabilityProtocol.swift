import Foundation

@MainActor
protocol NetworkReachabilityProtocol: AnyObject {
    var status: NetworkStatus { get }
    var isConnected: Bool { get }
}
