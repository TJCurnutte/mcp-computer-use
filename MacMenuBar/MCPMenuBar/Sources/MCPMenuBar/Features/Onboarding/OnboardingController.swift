import AppKit
import Foundation

/// Manages the onboarding flow and responds to actions from the onboarding UI.
final class OnboardingController: ObservableObject, OnboardingDelegate {
    @Published private(set) var state: OnboardingState = .idle

    private let window: OnboardingWindow
    var nsWindow: NSWindow? { window.window }
    private let repoRoot: URL
    private let bridgeURL: URL
    private var activeTestSession: BridgeTestSession?

    init(window: OnboardingWindow? = nil, repoRoot: URL? = nil, bridgeURL: URL? = nil) {
        self.window = window ?? OnboardingWindow()
        self.repoRoot = repoRoot ?? Self.defaultRepoRoot()
        self.bridgeURL = bridgeURL ?? self.repoRoot.appendingPathComponent("MacMenuBar/bridge/mcp_bridge.py")
    }

    // MARK: - Flow

    func start() {
        Logger.shared.log("Onboarding started")
        window.onboardingDelegate = self
        transition(to: .moveToApplications)
        window.show()
    }

    func onboardingDidRequestMoveToApplications() {
        let appPath = Bundle.main.bundlePath
        if appPath == "/Applications/MCPMenuBar.app" {
            transition(to: .permissions)
        } else {
            showMoveAlert()
        }
    }

    func onboardingDidRequestPermissions() {
        let checker = PermissionChecker()
        let accessibility = checker.checkAccessibility()
        let screenRecording = checker.checkScreenRecording()
        if accessibility && screenRecording {
            transition(to: .installConfig)
        } else {
            showPermissionsAlert()
        }
    }

