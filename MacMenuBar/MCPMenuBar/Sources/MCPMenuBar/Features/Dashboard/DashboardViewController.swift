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
    private var statusIconImageView: NSImageView!
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

    // MARK: - Public API

    func updateStatus(text: String, color: NSColor) {
        statusLabel.stringValue = "Status: \(text)"
        statusLabel.textColor = color
        statusIconImageView.image = symbolImage(
            named: "circle.fill",
            pointSize: 32,
            weight: .bold,
            color: color
        )
    }

    func updatePermissionStatus(text: String) {
        permissionStatusLabel.stringValue = text
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

    // MARK: - Actions

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

    // MARK: - UI

    private func setupUI() {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .underWindowBackground
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(visualEffectView)

        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: view.topAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let rootStack = NSStackView()
        rootStack.orientation = .vertical
        rootStack.alignment = .width
        rootStack.spacing = DashboardTheme.spacing
        rootStack.edgeInsets = NSEdgeInsets(
            top: 44,
            left: DashboardTheme.padding,
            bottom: DashboardTheme.padding,
            right: DashboardTheme.padding
        )
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: view.topAnchor),
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rootStack.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Status card
        statusIconImageView = NSImageView()
        statusIconImageView.imageScaling = .scaleProportionallyUpOrDown
        statusIconImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusIconImageView.widthAnchor.constraint(equalToConstant: 32),
            statusIconImageView.heightAnchor.constraint(equalToConstant: 32)
        ])

        statusLabel = NSTextField(labelWithString: "Status: Idle")
        statusLabel.font = DashboardTheme.fontTitle
        statusLabel.textColor = DashboardTheme.secondaryText

        let statusStack = NSStackView(views: [statusIconImageView, statusLabel])
        statusStack.orientation = .horizontal
        statusStack.alignment = .centerY
        statusStack.spacing = 12
        statusStack.translatesAutoresizingMaskIntoConstraints = false

        let statusCard = makeCard(content: statusStack)
        rootStack.addArrangedSubview(statusCard)

        // Permissions card
        let permissionsTitle = NSTextField(labelWithString: "Permissions")
        permissionsTitle.font = DashboardTheme.fontHeadline
        permissionsTitle.textColor = DashboardTheme.primaryText

        permissionStatusLabel = NSTextField(wrappingLabelWithString: "not checked")
        permissionStatusLabel.font = DashboardTheme.fontBody
        permissionStatusLabel.textColor = DashboardTheme.secondaryText
        permissionStatusLabel.isSelectable = true

        let permissionsStack = NSStackView(views: [permissionsTitle, permissionStatusLabel])
        permissionsStack.orientation = .vertical
        permissionsStack.alignment = .width
        permissionsStack.spacing = 4
        permissionsStack.translatesAutoresizingMaskIntoConstraints = false

        let permissionsCard = makeCard(content: permissionsStack)
        rootStack.addArrangedSubview(permissionsCard)

        // Server card
        startButton = makeButton(
            title: "Start Server",
            symbolName: "play.fill",
            color: DashboardTheme.statusRunning,
            action: #selector(startClicked)
        )
        stopButton = makeButton(
            title: "Stop Server",
            symbolName: "stop.fill",
            color: DashboardTheme.statusError,
            action: #selector(stopClicked)
        )

        let serverStack = NSStackView(views: [startButton, stopButton])
        serverStack.orientation = .horizontal
        serverStack.alignment = .centerY
        serverStack.distribution = .fillEqually
        serverStack.spacing = 12
        serverStack.translatesAutoresizingMaskIntoConstraints = false

        let serverTitle = NSTextField(labelWithString: "Server")
        serverTitle.font = DashboardTheme.fontHeadline
        serverTitle.textColor = DashboardTheme.primaryText

        let serverContent = NSStackView(views: [serverTitle, serverStack])
        serverContent.orientation = .vertical
        serverContent.alignment = .width
        serverContent.spacing = 8
        serverContent.translatesAutoresizingMaskIntoConstraints = false

        let serverCard = makeCard(content: serverContent)
        rootStack.addArrangedSubview(serverCard)

        // Actions card
        let checkPermissionsButton = makeButton(
            title: "Check Permissions",
            symbolName: "checkmark.shield",
            color: DashboardTheme.accent,
            action: #selector(checkPermissionsClicked)
        )
        let openLogsButton = makeButton(
            title: "Open Logs",
            symbolName: "doc.text",
            color: DashboardTheme.accent,
            action: #selector(openLogsClicked)
        )
        let testBridgeButton = makeButton(
            title: "Test Bridge",
            symbolName: "network",
            color: DashboardTheme.accent,
            action: #selector(testBridgeClicked)
        )
        let copyBridgeConfigButton = makeButton(
            title: "Copy Bridge Config",
            symbolName: "doc.on.doc",
            color: DashboardTheme.accent,
            action: #selector(copyBridgeConfigClicked)
        )

        let actionRow1 = NSStackView(views: [checkPermissionsButton, openLogsButton])
        actionRow1.orientation = .horizontal
        actionRow1.alignment = .centerY
        actionRow1.distribution = .fillEqually
        actionRow1.spacing = 12
        actionRow1.translatesAutoresizingMaskIntoConstraints = false

        let actionRow2 = NSStackView(views: [testBridgeButton, copyBridgeConfigButton])
        actionRow2.orientation = .horizontal
        actionRow2.alignment = .centerY
        actionRow2.distribution = .fillEqually
        actionRow2.spacing = 12
        actionRow2.translatesAutoresizingMaskIntoConstraints = false

        let actionsContent = NSStackView(views: [actionRow1, actionRow2])
        actionsContent.orientation = .vertical
        actionsContent.alignment = .width
        actionsContent.spacing = 12
        actionsContent.translatesAutoresizingMaskIntoConstraints = false

        let actionsTitle = NSTextField(labelWithString: "Actions")
        actionsTitle.font = DashboardTheme.fontHeadline
        actionsTitle.textColor = DashboardTheme.primaryText

        let actionsStack = NSStackView(views: [actionsTitle, actionsContent])
        actionsStack.orientation = .vertical
        actionsStack.alignment = .width
        actionsStack.spacing = 8
        actionsStack.translatesAutoresizingMaskIntoConstraints = false

        let actionsCard = makeCard(content: actionsStack)
        rootStack.addArrangedSubview(actionsCard)

        // Result card
        let resultTitle = NSTextField(labelWithString: "Result")
        resultTitle.font = DashboardTheme.fontHeadline
        resultTitle.textColor = DashboardTheme.primaryText

        resultLabel = NSTextField(wrappingLabelWithString: "")
        resultLabel.font = DashboardTheme.fontMonospaced
        resultLabel.textColor = DashboardTheme.primaryText
        resultLabel.isSelectable = true

        let resultStack = NSStackView(views: [resultTitle, resultLabel])
        resultStack.orientation = .vertical
        resultStack.alignment = .width
        resultStack.spacing = 4
        resultStack.translatesAutoresizingMaskIntoConstraints = false

        let resultCard = makeCard(content: resultStack)
        rootStack.addArrangedSubview(resultCard)

        // Initialize state
        updateStatus(text: "Idle", color: DashboardTheme.statusIdle)
        updatePermissionStatus(text: "not checked")
    }

    private func makeCard(content: NSView) -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer?.cornerRadius = DashboardTheme.cardCornerRadius
        card.layer?.backgroundColor = DashboardTheme.cardBackground.cgColor
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
        card.layer?.shadowColor = NSColor.black.cgColor
        card.layer?.shadowOpacity = 0.08
        card.layer?.shadowRadius = 4
        card.layer?.shadowOffset = CGSize(width: 0, height: -2)

        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        return card
    }

    private func makeButton(title: String, symbolName: String, color: NSColor, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.font = DashboardTheme.fontBody
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
        button.imageScaling = .scaleProportionallyDown
        button.image = symbolImage(
            named: symbolName,
            pointSize: DashboardTheme.buttonIconSize,
            weight: .regular,
            color: color
        )
        return button
    }

    private func symbolImage(named name: String, pointSize: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSImage? {
        let configured = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(
                NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight, scale: .medium)
                    .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
            )
        configured?.isTemplate = false
        return configured
    }
}
