import AppKit

final class DashboardWindow: NSWindowController {
    init(controller: DashboardController) {
        let viewController = DashboardViewController(delegate: controller)
        controller.viewController = viewController

        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "MCPMenuBar Dashboard"
        window.minSize = NSSize(width: 480, height: 320)
        window.isReleasedWhenClosed = false
        window.contentViewController = viewController

        super.init(window: window)

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = .clear
        window.setContentSize(NSSize(width: 800, height: 600))
        window.center()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