    func onboardingDidRequestInstallConfig() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let result = self.installConfig()
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.handleInstallConfigResult(result)
            }
        }
    }

    func onboardingDidRequestTest() {
        transition(to: .test)

        guard FileManager.default.fileExists(atPath: bridgeURL.path) else {
            showAlert("Bridge Test Failed", info: "Bridge script not found at \(bridgeURL.path)", style: .critical)
            return
        }

        activeTestSession = BridgeTestSession(bridgeURL: bridgeURL) { [weak self] status, screenshot, error in
            guard let self = self else { return }
            self.handleTestResult(status: status, screenshot: screenshot, error: error)
            self.activeTestSession = nil
        }
        activeTestSession?.start()
    }

    func onboardingDidFinish() {
        transition(to: .complete)
        Logger.shared.log("Onboarding completed")
        AppLifecycleManager.shared.completeOnboarding()
    }

    // MARK: - Helpers

    private func transition(to newState: OnboardingState) {
        DispatchQueue.main.async { [weak self] in
            self?.state = newState
        }
    }

    private static func defaultRepoRoot() -> URL {
        if let envPath = ProcessInfo.processInfo.environment["MCP_SERVER_ROOT"],
           FileManager.default.fileExists(atPath: envPath) {
            return URL(fileURLWithPath: envPath)
        }
        return URL(fileURLWithPath: "/Users/curnutte/CascadeProjects/mcp-computer-use")
    }

    // MARK: - /Applications check

    private func showMoveAlert() {
        let alert = NSAlert()
        alert.messageText = "Move to Applications"
        alert.informativeText = "MCPMenuBar must be in /Applications/MCPMenuBar.app to work correctly. Please drag it there and relaunch."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Applications")
        alert.addButton(withTitle: "OK")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications"))
        }
    }

    // MARK: - Permissions

    private func showPermissionsAlert() {
        let alert = NSAlert()
        alert.messageText = "Permissions Required"
        alert.informativeText = "MCPMenuBar needs Accessibility and Screen Recording permissions. The System Settings panes have been opened. Grant them, then click Check Permissions again."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Privacy & Security")
        alert.addButton(withTitle: "OK")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!)
        }
    }

    // MARK: - Config install

    private struct ConfigUpdateResult {
        let updated: [URL]
        let missing: [URL]
        let failed: [URL]
    }

    private enum ConfigUpdateOutcome {
        case updated
        case missing
        case failed
    }

    private func installConfig() -> ConfigUpdateResult {
        let devinURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/devin/config.json")
        let windsurfURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codeium/windsurf/mcp_config.json")

        var updated: [URL] = []
        var missing: [URL] = []
        var failed: [URL] = []

        switch updateConfig(devinURL) {
        case .updated: updated.append(devinURL)
        case .missing: missing.append(devinURL)
        case .failed: failed.append(devinURL)
        }

        switch updateConfig(windsurfURL) {
        case .updated: updated.append(windsurfURL)
        case .missing: missing.append(windsurfURL)
        case .failed: failed.append(windsurfURL)
        }

        return ConfigUpdateResult(updated: updated, missing: missing, failed: failed)
    }

    private func updateConfig(_ url: URL) -> ConfigUpdateOutcome {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return .missing }

        do {
            let data = try Data(contentsOf: url)
            guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .failed
            }

            var mcpServers = json["mcpServers"] as? [String: Any] ?? [:]
            mcpServers["mcp-computer-use"] = mcpServerEntry()
            json["mcpServers"] = mcpServers

            let outData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
            try outData.write(to: url)
            return .updated
        } catch {
            Logger.shared.log("Failed to update config at \(url.path): \(error.localizedDescription)")
            return .failed
        }
    }

    private func mcpServerEntry() -> [String: Any] {
        let bridgePath = bridgeURL.path
        let venvPython = repoRoot.appendingPathComponent(".venv/bin/python").path
        let command: String
        let args: [String]

        if FileManager.default.fileExists(atPath: venvPython) {
            command = venvPython
            args = [bridgePath]
        } else {
            command = "/usr/bin/env"
            args = ["python3", bridgePath]
        }

        return [
            "command": command,
            "args": args,
            "cwd": repoRoot.path
        ]
    }

    private func handleInstallConfigResult(_ result: ConfigUpdateResult) {
        for url in result.failed {
            showAlert("Config Update Failed", info: "Could not update \(url.path).", style: .critical)
        }

        for url in result.missing {
            showSnippet(for: url)
        }

        if !result.updated.isEmpty {
            let paths = result.updated.map { $0.path }.joined(separator: "\n")
            showAlert("Config Updated", info: "Updated:\n\(paths)")
            transition(to: .test)
        } else if result.missing.isEmpty {
            showAlert("Config Update Failed", info: "No config files were updated.", style: .critical)
        }
    }

    private func showSnippet(for url: URL) {
        let isDevin = url.pathComponents.contains("devin")
        let snippetDict: [String: Any]
        if isDevin {
            snippetDict = [
                "version": 1,
                "mcpServers": ["mcp-computer-use": mcpServerEntry()],
                "permissions": ["allow": ["mcp__*"]]
            ]
        } else {
            snippetDict = ["mcpServers": ["mcp-computer-use": mcpServerEntry()]]
        }

        guard let data = try? JSONSerialization.data(withJSONObject: snippetDict, options: [.prettyPrinted, .sortedKeys]),
              let snippet = String(data: data, encoding: .utf8) else { return }

        let alert = NSAlert()
        alert.messageText = "Create \(url.path)"
        alert.informativeText = "This file does not exist yet. Create it and paste the snippet. The snippet has been copied to your clipboard."
        alert.accessoryView = snippetTextView(snippet)
        alert.addButton(withTitle: "Copy")
        alert.addButton(withTitle: "OK")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippet, forType: .string)

        if alert.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(snippet, forType: .string)
        }
    }

    private func snippetTextView(_ snippet: String) -> NSView {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 150))
        let textView = NSTextView(frame: scrollView.bounds)
        textView.isEditable = false
        textView.isSelectable = true
        textView.string = snippet
        textView.font = NSFont.userFixedPitchFont(ofSize: 11)
        scrollView.documentView = textView
        return scrollView
    }

    // MARK: - Bridge test

    private func handleTestResult(status: String?, screenshot: String?, error: String?) {
        if let error = error, status == nil {
            showAlert("Bridge Test Failed", info: error, style: .critical)
            return
        }

        guard let statusText = status else {
            showAlert("Bridge Test Failed", info: "No response from the MCP server.", style: .critical)
            return
        }

        let statusJSON = statusText.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        guard let statusValue = statusJSON?["status"] as? String, statusValue == "ok" else {
            showAlert("Bridge Test Failed", info: "get_status did not return ok: \(statusText)", style: .critical)
            return
        }

        if let screenshotText = screenshot {
            let screenshotJSON = screenshotText.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            if screenshotJSON?["error"] != nil {
                showAlert("Bridge Test Failed", info: "screenshot returned an error: \(screenshotText)", style: .critical)
                return
            }
            if screenshotJSON?["image"] == nil {
                showAlert("Bridge Test Failed", info: "screenshot did not include an image.", style: .critical)
                return
            }
        }

        showAlert("Bridge Test Passed", info: "The MCP bridge is reachable and permissions look good.")
        transition(to: .complete)
    }

    // MARK: - General alerts

    private func showAlert(_ message: String, info: String, style: NSAlert.Style = .informational) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = info
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Bridge test session

private final class BridgeTestSession {
    private let process: Process
    private let bridgeURL: URL
    private var stdoutBuffer = Data()
    private let queue = DispatchQueue(label: "com.curnutte.MCPMenuBar.bridge-test")
    private var pending: (id: Int, semaphore: DispatchSemaphore, result: String?)?
    private var capturedError = ""
    private var completion: ((String?, String?, String?) -> Void)?

