import Foundation
import AppKit

final class DashboardController {
    let serverManager: ServerManager
    let permissionChecker: PermissionChecker
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

    init(serverManager: ServerManager, permissionChecker: PermissionChecker) {
        self.serverManager = serverManager
        self.permissionChecker = permissionChecker
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

        let access = permissionChecker.checkAccessibility()
        let screen = permissionChecker.checkScreenRecording()

        let accessLabel = access ? "✅ Accessibility OK" : "⚠️ Accessibility needed"
        let screenLabel = screen ? "✅ Screen Recording OK" : "⚠️ Screen Recording needed"
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
        let snippet = bridgeConfigSnippet()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippet, forType: .string)
        viewController?.updateTestResult(text: "Bridge config copied to pasteboard.")
    }

    private func updatePermissionStatus(_ text: String) {
        viewController?.updatePermissionStatus(text: text)
    }

    private func runTestBridge() {
        let process = Process()
        process.executableURL = pythonURL
        process.arguments = [testBridgeURL.path]
        process.currentDirectoryURL = repoURL
        process.environment = ["PYTHONUNBUFFERED": "1"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        process.terminationHandler = { [weak self] _ in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            DispatchQueue.main.async {
                self?.isTestingBridge = false
                self?.viewController?.updateTestResult(text: output.isEmpty ? "No output" : output)
                self?.updateUI()
            }
        }

        do {
            try process.run()
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.isTestingBridge = false
                self?.viewController?.updateTestResult(text: "Failed to start test: \(error.localizedDescription)")
                self?.updateUI()
            }
        }
    }

    func bridgeConfigSnippet() -> String {
        """
        {
          "version": 1,
          "mcpServers": {
            "mcp-computer-use": {
              "command": "\(pythonURL.path)",
              "args": [
                "\(mcpBridgeURL.path)"
              ],
              "cwd": "\(repoURL.path)"
            }
          },
          "permissions": {
            "allow": [
              "mcp__*"
            ]
          }
        }
        """
    }
}
