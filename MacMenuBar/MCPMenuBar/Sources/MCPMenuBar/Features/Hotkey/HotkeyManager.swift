import Carbon
import AppKit
import Foundation

/// Wraps `GlobalHotkey` and wires the hotkey to the dashboard.
///
/// The default shortcut is `Control + Option + M` (`⌃⌥M`).
/// `GlobalHotkey` prefers `Carbon` `RegisterEventHotKey`, which works without
/// any privacy permission. The `NSEvent` global fallback needs both
/// **Accessibility** and **Input Monitoring** permissions on macOS 10.15+.
final class HotkeyManager {
    static let shared = HotkeyManager()

    /// Set this from `AppDelegate` to make the hotkey open the dashboard.
    weak var dashboardController: DashboardController?

    /// Optional extra action triggered by the hotkey.
    var onTrigger: (() -> Void)?

    /// The key combination used by the hotkey.
    var keyCode: UInt16 = UInt16(kVK_ANSI_M)
    var modifiers: NSEvent.ModifierFlags = [.control, .option]

    private(set) var isRunning = false

    private let permissionsManager = PermissionsManager()
    private var hotkey: GlobalHotkey?

    // MARK: - Lifecycle

    func start() {
        stop()

        let globalAllowed = permissionsManager.checkAccessibility() && permissionsManager.checkInputMonitoring()
        let fallbackMode: GlobalHotkey.FallbackMode = globalAllowed ? .global : .local

        hotkey = GlobalHotkey(
            keyCode: keyCode,
            modifiers: modifiers,
            fallbackMode: fallbackMode,
            action: { [weak self] in self?.handleHotkey() }
        )

        isRunning = hotkey?.start() ?? false

        if !isRunning {
            Logger.shared.log("Hotkey: failed to start; requesting permissions")
            requestPermissions()
        } else if hotkey?.currentMode == .localMonitor {
            Logger.shared.log("Hotkey: local-only fallback is active; requesting permissions for global")
            requestPermissions()
        } else {
            Logger.shared.log("Hotkey: started in \(hotkey?.currentMode.description ?? "unknown") mode")
        }
    }

    func stop() {
        hotkey?.stop()
        hotkey = nil
        isRunning = false
    }

    /// Request the permissions that the `NSEvent` global monitor needs.
    func requestPermissions() {
        permissionsManager.requestAccessibility()
        permissionsManager.requestInputMonitoring()
    }

    /// Explain to users/logs why the permission is needed.
    var permissionExplanation: String {
        """
        A global hotkey using the system event monitor needs to be allowed in
        System Settings > Privacy & Security. The app may require both
        Accessibility and Input Monitoring permissions, depending on the macOS
        version and the listening API. The default Carbon `RegisterEventHotKey`
        path does not need any permission.
        """
    }

    // MARK: - Private

    private func handleHotkey() {
        Logger.shared.log("Hotkey triggered")

        WindowActivator.activateApp()

        if let dashboard = dashboardController {
            dashboard.show()
        }

        onTrigger?()
    }
}

private extension GlobalHotkey.RegistrationMode {
    var description: String {
        switch self {
        case .none:          return "none"
        case .carbon:        return "carbon"
        case .globalMonitor: return "global-monitor"
        case .localMonitor:  return "local-monitor"
        }
    }
}
