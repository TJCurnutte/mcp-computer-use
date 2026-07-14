import AppKit

final class DashboardWindow: NSWindowController {
    init(controller: DashboardController) {
        let viewController = DashboardViewController(delegate: controller)
        controller.viewController = viewController

        let window = NSWindow(contentViewController: viewController)
        window.title = "MCPMenuBar Dashboard"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 480, height: 320)
        window.center()

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
