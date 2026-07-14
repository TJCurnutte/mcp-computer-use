import AppKit
import Foundation

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(AppLifecycleManager.shared.isFirstRun ? .regular : .accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    private var menuManager: MenuManager!
    private var serverManager: ServerManager!
    private var permissionsManager: PermissionsManager!
    private var dashboardController: DashboardController!
    private var onboardingController: OnboardingController!
    private var hotkeyManager: HotkeyManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.shared.log("MCPMenuBar launched")

        permissionsManager = PermissionsManager()

        serverManager = ServerManager()

        dashboardController = DashboardController(
            serverManager: serverManager,
            permissionsManager: permissionsManager
        )
        dashboardController.stateForwardDelegate = self

        onboardingController = OnboardingController(permissionsManager: permissionsManager)

        hotkeyManager = HotkeyManager.shared
        hotkeyManager.dashboardController = dashboardController
        hotkeyManager.start()

        menuManager = MenuManager(delegate: self)

        // Wire the lifecycle manager to use the real onboarding and dashboard windows.
        AppLifecycleManager.shared.onboardingWindowFactory = { [weak self] in
            self?.onboardingController?.start()
            return self?.onboardingController?.nsWindow
        }
        AppLifecycleManager.shared.dashboardWindowFactory = { [weak self] in
            self?.dashboardController?.show()
            return self?.dashboardController?.nsWindow
        }

        serverManager.start()
        AppLifecycleManager.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.stop()
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
        permissionsManager.checkAndRequest()
    }

    func menuManagerDidSelectOpenLogs() {
        NSWorkspace.shared.open(Paths.logDirectory)
    }

    func menuManagerDidSelectCopyBridgeConfig() {
        let snippet = dashboardController?.bridgeConfigSnippet() ?? ""
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippet, forType: .string)
        Logger.shared.log("Copied bridge config snippet to pasteboard")
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
