import AppKit

protocol MenuManagerDelegate: AnyObject {
    func menuManagerDidSelectStart()
    func menuManagerDidSelectStop()
    func menuManagerDidSelectCheckPermissions()
    func menuManagerDidSelectOpenLogs()
    func menuManagerDidSelectCopyBridgePath()
}

enum MenuIconState {
    case idle
    case starting
    case running
    case error
}

final class MenuManager: NSObject {
    weak var delegate: MenuManagerDelegate?
    private let statusItem: NSStatusItem
    private let statusMenuItem: NSMenuItem

    init(delegate: MenuManagerDelegate?) {
        self.delegate = delegate
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusMenuItem = NSMenuItem(title: "MCPMenuBar", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        super.init()
        setupMenu()
        updateStatus(text: "MCPMenuBar: Idle", state: .idle)
    }

    private func setupMenu() {
        let menu = NSMenu()

        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())

        let startItem = NSMenuItem(title: "Start Server", action: #selector(startServer), keyEquivalent: "")
        startItem.target = self
        menu.addItem(startItem)

        let stopItem = NSMenuItem(title: "Stop Server", action: #selector(stopServer), keyEquivalent: "")
        stopItem.target = self
        menu.addItem(stopItem)

        let checkItem = NSMenuItem(title: "Check Permissions", action: #selector(checkPermissions), keyEquivalent: "")
        checkItem.target = self
        menu.addItem(checkItem)

        let logsItem = NSMenuItem(title: "Open Logs", action: #selector(openLogs), keyEquivalent: "")
        logsItem.target = self
        menu.addItem(logsItem)

        let copyItem = NSMenuItem(title: "Copy Bridge Path", action: #selector(copyBridgePath), keyEquivalent: "")
        copyItem.target = self
        menu.addItem(copyItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func updateStatus(text: String, state: MenuIconState) {
        statusMenuItem.title = text
        setIcon(state)
    }

    private func setIcon(_ state: MenuIconState) {
        guard let button = statusItem.button else { return }

        let image = NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: "MCP Menu Bar")
        let color: NSColor
        switch state {
        case .idle: color = .systemGray
        case .starting: color = .systemYellow
        case .running: color = .systemGreen
        case .error: color = .systemRed
        }

        if let image = image {
            image.isTemplate = false
            button.image = image
            button.contentTintColor = color
        } else {
            button.title = "MCP"
            button.contentTintColor = color
        }
    }

    @objc private func startServer() {
        delegate?.menuManagerDidSelectStart()
    }

    @objc private func stopServer() {
        delegate?.menuManagerDidSelectStop()
    }

    @objc private func checkPermissions() {
        delegate?.menuManagerDidSelectCheckPermissions()
    }

    @objc private func openLogs() {
        delegate?.menuManagerDidSelectOpenLogs()
    }

    @objc private func copyBridgePath() {
        delegate?.menuManagerDidSelectCopyBridgePath()
    }

    @objc private func quit() {
        NSApp.terminate(self)
    }
}
