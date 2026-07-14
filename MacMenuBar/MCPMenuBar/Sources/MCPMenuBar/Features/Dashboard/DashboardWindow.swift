// FILE: Sources/MCPMenuBar/Features/Dashboard/DashboardWindow.swift
import AppKit

/// Full-size, titlebar-integrated dashboard window with frosted glass chrome.
/// Layout and styling tokens live in `DashboardTheme`; this type only owns the window shell.
final class DashboardWindow: NSWindowController {
    private weak var controller: DashboardController?

    convenience init(controller: DashboardController) {
        let viewController = DashboardViewController(delegate: controller)
        controller.viewController = viewController

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: DashboardTheme.defaultWindowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "MCPMenuBar"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.minSize = DashboardTheme.minWindowSize
        window.setContentSize(DashboardTheme.defaultWindowSize)
        window.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        window.tabbingMode = .disallowed
        window.contentViewController = viewController

        // Soft rounded chrome that matches the glass cards inside.
        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = 12
            contentView.layer?.masksToBounds = true
        }

        self.init(window: window)
        self.controller = controller

        window.center()
        window.setFrameAutosaveName("MCPMenuBar.DashboardWindow")
        window.delegate = self
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        guard let window else { return }

        // Re-assert glass chrome in case the system restored a different appearance.
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .clear
        window.isOpaque = false

        if !window.isKeyWindow {
            window.makeKeyAndOrderFront(sender)
        }

        // Subtle present animation for a polished open.
        window.alphaValue = 0
        window.animationBehavior = .documentWindow
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
    }
}

// MARK: - NSWindowDelegate

extension DashboardWindow: NSWindowDelegate {
    func windowDidBecomeKey(_ notification: Notification) {
        // Ensure traffic lights remain visible over the transparent titlebar.
        window?.standardWindowButton(.closeButton)?.isHidden = false
        window?.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window?.standardWindowButton(.zoomButton)?.isHidden = false
    }
}