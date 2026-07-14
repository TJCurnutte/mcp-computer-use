import Foundation
import AppKit
import ApplicationServices
import CoreGraphics
import Combine
import IOKit.hidsystem

/// The privacy permission categories MCPMenuBar depends on.
enum PermissionType: String, CaseIterable, Identifiable, Hashable {
    case accessibility
    case screenRecording
    case inputMonitoring

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .accessibility:     return "Accessibility"
        case .screenRecording:   return "Screen Recording"
        case .inputMonitoring:   return "Input Monitoring"
        }
    }

    /// System Settings > Privacy & Security anchor for this permission.
    var settingsAnchor: String {
        switch self {
        case .accessibility:     return "Privacy_Accessibility"
        case .screenRecording:   return "Privacy_ScreenCapture"
        case .inputMonitoring:   return "Privacy_ListenEvent"
        }
    }
}

/// A consumable snapshot of a single permission for the onboarding and dashboard UIs.
struct PermissionStatus: Identifiable, Hashable {
    let permissionType: PermissionType
    let isGranted: Bool
    let description: String

    var id: String { permissionType.rawValue }
}

/// Proactive TCC checks, request dialogs, and status reporting for the app.
///
/// This manager is intended to replace `PermissionChecker` without modifying it.
/// Use it from onboarding, dashboard, and the menu bar.
final class PermissionsManager: ObservableObject {
    @Published var statuses: [PermissionStatus] = []

    private var monitorTimer: Timer?

    private static var hasRequestedAccessibility = false
    private static var hasRequestedScreenRecording = false
    private static var hasRequestedInputMonitoring = false

    init() {
        refresh()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Polling

    /// Polls permission status every `interval` seconds.
    func startMonitoring(interval: TimeInterval = 1.0) {
        stopMonitoring()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    // MARK: - Status refresh

    func refresh() {
        statuses = PermissionType.allCases.map { status(for: $0) }
    }

    func status(for type: PermissionType) -> PermissionStatus {
        let granted = check(type)
        let description = granted ? "Granted" : "Not granted"
        return PermissionStatus(permissionType: type, isGranted: granted, description: description)
    }

    func allPermissionsGranted() -> Bool {
        PermissionType.allCases.allSatisfy { check($0) }
    }

    // MARK: - Accessibility

    @discardableResult
    func checkAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        let granted = AXIsProcessTrustedWithOptions(options)
        Logger.shared.log("Accessibility check: \(granted)")
        return granted
    }

    func requestAccessibility() {
        guard !Self.hasRequestedAccessibility else {
            Logger.shared.log("Accessibility request already attempted; skipping repeat prompt.")
            return
        }
        Self.hasRequestedAccessibility = true
        Logger.shared.log("Requesting Accessibility permission...")
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let granted = AXIsProcessTrustedWithOptions(options)
        Logger.shared.log("Accessibility request result: \(granted)")
        if !granted {
            openSystemSettings(for: .accessibility)
        }
        refresh()
    }

    // MARK: - Screen Recording

    @discardableResult
    func checkScreenRecording() -> Bool {
        let granted = CGPreflightScreenCaptureAccess()
        Logger.shared.log("Screen recording check: \(granted)")
        return granted
    }

    func requestScreenRecording() {
        guard !Self.hasRequestedScreenRecording else {
            Logger.shared.log("Screen recording request already attempted; skipping repeat prompt.")
            return
        }
        Self.hasRequestedScreenRecording = true
        Logger.shared.log("Requesting Screen Recording permission...")
        let granted = CGRequestScreenCaptureAccess()
        Logger.shared.log("Screen recording request result: \(granted)")
        if !granted {
            openSystemSettings(for: .screenRecording)
        }
        refresh()
    }

    // MARK: - Input Monitoring

    @discardableResult
    func checkInputMonitoring() -> Bool {
        let access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        let granted = access == kIOHIDAccessTypeGranted
        Logger.shared.log("Input monitoring check: \(access.rawValue) -> granted=\(granted)")
        return granted
    }

    func requestInputMonitoring() {
        guard !Self.hasRequestedInputMonitoring else {
            Logger.shared.log("Input monitoring request already attempted; skipping repeat prompt.")
            return
        }
        Self.hasRequestedInputMonitoring = true
        Logger.shared.log("Requesting Input Monitoring permission...")
        let granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        Logger.shared.log("Input monitoring request result: \(granted)")
        if !granted {
            openSystemSettings(for: .inputMonitoring)
        }
        refresh()
    }

    // MARK: - System Settings

    /// Opens the correct Privacy & Security pane for the given permission.
    func openSystemSettings(for type: PermissionType) {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?\(type.settingsAnchor)"
        guard let url = URL(string: urlString) else { return }
        Logger.shared.log("Opening System Settings for \(type.displayName): \(urlString)")
        NSWorkspace.shared.open(url)
    }

    // MARK: - Check + request

    @discardableResult
    func checkAndRequest() -> Bool {
        if !checkAccessibility() { requestAccessibility() }
        if !checkScreenRecording() { requestScreenRecording() }
        if !checkInputMonitoring() { requestInputMonitoring() }
        refresh()
        return allPermissionsGranted()
    }

    // MARK: - Helpers

    private func check(_ type: PermissionType) -> Bool {
        switch type {
        case .accessibility:     return checkAccessibility()
        case .screenRecording:   return checkScreenRecording()
        case .inputMonitoring:   return checkInputMonitoring()
        }
    }
}
