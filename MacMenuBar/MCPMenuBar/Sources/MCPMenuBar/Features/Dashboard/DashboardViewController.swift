import AppKit

protocol DashboardViewControllerDelegate: AnyObject {
    func dashboardViewControllerDidSelectStart()
    func dashboardViewControllerDidSelectStop()
    func dashboardViewControllerDidSelectCheckPermissions()
    func dashboardViewControllerDidSelectOpenLogs()
    func dashboardViewControllerDidSelectTestBridge()
    func dashboardViewControllerDidSelectCopyBridgeConfig()
}

final class DashboardViewController: NSViewController {
    weak var delegate: DashboardViewControllerDelegate?

    private var statusLabel: NSTextField!
    private var permissionStatusLabel: NSTextField!
    private var resultLabel: NSTextField!
    private var startButton: NSButton!
    private var stopButton: NSButton!

    init(delegate: DashboardViewControllerDelegate? = nil) {
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        setupUI()
    }

    private func setupUI() {
        statusLabel = NSTextField(labelWithString: "Status: Idle")
        statusLabel.font = NSFont.boldSystemFont(ofSize: 14)
        statusLabel.textColor = .secondaryLabelColor

        permissionStatusLabel = NSTextField(labelWithString: "Permissions: not checked")
        permissionStatusLabel.textColor = .secondaryLabelColor

        resultLabel = NSTextField(wrappingLabelWithString: "")
        resultLabel.isSelectable = true

        startButton = NSButton(title: "Start Server", target: self, action: #selector(startClicked))
        startButton.bezelStyle = .rounded

        stopButton = NSButton(title: "Stop Server", target: self, action: #selector(stopClicked))
        stopButton.bezelStyle = .rounded

        let checkPermissionsButton = NSButton(title: "Check Permissions", target: self, action: #selector(checkPermissionsClicked))
        checkPermissionsButton.bezelStyle = .rounded

        let openLogsButton = NSButton(title: "Open Logs", target: self, action: #selector(openLogsClicked))
        openLogsButton.bezelStyle = .rounded

        let testBridgeButton = NSButton(title: "Test Bridge", target: self, action: #selector(testBridgeClicked))
        testBridgeButton.bezelStyle = .rounded

        let copyBridgeConfigButton = NSButton(title: "Copy Bridge Config", target: self, action: #selector(copyBridgeConfigClicked))
        copyBridgeConfigButton.bezelStyle = .rounded

        let serverStack = NSStackView(views: [startButton, stopButton])
        serverStack.orientation = .horizontal
        serverStack.alignment = .centerY
        serverStack.spacing = 8

        let actionStack = NSStackView(views: [checkPermissionsButton, openLogsButton, testBridgeButton, copyBridgeConfigButton])
        actionStack.orientation = .horizontal
        actionStack.alignment = .centerY
        actionStack.spacing = 8

        let stackView = NSStackView(views: [statusLabel, permissionStatusLabel, resultLabel, serverStack, actionStack])
        stackView.orientation = .vertical
        stackView.alignment = .width
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    func updateStatus(text: String, color: NSColor) {
        statusLabel.stringValue = "Status: \(text)"
        statusLabel.textColor = color
    }

    func updatePermissionStatus(text: String) {
        permissionStatusLabel.stringValue = "Permissions: \(text)"
    }

    func updateTestResult(text: String) {
        resultLabel.stringValue = text
    }

    func setStartEnabled(_ enabled: Bool) {
        startButton.isEnabled = enabled
    }

    func setStopEnabled(_ enabled: Bool) {
        stopButton.isEnabled = enabled
    }

    @objc private func startClicked() {
        delegate?.dashboardViewControllerDidSelectStart()
    }

    @objc private func stopClicked() {
        delegate?.dashboardViewControllerDidSelectStop()
    }

    @objc private func checkPermissionsClicked() {
        delegate?.dashboardViewControllerDidSelectCheckPermissions()
    }

    @objc private func openLogsClicked() {
        delegate?.dashboardViewControllerDidSelectOpenLogs()
    }

    @objc private func testBridgeClicked() {
        delegate?.dashboardViewControllerDidSelectTestBridge()
    }

    @objc private func copyBridgeConfigClicked() {
        delegate?.dashboardViewControllerDidSelectCopyBridgeConfig()
    }
}
