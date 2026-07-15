import Foundation
import Combine

/// Manages the MCPMenuBar LaunchAgent so the app can start at login.
final class StartupManager: NSObject, ObservableObject {
    static let shared = StartupManager()

    private let label = "com.curnutte.mcp-computer-use"
    private let plistName = "com.curnutte.mcp-computer-use.plist"

    @Published private(set) var startAtLoginEnabled = false

    // MARK: - Paths

    private var launchAgentsDirectory: URL {
        Paths.home.appendingPathComponent("Library/LaunchAgents", isDirectory: true)
    }

    private var launchAgentDestination: URL {
        launchAgentsDirectory.appendingPathComponent(plistName)
    }

    // MARK: - Initialization

    override private init() {
        super.init()
        refreshStatus()
    }

    /// Refreshes the published ``startAtLoginEnabled`` flag.
    func refreshStatus() {
        startAtLoginEnabled = isRunningAtLogin()
    }

    // MARK: - State queries

    func isLaunchAgentInstalled() -> Bool {
        FileManager.default.fileExists(atPath: launchAgentDestination.path)
    }

    func isRunningAtLogin() -> Bool {
        guard isLaunchAgentInstalled() else { return false }
        return launchctl(arguments: ["list", label]) == 0
    }

    // MARK: - Install / Uninstall

    func installLaunchAgent() -> Bool {
        Logger.shared.log("Installing LaunchAgent for start-at-login...")

        do {
            try FileManager.default.createDirectory(
                at: Paths.mcpDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try FileManager.default.createDirectory(
                at: Paths.logDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try FileManager.default.createDirectory(
                at: launchAgentsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            Logger.shared.log("Failed to create directories: \(error)")
            return false
        }

        guard writeLaunchAgentPlist() else {
            Logger.shared.log("Failed to write LaunchAgent plist")
            return false
        }

        // Unload first, then load and enable.
        _ = launchctl(arguments: ["unload", launchAgentDestination.path])

        let exitCode = launchctl(arguments: ["load", "-w", launchAgentDestination.path])
        if exitCode != 0 {
            Logger.shared.log("launchctl load failed with exit code \(exitCode)")
            return false
        }

        Logger.shared.log("LaunchAgent installed and loaded")
        refreshStatus()
        return isLaunchAgentInstalled() && isRunningAtLogin()
    }

    func uninstallLaunchAgent() -> Bool {
        Logger.shared.log("Uninstalling LaunchAgent...")

        _ = launchctl(arguments: ["unload", "-w", launchAgentDestination.path])

        if FileManager.default.fileExists(atPath: launchAgentDestination.path) {
            do {
                try FileManager.default.removeItem(at: launchAgentDestination)
            } catch {
                Logger.shared.log("Failed to remove LaunchAgent plist: \(error)")
                return false
            }
        }

        Logger.shared.log("LaunchAgent uninstalled")
        refreshStatus()
        return !isLaunchAgentInstalled()
    }

    // MARK: - Menu action

    @objc func toggleStartAtLogin() -> Bool {
        let currentlyEnabled = isRunningAtLogin()
        let success = currentlyEnabled ? uninstallLaunchAgent() : installLaunchAgent()

        if success {
            Logger.shared.log("Start at login toggled to \(!currentlyEnabled)")
        } else {
            Logger.shared.log("Failed to toggle start at login")
        }

        refreshStatus()
        return success
    }

    // MARK: - Helpers

    /// Locates the source plist. Checks the app bundle first, then walks up from
    /// the executable looking for `MacMenuBar/LaunchAgent`.
    private func locateSourcePlist() -> URL? {
        // Packaged resource (if the packager copied it into Contents/Resources/LaunchAgent).
        if let resource = Bundle.main.url(
            forResource: "com.curnutte.mcp-computer-use",
            withExtension: "plist",
            subdirectory: "LaunchAgent"
        ) {
            return resource
        }

        if let resourceURL = Bundle.main.resourceURL {
            let candidate = resourceURL.appendingPathComponent("LaunchAgent/\(plistName)")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        // Walk up from the executable to find the LaunchAgent directory in the repo.
        let executableURL = Bundle.main.executableURL
            ?? URL(fileURLWithPath: ProcessInfo.processInfo.arguments.first ?? "/Applications/MCPMenuBar.app/Contents/MacOS/MCPMenuBar")
        var url = executableURL.deletingLastPathComponent()
        let root = URL(fileURLWithPath: "/")
        while url != root {
            let candidate = url.appendingPathComponent("LaunchAgent/\(plistName)")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            url = url.deletingLastPathComponent()
        }

        return nil
    }

    private func writeLaunchAgentPlist() -> Bool {
        let home = Paths.home.path
        let content: String

        if let source = locateSourcePlist(),
           let sourceContent = try? String(contentsOf: source, encoding: .utf8) {
            content = sourceContent.replacingOccurrences(of: "__HOME__", with: home)
        } else {
            content = launchAgentTemplate.replacingOccurrences(of: "__HOME__", with: home)
        }

        do {
            try content.write(to: launchAgentDestination, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: 0o644)],
                ofItemAtPath: launchAgentDestination.path
            )
            return true
        } catch {
            Logger.shared.log("Failed to write LaunchAgent plist: \(error)")
            return false
        }
    }

    @discardableResult
    private func launchctl(arguments: [String]) -> Int {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = arguments

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
        } catch {
            Logger.shared.log("Failed to run launchctl: \(error)")
            return -1
        }

        task.waitUntilExit()
        return Int(task.terminationStatus)
    }

    /// Fallback LaunchAgent plist used when the source file cannot be found at runtime.
    private let launchAgentTemplate = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.curnutte.mcp-computer-use</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/MCPMenuBar.app/Contents/MacOS/MCPMenuBar</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>MCP_SERVER_ROOT</key>
        <string>__HOME__/CascadeProjects/mcp-computer-use</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>ThrottleInterval</key>
    <integer>10</integer>
    <key>StandardOutPath</key>
    <string>__HOME__/.mcp-computer-use/logs/MCPMenuBar.out.log</string>
    <key>StandardErrorPath</key>
    <string>__HOME__/.mcp-computer-use/logs/MCPMenuBar.err.log</string>
</dict>
</plist>
"""
}
