// FILE: Sources/MCPMenuBar/Features/Dashboard/DashboardController.swift
import Foundation
import AppKit

final class DashboardController {
    let serverManager: ServerManager
    let permissionsManager: PermissionsManager
    weak var stateForwardDelegate: ServerManagerDelegate?

    private var currentState: ServerState = .idle
    private var isTestingBridge = false
    private var window: NSWindowController?
    var nsWindow: NSWindow? { window?.window }

    private var repoURL: URL {
        if let envPath = ProcessInfo.processInfo.environment["MCP_SERVER_ROOT"],
           !envPath.isEmpty,
           FileManager.default.fileExists(atPath: envPath) {
            return URL(fileURLWithPath: envPath)
        }
        return URL(fileURLWithPath: "/Users/curnutte/CascadeProjects/mcp-computer-use")
    }

    private var pythonURL: URL {
        let venv = repoURL.appendingPathComponent(".venv/bin/python")
        return FileManager.default.fileExists(atPath: venv.path) ? venv : URL(fileURLWithPath: "/usr/bin/python3")
    }

    private var mcpBridgeURL: URL {
        repoURL.appendingPathComponent("MacMenuBar/bridge/mcp_bridge.py")
    }

    private var testBridgeURL: URL {
        repoURL.appendingPathComponent("MacMenuBar/tests/test_bridge.py")
    }

    weak var viewController: DashboardViewController? {
        didSet {
            _ = viewController?.view
            updateUI()
        }
    }

    init(serverManager: ServerManager, permissionsManager: PermissionsManager) {
        self.serverManager = serverManager
        self.permissionsManager = permissionsManager
        serverManager.delegate = self
        refreshServerState()
    }

    func show() {
        if window == nil {
            window = DashboardWindow(controller: self)
        }
        window?.showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateUI() {
        _ = viewController?.view

        let statusText: String
        let statusColor: NSColor
        let startEnabled: Bool
        let stopEnabled: Bool

        switch currentState {
        case .idle:
            statusText = "Ready to start"
            statusColor = DashboardTheme.statusIdle
            startEnabled = true
            stopEnabled = false
        case .starting:
            statusText = "Starting bridge, please wait..."
            statusColor = DashboardTheme.statusStarting
            startEnabled = false
            stopEnabled = true
        case .running(let port):
            statusText = "Server running on port \(port)"
            statusColor = DashboardTheme.statusRunning
            startEnabled = false
            stopEnabled = true
        case .error(let message):
            statusText = "Error: \(message)"
            statusColor = DashboardTheme.statusError
            startEnabled = true
            stopEnabled = false
        }

        if isTestingBridge {
            viewController?.updateStatus(text: "Testing bridge...", color: DashboardTheme.statusStarting)
            viewController?.setStartEnabled(false)
            viewController?.setStopEnabled(false)
        } else {
            viewController?.updateStatus(text: statusText, color: statusColor)
            viewController?.setStartEnabled(startEnabled)
            viewController?.setStopEnabled(stopEnabled)
        }
    }

    private func updatePermissionStatus(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.viewController?.updatePermissionStatus(text: text)
        }
    }

