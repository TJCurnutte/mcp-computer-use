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
    private static var hasRequestedPythonAccessibility = false
    private static var hasRequestedPythonScreenRecording = false

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

    // MARK: - Python Interpreter Permissions

    /// The Python interpreter that actually runs the mcp-computer-use server.
    private func pythonExecutableURL() -> URL {
        if let envPath = ProcessInfo.processInfo.environment["MCP_SERVER_ROOT"],
           !envPath.isEmpty,
           FileManager.default.fileExists(atPath: envPath) {
            let venv = URL(fileURLWithPath: envPath).appendingPathComponent(".venv/bin/python")
            if FileManager.default.fileExists(atPath: venv.path) {
                return venv
            }
        }
        let defaultVenv = URL(fileURLWithPath: "/Users/curnutte/CascadeProjects/mcp-computer-use")
            .appendingPathComponent(".venv/bin/python")
        if FileManager.default.fileExists(atPath: defaultVenv.path) {
            return defaultVenv
        }
        return URL(fileURLWithPath: "/usr/bin/python3")
    }

    private func repoURL() -> URL {
        if let envPath = ProcessInfo.processInfo.environment["MCP_SERVER_ROOT"],
           !envPath.isEmpty,
           FileManager.default.fileExists(atPath: envPath) {
            return URL(fileURLWithPath: envPath)
        }
        return URL(fileURLWithPath: "/Users/curnutte/CascadeProjects/mcp-computer-use")
    }

    private func runPythonPermissionProbe() -> (accessibility: Bool, screenRecording: Bool) {
        let script = """
        import json
        try:
            import ApplicationServices
            opts = {ApplicationServices.kAXTrustedCheckOptionPrompt: False}
            accessibility = bool(ApplicationServices.AXIsProcessTrustedWithOptions(opts))
        except Exception:
            accessibility = False
        try:
            import Quartz
            screen_recording = bool(Quartz.CGPreflightScreenCaptureAccess())
        except Exception:
            screen_recording = False
        print(json.dumps({"accessibility": accessibility, "screen_recording": screen_recording}))
        """

        let process = Process()
        process.executableURL = pythonExecutableURL()
        process.arguments = ["-c", script]
        process.currentDirectoryURL = repoURL()

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            Logger.shared.log("Python permission probe failed to run: \(error)")
            return (false, false)
        }

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        if let err = String(data: errData, encoding: .utf8), !err.isEmpty {
            Logger.shared.log("Python permission probe stderr: \(err)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: outData) as? [String: Bool] else {
            Logger.shared.log("Python permission probe returned invalid JSON")
            return (false, false)
        }
        return (
            accessibility: json["accessibility"] ?? false,
            screenRecording: json["screen_recording"] ?? false
        )
    }

    @discardableResult
    func checkPythonAccessibility() -> Bool {
        let granted = runPythonPermissionProbe().accessibility
        Logger.shared.log("Python accessibility check: \(granted)")
        return granted
    }

    @discardableResult
    func checkPythonScreenRecording() -> Bool {
        let granted = runPythonPermissionProbe().screenRecording
        Logger.shared.log("Python screen recording check: \(granted)")
        return granted
    }

    func requestPythonAccessibility() {
        guard !Self.hasRequestedPythonAccessibility else {
            Logger.shared.log("Python accessibility request already attempted; skipping repeat prompt.")
            return
        }
        Self.hasRequestedPythonAccessibility = true
        Logger.shared.log("Requesting Python Accessibility permission (opens System Settings)")
        openSystemSettings(for: .accessibility)
    }

    func requestPythonScreenRecording() {
        guard !Self.hasRequestedPythonScreenRecording else {
            Logger.shared.log("Python screen recording request already attempted; skipping repeat prompt.")
            return
        }
        Self.hasRequestedPythonScreenRecording = true
        Logger.shared.log("Requesting Python Screen Recording permission (opens System Settings)")
        openSystemSettings(for: .screenRecording)
    }

    @discardableResult
    func checkAndRequestPythonPermissions() -> Bool {
        if !checkPythonAccessibility() { requestPythonAccessibility() }
        if !checkPythonScreenRecording() { requestPythonScreenRecording() }
        return checkPythonAccessibility() && checkPythonScreenRecording()
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
