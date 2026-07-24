import Foundation
import Network

protocol NetworkPathMonitorProtocol: AnyObject {
    var pathUpdateHandler: ((NWPath.Status) -> Void)? { get set }
    func start(queue: DispatchQueue)
    func cancel()
}
