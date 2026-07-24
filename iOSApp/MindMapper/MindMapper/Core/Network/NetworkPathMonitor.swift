import Foundation
import Network

final class NetworkPathMonitor: NetworkPathMonitorProtocol {
    var pathUpdateHandler: ((NWPath.Status) -> Void)?
    private let monitor: NWPathMonitor
    private var isStarted = false

    init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            self?.pathUpdateHandler?(path.status)
        }
    }

    func start(queue: DispatchQueue) {
        guard !isStarted else { return }
        isStarted = true
        monitor.start(queue: queue)
    }

    func cancel() {
        guard isStarted else { return }
        isStarted = false
        pathUpdateHandler = nil
        monitor.pathUpdateHandler = nil
        monitor.cancel()
    }
}