    private func updateTestResult(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.viewController?.updateTestResult(text: text)
        }
    }

    private func refreshServerState() {
        if FileManager.default.fileExists(atPath: Paths.portFile.path),
           let text = try? String(contentsOf: Paths.portFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           let port = UInt16(text) {
            currentState = .running(port: port)
        } else {
            currentState = .idle
        }
        updateUI()
    }

    private func runTestBridge() {
        let process = Process()
        process.executableURL = pythonURL
        process.arguments = [testBridgeURL.path]
        process.currentDirectoryURL = repoURL

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()

            let outData = stdout.fileHandleForReading.readDataToEndOfFile()
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            let outText = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let errText = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            var result = ""
            if !outText.isEmpty {
                result += outText
            }
            if !errText.isEmpty {
                if !result.isEmpty { result += "\n\n" }
                result += "stderr:\n\(errText)"
            }
            if result.isEmpty {
                result = process.terminationStatus == 0
                    ? "Bridge test completed successfully (no output)."
                    : "Bridge test failed with exit code \(process.terminationStatus) (no output)."
            } else if process.terminationStatus != 0 {
                result += "\n\nExit code: \(process.terminationStatus)"
            }

            DispatchQueue.main.async { [weak self] in
                self?.isTestingBridge = false
                self?.updateTestResult(result)
                self?.updateUI()
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.isTestingBridge = false
                self?.updateTestResult("Failed to run bridge test: \(error.localizedDescription)")
                self?.updateUI()
            }
        }
    }

    private func bridgeConfigJSON(port: UInt16) -> String {
        // Cursor / Claude Desktop style MCP server entry pointing at the local bridge.
        let pythonPath = pythonURL.path
        let bridgePath = mcpBridgeURL.path
        let rootPath = repoURL.path

        let config: [String: Any] = [
            "mcpServers": [
                "mcp-computer-use": [
                    "command": pythonPath,
                    "args": [bridgePath],
                    "env": [
                        "MCP_SERVER_ROOT": rootPath,
                        "MCP_BRIDGE_PORT": "\(port)"
                    ]
                ]
            ]
        ]

        guard JSONSerialization.isValidJSONObject(config),
              let data = try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return """
            {
              "mcpServers": {
                "mcp-computer-use": {
                  "command": "\(pythonPath)",
                  "args": ["\(bridgePath)"],
                  "env": {
                    "MCP_SERVER_ROOT": "\(rootPath)",
                    "MCP_BRIDGE_PORT": "\(port)"
                  }
                }
              }
            }
            """
        }
        return text
    }

    func bridgeConfigSnippet() -> String {
        let port: UInt16
        if case .running(let runningPort) = currentState {
            port = runningPort
        } else if FileManager.default.fileExists(atPath: Paths.portFile.path),
                  let text = try? String(contentsOf: Paths.portFile, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  let parsed = UInt16(text) {
            port = parsed
        } else {
            port = 8765
        }
        return bridgeConfigJSON(port: port)
    }
}

extension DashboardController: ServerManagerDelegate {
    func serverStateDidChange(_ state: ServerState) {
        currentState = state
        updateUI()
        stateForwardDelegate?.serverStateDidChange(state)
    }
}

extension DashboardController: DashboardViewControllerDelegate {
    func dashboardViewControllerDidSelectStart() {
        serverManager.start()
    }

    func dashboardViewControllerDidSelectStop() {
        serverManager.stop()
    }

    func dashboardViewControllerDidSelectCheckPermissions() {
        updatePermissionStatus("Checking permissions...")

        let access = permissionsManager.checkPythonAccessibility()
        let screen = permissionsManager.checkPythonScreenRecording()

        let accessLabel = access ? "✅ Accessibility OK" : "⚠️ Accessibility needed (Python interpreter)"
        let screenLabel = screen ? "✅ Screen Recording OK" : "⚠️ Screen Recording needed (Python interpreter)"
        updatePermissionStatus("\(accessLabel), \(screenLabel)")
    }

    func dashboardViewControllerDidSelectOpenLogs() {
        NSWorkspace.shared.open(Paths.logDirectory)
    }

    func dashboardViewControllerDidSelectTestBridge() {
        viewController?.updateTestResult(text: "Testing bridge...")

        guard FileManager.default.fileExists(atPath: Paths.portFile.path) else {
            viewController?.updateTestResult(text: "Cannot test: server is not running. Start the server first.")
            updateUI()
            return
        }

        guard FileManager.default.fileExists(atPath: testBridgeURL.path) else {
            viewController?.updateTestResult(text: "Cannot test: test_bridge.py not found at \(testBridgeURL.path).")
            updateUI()
            return
        }

        isTestingBridge = true
        updateUI()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.runTestBridge()
        }
    }

    func dashboardViewControllerDidSelectCopyBridgeConfig() {
        let port: UInt16
        if case .running(let runningPort) = currentState {
            port = runningPort
        } else if FileManager.default.fileExists(atPath: Paths.portFile.path),
                  let text = try? String(contentsOf: Paths.portFile, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  let parsed = UInt16(text) {
            port = parsed
        } else {
            // Still useful to copy a template when the server is stopped.
            port = 0
        }

        let config = bridgeConfigJSON(port: port == 0 ? 8765 : port)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(config, forType: .string)

        if port == 0 {
            updateTestResult("Bridge config copied to clipboard (template port 8765).\nStart the server to get the live port, then copy again if needed.\n\n\(config)")
        } else {
            updateTestResult("Bridge config copied to clipboard (port \(port)).\n\n\(config)")
        }
    }
}