    init(bridgeURL: URL, completion: @escaping (String?, String?, String?) -> Void) {
        self.bridgeURL = bridgeURL
        process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", bridgeURL.path]
        process.standardInput = Pipe()
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        self.completion = completion
    }

    func start() {
        let stdoutPipe = process.standardOutput as? Pipe
        stdoutPipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.queue.async { self?.handleStdout(data) }
        }

        let stderrPipe = process.standardError as? Pipe
        stderrPipe?.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let self = self, !data.isEmpty, let string = String(data: data, encoding: .utf8) else { return }
            self.queue.async { self.capturedError.append(string) }
            Logger.shared.log("[BridgeTestSession stderr] \(string.trimmingCharacters(in: .newlines))")
        }

        process.terminationHandler = { [weak self] _ in
            self?.queue.async { self?.finish(status: nil, screenshot: nil, error: "Bridge process terminated before all responses were received.") }
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                try self.process.run()

                _ = self.sendRequest(
                    id: 1,
                    method: "initialize",
                    params: [
                        "protocolVersion": "2024-11-05",
                        "capabilities": [String: Any](),
                        "clientInfo": ["name": "MCPMenuBar-onboarding", "version": "1.0.0"]
                    ]
                )

                self.sendNotification(method: "notifications/initialized")

                let status = self.sendRequest(
                    id: 2,
                    method: "tools/call",
                    params: ["name": "get_status", "arguments": [String: Any]()]
                )
                let screenshot = self.sendRequest(
                    id: 3,
                    method: "tools/call",
                    params: ["name": "screenshot", "arguments": ["display": 0, "scale": true]]
                )

                self.process.terminate()
                self.finish(status: status, screenshot: screenshot, error: nil)
            } catch {
                self.finish(status: nil, screenshot: nil, error: "Failed to run bridge: \(error.localizedDescription)")
            }
        }
    }

    private func sendRequest(id: Int, method: String, params: [String: Any]) -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        var responseText: String?

        queue.sync {
            self.pending = (id: id, semaphore: semaphore, result: nil)
        }

        let request: [String: Any] = ["jsonrpc": "2.0", "id": id, "method": method, "params": params]
        guard let data = try? JSONSerialization.data(withJSONObject: request, options: []),
              let line = String(data: data, encoding: .utf8) else {
            queue.sync { self.pending = nil }
            return nil
        }

        let dataWithNewline = Data((line + "\n").utf8)
        do {
            try (process.standardInput as? Pipe)?.fileHandleForWriting.write(contentsOf: dataWithNewline)
        } catch {
            queue.sync { self.pending = nil }
            return nil
        }

        if semaphore.wait(timeout: .now() + .seconds(15)) == .timedOut {
            queue.sync { self.pending = nil }
            return nil
        }

        queue.sync {
            responseText = self.pending?.result
            self.pending = nil
        }
        return responseText
    }

    private func sendNotification(method: String, params: [String: Any] = [:]) {
        let request: [String: Any] = ["jsonrpc": "2.0", "method": method, "params": params]
        guard let data = try? JSONSerialization.data(withJSONObject: request, options: []),
              let line = String(data: data, encoding: .utf8) else { return }
        let dataWithNewline = Data((line + "\n").utf8)
        try? (process.standardInput as? Pipe)?.fileHandleForWriting.write(contentsOf: dataWithNewline)
    }

    private func handleStdout(_ data: Data) {
        stdoutBuffer.append(data)
        while let newlineIndex = stdoutBuffer.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = stdoutBuffer[..<newlineIndex]
            stdoutBuffer.removeSubrange(...newlineIndex)
            parseLine(lineData)
        }
    }

    private func parseLine(_ lineData: Data) {
        guard let json = (try? JSONSerialization.jsonObject(with: lineData, options: [])) as? [String: Any],
              let id = json["id"] as? Int,
              let pending = self.pending,
              id == pending.id else { return }

        if let error = json["error"] as? [String: Any] {
            let message = (error["message"] as? String) ?? String(describing: error)
            self.pending?.result = "ERROR: \(message)"
        } else if let result = json["result"] as? [String: Any] {
            if let content = result["content"] as? [[String: Any]],
               let first = content.first,
               let text = first["text"] as? String {
                self.pending?.result = text
            } else {
                self.pending?.result = String(data: (try? JSONSerialization.data(withJSONObject: result)) ?? Data(), encoding: .utf8)
            }
        }

        self.pending?.semaphore.signal()
    }

    private func finish(status: String? = nil, screenshot: String? = nil, error: String?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let completion = self.completion else { return }
            completion(status, screenshot, error ?? (self.capturedError.isEmpty ? nil : self.capturedError))
            self.completion = nil
            self.process.terminate()
        }
    }
}
