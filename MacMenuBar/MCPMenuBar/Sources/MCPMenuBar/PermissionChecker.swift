import Foundation
import AppKit
import ApplicationServices
import CoreGraphics

final class PermissionChecker {
    func checkAndRequest() {
        Logger.shared.log("Checking permissions...")
        let accessibilityGranted = checkAccessibility()
        let screenRecordingGranted = checkScreenRecording()
        Logger.shared.log("Permissions — Accessibility: \(accessibilityGranted), Screen Recording: \(screenRecordingGranted)")
    }

    @discardableResult
    func checkAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        Logger.shared.log("Accessibility permission: \(trusted)")
        if !trusted {
            openSecurityPane("Privacy_Accessibility")
        }
        return trusted
    }

    @discardableResult
    func checkScreenRecording() -> Bool {
        let granted = CGPreflightScreenCaptureAccess()
        Logger.shared.log("Screen recording permission preflight: \(granted)")
        if !granted {
            CGRequestScreenCaptureAccess()
            openSecurityPane("Privacy_ScreenCapture")
        }
        return granted
    }

    private func openSecurityPane(_ anchor: String) {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?\(anchor)"
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
