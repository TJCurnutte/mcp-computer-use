import Foundation
import Network

protocol SocketListenerDelegate: AnyObject {
    func listenerReady(port: UInt16)
    func listenerFailed(error: Error)
    func listenerAccepted(_ connection: NWConnection)
}

final class SocketListener {
    weak var delegate: SocketListenerDelegate?

    private var nwListener: NWListener?
    private let queue: DispatchQueue
    private var isCancelled = false

    init(queue: DispatchQueue) {
        self.queue = queue
    }

    func start() {
        isCancelled = false
        do {
            let tcpOptions = NWProtocolTCP.Options()
            tcpOptions.enableKeepalive = true
            tcpOptions.keepaliveIdle = 30
            tcpOptions.keepaliveInterval = 10
            tcpOptions.keepaliveCount = 3

            let parameters = NWParameters(tls: nil, tcp: tcpOptions)
            parameters.allowLocalEndpointReuse = true
            parameters.requiredLocalEndpoint = NWEndpoint.hostPort(
                host: .ipv4(.loopback),
                port: .any
            )

            let listener = try NWListener(using: parameters)
            listener.stateUpdateHandler = { [weak self] state in
                self?.handleState(state)
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.delegate?.listenerAccepted(connection)
            }
            listener.start(queue: queue)
            nwListener = listener
        } catch {
            delegate?.listenerFailed(error: error)
        }
    }

    func stop() {
        isCancelled = true
        nwListener?.cancel()
        nwListener = nil
    }

    private func handleState(_ state: NWListener.State) {
        switch state {
        case .ready:
            let port = nwListener?.port?.rawValue ?? 0
            delegate?.listenerReady(port: port)
        case .failed(let error):
            if !isCancelled {
                delegate?.listenerFailed(error: error)
            }
        case .cancelled:
            break
        case .setup, .waiting(_):
            break
        @unknown default:
            break
        }
    }
}
