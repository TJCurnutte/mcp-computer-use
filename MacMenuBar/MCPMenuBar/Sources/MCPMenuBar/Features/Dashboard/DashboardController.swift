import Foundation
import AppKit

final class DashboardController {
    let serverManager: ServerManager
    let permissionChecker: PermissionChecker
    weak var stateForwardDelegate: ServerManagerDelegate?

    private var currentState: ServerState = .idle
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

        switch currentState {
        case .idle:
            viewController?.updateStatus(text: "Idle", color: .secondaryLabelColor)
            viewController?.setStartEnabled(true)
            viewController?.setStopEnabled(false)
        case .starting:
            viewController?.updateStatus(text: "Starting...", color: .systemYellow)
            viewController?.setStartEnabled(false)
            viewController?.setStopEnabled(true)
        case .running(let port):
            viewController?.updateStatus(text: "Running on port \(port)", color: .systemGreen)
            viewController?.setStartEnabled(false)
            viewController?.setStopEnabled(true)
        case .error(let message):
            viewController?.updateStatus(text: "Error: \(message)", color: .systemRed)
            viewController?.setStartEnabled(true)
            viewController?.setStopEnabled(false)
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
        let access = permissionChecker.checkAccessibility()
        let screen = permissionChecker.checkScreenRecording()
        updatePermissionStatus(accessibility: access, screenRecording: screen)
    }

    func dashboardViewControllerDidSelectOpenLogs() {
        NSWorkspace.shared.open(Paths.logDirectory)
    }

    func dashboardViewControllerDidSelectTestBridge() {
        viewController?.updateTestResult(text: "Testing bridge...")

        guard FileManager.default.fileExists(atPath: Paths.portFile.path) else {
            viewController?.updateTestResult(text: "Cannot test: server is not running. Start the server first.")
            return
        }

        guard FileManager.default.fileExists(atPath: testBridgeURL.path) else {
            viewController?.updateTestResult(text: "Cannot test: test_bridge.py not found at \(testBridgeURL.path).")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.runTestBridge()
        }
    }

    func dashboardViewControllerDidSelectCopyBridgeConfig() {
        let snippet = bridgeConfigSnippet()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippet, forType: .string)
        viewController?.updateTestResult(text: "Devin config snippet copied to pasteboard.")
    }

    private func updatePermissionStatus(accessibility: Bool, screenRecording: Bool) {
        let accessText = accessibility ? "OK" : "Needed"
        let screenText = screenRecording ? "OK" : "Needed"
        viewController?.updatePermissionStatus(text: "Accessibility: \(accessText), Screen Recording: \(screenText)")
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
                self?.viewController?.updateTestResult(text: output.isEmpty ? "No output" : output)
            }
        }

        do {
            try process.run()
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.viewController?.updateTestResult(text: "Failed to start test: \(error.localizedDescription)")
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
