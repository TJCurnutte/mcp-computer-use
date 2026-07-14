import AppKit

/// Helper that activates `NSApplication` and brings an `NSWindow` to the front.
enum WindowActivator {
    /// Activates the app and optionally switches its activation policy.
    /// - Parameter policy: The activation policy to use. Defaults to `.regular`
    ///   so that a visible window appears in the Dock and can become key.
    @discardableResult
    static func activateApp(policy: NSApplication.ActivationPolicy = .regular) -> Bool {
        let app = NSApplication.shared
        if app.activationPolicy() != policy {
            _ = app.setActivationPolicy(policy)
        }
        app.activate(ignoringOtherApps: true)
        return true
    }

    /// Shows a window, centering it if it is not currently on screen.
    static func show(_ window: NSWindow?) {
        guard let window = window else { return }
        if !window.isVisible {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
    }

    /// Activates the app and brings the window to the front.
    static func bringToFront(_ window: NSWindow?) {
        activateApp()
        show(window)
    }
}
