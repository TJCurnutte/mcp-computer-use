import Foundation
import Network

enum ServerState {
    case idle
    case starting
    case running(port: UInt16)
    case error(String)
}

protocol ServerManagerDelegate: AnyObject {
    func serverStateDidChange(_ state: ServerState)
}

// MARK: - ServerManager

final class ServerManager: SocketListenerDelegate, BridgeConnectionDelegate {
    weak var delegate: ServerManagerDelegate?

    private let queue = DispatchQueue(label: "com.example.MCPMenuBar.server")
    private let listener: SocketListener
    private var activeBridges: [BridgeConnection] = []
    private var isStopping = false

    init() {
        listener = SocketListener(queue: queue)
        listener.delegate = self
    }

    func start() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.isStopping = false
            self.notify(.starting)
            self.listener.start()
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.isStopping = true
            self.activeBridges.forEach { $0.stop() }
            self.activeBridges.removeAll()
            self.listener.stop()
            self.writePortFile(nil)
            self.notify(.idle)
        }
    }

    // MARK: SocketListenerDelegate

    func listenerReady(port: UInt16) {
        Logger.shared.log("Server listening on 127.0.0.1:\(port)")
        writePortFile(port)
        notify(.running(port: port))
    }

    func listenerFailed(error: Error) {
        Logger.shared.log("Listener failed: \(error.localizedDescription)")
        if !isStopping {
            listener.stop()
            writePortFile(nil)
            notify(.error(error.localizedDescription))
        }
    }

    func listenerAccepted(_ connection: NWConnection) {
        Logger.shared.log("Accepted connection")
        let bridge = BridgeConnection(connection: connection, queue: queue)
        bridge.delegate = self
        activeBridges.append(bridge)
        bridge.start()
    }

    // MARK: BridgeConnectionDelegate

    func bridgeDidStop(_ bridge: BridgeConnection) {
        queue.async { [weak self] in
            self?.activeBridges.removeAll { $0 === bridge }
        }
    }

    // MARK: Private

    private func notify(_ state: ServerState) {
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.serverStateDidChange(state)
        }
    }

    private func writePortFile(_ port: UInt16?) {
        let fm = FileManager.default
        try? fm.createDirectory(at: Paths.mcpDirectory, withIntermediateDirectories: true)
        if let port = port {
            // Foundation's atomically:true writes to a temp file and renames.
            try? "\(port)".write(to: Paths.portFile, atomically: true, encoding: .utf8)
        } else {
            try? fm.removeItem(at: Paths.portFile)
        }
    }
}

// MARK: - BridgeConnectionDelegate

protocol BridgeConnectionDelegate: AnyObject {
    func bridgeDidStop(_ bridge: BridgeConnection)
}

// MARK: - BridgeConnection

final class BridgeConnection: NSObject {
    weak var delegate: BridgeConnectionDelegate?

    private let connection: NWConnection
    private let queue: DispatchQueue
    private let stdinPipe = Pipe()
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()
    private var process: Process?
    private var isStopped = false
    private var heartbeatTimer: DispatchSourceTimer?
    private let heartbeatInterval: TimeInterval = 30
    private let heartbeatContent = Data("{\"__mcp_menubar_heartbeat\":1}\n".utf8)

    init(connection: NWConnection, queue: DispatchQueue) {
        self.connection = connection
        self.queue = queue
        super.init()
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            self?.handleConnectionState(state)
        }
        connection.start(queue: queue)
        spawnProcess()
        startReadingStdout()
        startReadingStderr()
        receiveNext()
    }

    func stop() {
        guard !isStopped else { return }
        isStopped = true

        stopHeartbeat()
        connection.cancel()
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        stdinPipe.fileHandleForWriting.closeFile()

        if let process = process, process.isRunning {
            process.terminate()
        }
        process = nil

        delegate?.bridgeDidStop(self)
    }

    // MARK: Heartbeat

    private func startHeartbeat() {
        guard heartbeatTimer == nil, !isStopped else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + heartbeatInterval, repeating: heartbeatInterval)
        timer.setEventHandler { [weak self] in
            guard let self = self, !self.isStopped else { return }
            self.connection.send(content: self.heartbeatContent, completion: .contentProcessed { [weak self] error in
                if let error = error {
                    Logger.shared.log("Heartbeat send failed: \(error.localizedDescription)")
                    self?.stop()
                }
            })
        }
        timer.resume()
        heartbeatTimer = timer
    }

    private func stopHeartbeat() {
        heartbeatTimer?.cancel()
        heartbeatTimer = nil
    }

    // MARK: Process

    private func spawnProcess() {
        let repoURL = Paths.repoRoot

        let venvPython = repoURL.appendingPathComponent(".venv/bin/python")
        let pythonURL = FileManager.default.fileExists(atPath: venvPython.path) ? venvPython : URL(fileURLWithPath: "/usr/bin/python3")

        let proc = Process()
        proc.executableURL = pythonURL
        proc.arguments = ["-m", "mcp_computer_use"]
        proc.currentDirectoryURL = repoURL
        proc.environment = [
            "PYTHONUNBUFFERED": "1",
            "MCP_LOG_LEVEL": "INFO",
            "MCP_SERVER_ROOT": repoURL.path,
            "PATH": "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/opt/homebrew/bin"
        ]
        proc.standardInput = stdinPipe
        proc.standardOutput = stdoutPipe
        proc.standardError = stderrPipe
        proc.terminationHandler = { [weak self] process in
            Logger.shared.log("Python process \(process.processIdentifier) terminated with status \(process.terminationStatus), reason \(String(describing: process.terminationReason))")
            self?.queue.async { self?.stop() }
        }
        process = proc

        do {
            try proc.run()
            Logger.shared.log("Spawned Python process \(proc.processIdentifier)")
        } catch {
            Logger.shared.log("Failed to spawn Python: \(error.localizedDescription)")
            stop()
        }
    }

    // MARK: I/O

    private func startReadingStdout() {
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            guard let self = self, !self.isStopped else { return }
            self.connection.send(content: data, completion: .contentProcessed { _ in })
        }
    }

    private func startReadingStderr() {
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let string = String(data: data, encoding: .utf8) else { return }
            Logger.shared.log("[py stderr] \(string.trimmingCharacters(in: .newlines))")
        }
    }

    private func receiveNext() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self, !self.isStopped else { return }

            if let error = error {
                Logger.shared.log("Receive error: \(error.localizedDescription)")
                self.stop()
                return
            }

            if let data = data, !data.isEmpty {
                try? self.stdinPipe.fileHandleForWriting.write(contentsOf: data)
            }

            if isComplete {
                self.stdinPipe.fileHandleForWriting.closeFile()
            } else {
                self.receiveNext()
            }
        }
    }

    private func handleConnectionState(_ state: NWConnection.State) {
        switch state {
        case .failed(let error):
            Logger.shared.log("Connection failed: \(error.localizedDescription)")
            stop()
        case .cancelled:
            stop()
        case .setup, .preparing:
            break
        case .ready:
            guard !isStopped else { return }
            Logger.shared.log("Connection ready")
            startHeartbeat()
        case .waiting(let error):
            Logger.shared.log("Connection waiting: \(error.localizedDescription)")
        @unknown default:
            break
        }
    }
}
