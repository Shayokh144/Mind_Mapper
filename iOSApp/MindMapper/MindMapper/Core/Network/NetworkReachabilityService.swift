import Foundation
import Combine
import Network

@MainActor
final class NetworkReachabilityService: ObservableObject, NetworkReachabilityProtocol {
    @Published private(set) var status: NetworkStatus = .undetermined

    var isConnected: Bool { status == .connected }

    private let monitor: NetworkPathMonitorProtocol
    private let queue = DispatchQueue(label: "abu.taher.com.MindMapper.network-monitor")

    init(monitor: NetworkPathMonitorProtocol = NetworkPathMonitor()) {
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] pathStatus in
            Task { @MainActor [weak self] in
                self?.apply(pathStatus)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    private func apply(_ pathStatus: NWPath.Status) {
        let next: NetworkStatus = pathStatus == .satisfied ? .connected : .disconnected
        if status != next {
            status = next
        }
    }
}
