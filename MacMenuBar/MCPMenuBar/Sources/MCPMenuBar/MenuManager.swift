import AppKit
import Combine

protocol MenuManagerDelegate: AnyObject {
    func menuManagerDidSelectStart()
    func menuManagerDidSelectStop()
    func menuManagerDidSelectCheckPermissions()
    func menuManagerDidSelectOpenLogs()
    func menuManagerDidSelectCopyBridgeConfig()
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
    private var startItem: NSMenuItem!
    private var stopItem: NSMenuItem!
    private var startAtLoginItem: NSMenuItem!
    private var cancellables = Set<AnyCancellable>()

    init(delegate: MenuManagerDelegate?) {
        self.delegate = delegate
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusMenuItem = NSMenuItem(title: "MCPMenuBar", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        super.init()
        setupMenu()
        bindStartupManager()
        updateStatus(text: "MCPMenuBar: Idle", state: .idle)
    }

    private func setupMenu() {
        let menu = NSMenu()

        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())

        let dashboardItem = NSMenuItem(title: "Open Dashboard", action: #selector(showDashboard), keyEquivalent: "d")
        dashboardItem.target = self
        menu.addItem(dashboardItem)

        let onboardingItem = NSMenuItem(title: "Open Onboarding", action: #selector(showOnboarding), keyEquivalent: "")
        onboardingItem.target = self
        menu.addItem(onboardingItem)

        menu.addItem(NSMenuItem.separator())

        startItem = NSMenuItem(title: "Start Server", action: #selector(startServer), keyEquivalent: "")
        startItem.target = self
        menu.addItem(startItem)

        stopItem = NSMenuItem(title: "Stop Server", action: #selector(stopServer), keyEquivalent: "")
        stopItem.target = self
        menu.addItem(stopItem)

        let checkItem = NSMenuItem(title: "Check Permissions", action: #selector(checkPermissions), keyEquivalent: "")
        checkItem.target = self
        menu.addItem(checkItem)

        startAtLoginItem = NSMenuItem(title: "Start at Login", action: #selector(toggleStartAtLogin), keyEquivalent: "")
        startAtLoginItem.target = self
        startAtLoginItem.state = StartupManager.shared.startAtLoginEnabled ? .on : .off
        menu.addItem(startAtLoginItem)

        let copyItem = NSMenuItem(title: "Copy Bridge Config", action: #selector(copyBridgeConfig), keyEquivalent: "")
        copyItem.target = self
        menu.addItem(copyItem)

        let logsItem = NSMenuItem(title: "Open Logs", action: #selector(openLogs), keyEquivalent: "")
        logsItem.target = self
        menu.addItem(logsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func bindStartupManager() {
        StartupManager.shared.$startAtLoginEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                self?.startAtLoginItem?.state = enabled ? .on : .off
            }
            .store(in: &cancellables)
    }

    func updateStatus(text: String, state: MenuIconState) {
        statusMenuItem.title = text
        setIcon(state)

        switch state {
        case .idle:
            startItem?.isEnabled = true
            stopItem?.isEnabled = false
        case .starting:
            startItem?.isEnabled = false
            stopItem?.isEnabled = true
        case .running:
            startItem?.isEnabled = false
            stopItem?.isEnabled = true
        case .error:
            startItem?.isEnabled = true
            stopItem?.isEnabled = false
        }
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

    @objc private func showDashboard() {
        AppLifecycleManager.shared.showDashboard()
    }

    @objc private func showOnboarding() {
        AppLifecycleManager.shared.showOnboarding()
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

    @objc private func toggleStartAtLogin() {
        _ = StartupManager.shared.toggleStartAtLogin()
    }

    @objc private func copyBridgeConfig() {
        delegate?.menuManagerDidSelectCopyBridgeConfig()
    }

    @objc private func openLogs() {
        delegate?.menuManagerDidSelectOpenLogs()
    }

    @objc private func quit() {
        NSApp.terminate(self)
    }
}
