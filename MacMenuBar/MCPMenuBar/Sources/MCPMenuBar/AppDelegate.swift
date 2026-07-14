import AppKit
import Foundation

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    private var menuManager: MenuManager!
    private var serverManager: ServerManager!
    private var permissionChecker: PermissionChecker!

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.shared.log("MCPMenuBar launched")

        permissionChecker = PermissionChecker()
        menuManager = MenuManager(delegate: self)
        serverManager = ServerManager()
        serverManager.delegate = self

        menuManager.updateStatus(text: "Idle", state: .idle)
        serverManager.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        serverManager?.stop()
        Logger.shared.log("MCPMenuBar terminating")
    }
}

extension AppDelegate: MenuManagerDelegate {
    func menuManagerDidSelectStart() {
        serverManager?.start()
    }

    func menuManagerDidSelectStop() {
        serverManager?.stop()
    }

    func menuManagerDidSelectCheckPermissions() {
        permissionChecker.checkAndRequest()
    }

    func menuManagerDidSelectOpenLogs() {
        NSWorkspace.shared.open(Paths.logDirectory)
    }

    func menuManagerDidSelectCopyBridgePath() {
        guard FileManager.default.fileExists(atPath: Paths.portFile.path),
              let text = try? String(contentsOf: Paths.portFile, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty,
              let port = UInt16(text) else {
            Logger.shared.log("No bridge port available to copy")
            return
        }
        let address = "127.0.0.1:\(port)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(address, forType: .string)
        Logger.shared.log("Copied bridge address: \(address)")
    }
}

extension AppDelegate: ServerManagerDelegate {
    func serverStateDidChange(_ state: ServerState) {
        switch state {
        case .idle:
            menuManager.updateStatus(text: "Idle", state: .idle)
        case .starting:
            menuManager.updateStatus(text: "Starting server...", state: .starting)
        case .running(let port):
            menuManager.updateStatus(text: "Running on port \(port)", state: .running)
        case .error(let message):
            menuManager.updateStatus(text: "Error: \(message)", state: .error)
        }
    }
}
