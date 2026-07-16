// FILE: Sources/MCPMenuBar/Features/Dashboard/DashboardViewController.swift
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
    private var statusDetailLabel: NSTextField!
    private var statusIconImageView: NSImageView!
    private var statusPulseView: NSView!
    private var permissionStatusLabel: NSTextField!
    private var resultLabel: NSTextField!
    private var startButton: NSButton!
    private var stopButton: NSButton!
    private var resultScrollView: NSScrollView!

    init(delegate: DashboardViewControllerDelegate? = nil) {
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 680))
        root.wantsLayer = true
        view = root
        setupUI()
    }

    // MARK: - Public API

    func updateStatus(text: String, color: NSColor) {
        statusLabel.stringValue = text
        statusLabel.textColor = DashboardTheme.primaryText
        statusDetailLabel.stringValue = statusDetail(for: text)
        statusDetailLabel.textColor = DashboardTheme.secondaryText

        statusIconImageView.image = symbolImage(
            named: statusSymbol(for: text, color: color),
            pointSize: 18,
            weight: .semibold,
            color: color
        )

        statusPulseView.layer?.backgroundColor = color.withAlphaComponent(0.18).cgColor
        statusPulseView.layer?.borderColor = color.withAlphaComponent(0.35).cgColor

        animateStatusChange()
    }

    func updatePermissionStatus(text: String) {
        permissionStatusLabel.stringValue = text
        permissionStatusLabel.textColor = permissionColor(for: text)
    }

    func updateTestResult(text: String) {
        resultLabel.stringValue = text.isEmpty ? "No results yet. Run a bridge test or copy config to see feedback here." : text
        resultLabel.textColor = text.isEmpty
            ? DashboardTheme.secondaryText
            : DashboardTheme.primaryText

        // Keep the latest feedback visible.
        DispatchQueue.main.async { [weak self] in
            guard let scrollView = self?.resultScrollView else { return }
            scrollView.contentView.scroll(to: .zero)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
    }

    func setStartEnabled(_ enabled: Bool) {
        startButton.isEnabled = enabled
        startButton.alphaValue = enabled ? 1.0 : 0.45
    }

    func setStopEnabled(_ enabled: Bool) {
        stopButton.isEnabled = enabled
        stopButton.alphaValue = enabled ? 1.0 : 0.45
    }

    // MARK: - Actions

    @objc private func startClicked() {
        flashButton(startButton)
        delegate?.dashboardViewControllerDidSelectStart()
    }

    @objc private func stopClicked() {
        flashButton(stopButton)
        delegate?.dashboardViewControllerDidSelectStop()
    }

    @objc private func checkPermissionsClicked(_ sender: NSButton) {
        flashButton(sender)
        delegate?.dashboardViewControllerDidSelectCheckPermissions()
    }

    @objc private func openLogsClicked(_ sender: NSButton) {
        flashButton(sender)
        delegate?.dashboardViewControllerDidSelectOpenLogs()
    }

    @objc private func testBridgeClicked(_ sender: NSButton) {
        flashButton(sender)
        delegate?.dashboardViewControllerDidSelectTestBridge()
    }

    @objc private func copyBridgeConfigClicked(_ sender: NSButton) {
        flashButton(sender)
        delegate?.dashboardViewControllerDidSelectCopyBridgeConfig()
    }

    // MARK: - UI

    private func setupUI() {
        // Frosted glass backdrop that fills the full-size content view,
        // including under the transparent titlebar.
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .underWindowBackground
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(visualEffectView)

        // Titlebar-integrated header (sits under traffic lights).
        let header = makeHeader()
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        let headerDivider = NSView()
        headerDivider.wantsLayer = true
        headerDivider.layer?.backgroundColor = DashboardTheme.headerDivider.cgColor
        headerDivider.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerDivider)

        // Scrollable content so the dashboard stays usable at smaller sizes.
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentView

        let rootStack = NSStackView()
        rootStack.orientation = .vertical
        rootStack.alignment = .width
        rootStack.spacing = DashboardTheme.spacing
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rootStack)

        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: view.topAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            header.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DashboardTheme.padding),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DashboardTheme.padding),
            header.heightAnchor.constraint(equalToConstant: DashboardTheme.headerHeight),

            headerDivider.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4),
            headerDivider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DashboardTheme.padding),
            headerDivider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DashboardTheme.padding),
            headerDivider.heightAnchor.constraint(equalToConstant: 1),

            scrollView.topAnchor.constraint(equalTo: headerDivider.bottomAnchor, constant: 14),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            rootStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            rootStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: DashboardTheme.padding),
            rootStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -DashboardTheme.padding),
            rootStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -DashboardTheme.padding)
        ])

        // MARK: Status card
        statusPulseView = NSView()
        statusPulseView.wantsLayer = true
        statusPulseView.layer?.cornerRadius = 22
        statusPulseView.layer?.borderWidth = 1
        statusPulseView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusPulseView.widthAnchor.constraint(equalToConstant: 44),
            statusPulseView.heightAnchor.constraint(equalToConstant: 44)
        ])

        statusIconImageView = NSImageView()
        statusIconImageView.imageScaling = .scaleProportionallyUpOrDown
        statusIconImageView.translatesAutoresizingMaskIntoConstraints = false
        statusPulseView.addSubview(statusIconImageView)
        NSLayoutConstraint.activate([
            statusIconImageView.centerXAnchor.constraint(equalTo: statusPulseView.centerXAnchor),
            statusIconImageView.centerYAnchor.constraint(equalTo: statusPulseView.centerYAnchor),
            statusIconImageView.widthAnchor.constraint(equalToConstant: 22),
            statusIconImageView.heightAnchor.constraint(equalToConstant: 22)
        ])

        statusLabel = makeLabel("Ready to start", font: DashboardTheme.fontTitle, color: DashboardTheme.primaryText)
        statusDetailLabel = makeLabel(
            "Start the MCP bridge when you are ready.",
            font: DashboardTheme.fontCaption,
            color: DashboardTheme.secondaryText
        )
        statusDetailLabel.lineBreakMode = .byWordWrapping
        statusDetailLabel.maximumNumberOfLines = 2

        let statusTextStack = NSStackView(views: [statusLabel, statusDetailLabel])
        statusTextStack.orientation = .vertical
        statusTextStack.alignment = .leading
        statusTextStack.spacing = 3
        statusTextStack.translatesAutoresizingMaskIntoConstraints = false

        let statusRow = NSStackView(views: [statusPulseView, statusTextStack])
        statusRow.orientation = .horizontal
        statusRow.alignment = .centerY
        statusRow.spacing = 14
        statusRow.translatesAutoresizingMaskIntoConstraints = false

        let statusCard = makeCard(content: statusRow, title: nil)
        rootStack.addArrangedSubview(statusCard)

        // MARK: Permissions card
        permissionStatusLabel = makeWrappingLabel(
            "not checked",
            font: DashboardTheme.fontBody,
            color: DashboardTheme.secondaryText
        )
        permissionStatusLabel.isSelectable = true

        let permissionsCard = makeCard(content: permissionStatusLabel, title: "Permissions")
        rootStack.addArrangedSubview(permissionsCard)

        // MARK: Server card
        startButton = makeButton(
            title: "Start Server",
            symbolName: "play.fill",
            tint: DashboardTheme.statusRunning,
            isProminent: true,
            action: #selector(startClicked)
        )
        stopButton = makeButton(
            title: "Stop Server",
            symbolName: "stop.fill",
            tint: DashboardTheme.statusError,
            isProminent: false,
            action: #selector(stopClicked)
        )

        let serverStack = NSStackView(views: [startButton, stopButton])
        serverStack.orientation = .horizontal
        serverStack.alignment = .centerY
        serverStack.distribution = .fillEqually
        serverStack.spacing = 10
        serverStack.translatesAutoresizingMaskIntoConstraints = false

        let serverCard = makeCard(content: serverStack, title: "Server")
        rootStack.addArrangedSubview(serverCard)

        // MARK: Actions card
        let checkPermissionsButton = makeButton(
            title: "Check Permissions",
            symbolName: "checkmark.shield.fill",
            tint: DashboardTheme.accent,
            isProminent: false,
            action: #selector(checkPermissionsClicked(_:))
        )
        let openLogsButton = makeButton(
            title: "Open Logs",
            symbolName: "doc.text.fill",
            tint: DashboardTheme.accent,
            isProminent: false,
            action: #selector(openLogsClicked(_:))
        )
        let testBridgeButton = makeButton(
            title: "Test Bridge",
            symbolName: "network",
            tint: DashboardTheme.accent,
            isProminent: false,
            action: #selector(testBridgeClicked(_:))
        )
        let copyBridgeConfigButton = makeButton(
            title: "Copy Bridge Config",
            symbolName: "doc.on.doc.fill",
            tint: DashboardTheme.accent,
            isProminent: false,
            action: #selector(copyBridgeConfigClicked(_:))
        )

        let actionRow1 = NSStackView(views: [checkPermissionsButton, openLogsButton])
        actionRow1.orientation = .horizontal
        actionRow1.alignment = .centerY
        actionRow1.distribution = .fillEqually
        actionRow1.spacing = 10
        actionRow1.translatesAutoresizingMaskIntoConstraints = false

        let actionRow2 = NSStackView(views: [testBridgeButton, copyBridgeConfigButton])
        actionRow2.orientation = .horizontal
        actionRow2.alignment = .centerY
        actionRow2.distribution = .fillEqually
        actionRow2.spacing = 10
        actionRow2.translatesAutoresizingMaskIntoConstraints = false

        let actionsContent = NSStackView(views: [actionRow1, actionRow2])
        actionsContent.orientation = .vertical
        actionsContent.alignment = .width
        actionsContent.spacing = 10
        actionsContent.translatesAutoresizingMaskIntoConstraints = false

        let actionsCard = makeCard(content: actionsContent, title: "Actions")
        rootStack.addArrangedSubview(actionsCard)

        // MARK: Result card
        resultLabel = makeWrappingLabel(
            "No results yet. Run a bridge test or copy config to see feedback here.",
            font: DashboardTheme.fontMonospaced,
            color: DashboardTheme.secondaryText
        )
        resultLabel.isSelectable = true

        resultScrollView = NSScrollView()
        resultScrollView.drawsBackground = false
        resultScrollView.hasVerticalScroller = true
        resultScrollView.hasHorizontalScroller = false
        resultScrollView.autohidesScrollers = true
        resultScrollView.borderType = .noBorder
        resultScrollView.documentView = resultLabel
        resultScrollView.translatesAutoresizingMaskIntoConstraints = false
        resultScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 96).isActive = true
        resultScrollView.heightAnchor.constraint(lessThanOrEqualToConstant: 180).isActive = true

        // Pin the label width to the scroll view so wrapping works.
        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            resultLabel.topAnchor.constraint(equalTo: resultScrollView.contentView.topAnchor),
            resultLabel.leadingAnchor.constraint(equalTo: resultScrollView.contentView.leadingAnchor),
            resultLabel.trailingAnchor.constraint(equalTo: resultScrollView.contentView.trailingAnchor),
            resultLabel.widthAnchor.constraint(equalTo: resultScrollView.contentView.widthAnchor)
        ])

        let resultCard = makeCard(content: resultScrollView, title: "Result")
        rootStack.addArrangedSubview(resultCard)

        // Initial state
        updateStatus(text: "Idle", color: DashboardTheme.statusIdle)
        updatePermissionStatus(text: "not checked")
        setStartEnabled(true)
        setStopEnabled(false)
    }

    // MARK: - Builders

    private func makeHeader() -> NSView {
        let container = NSView()
        container.wantsLayer = true

        let iconBadge = NSView()
        iconBadge.wantsLayer = true
        iconBadge.layer?.cornerRadius = 10
        iconBadge.layer?.backgroundColor = DashboardTheme.accent.withAlphaComponent(0.16).cgColor
        iconBadge.layer?.borderWidth = 0.5
        iconBadge.layer?.borderColor = DashboardTheme.accent.withAlphaComponent(0.28).cgColor
        iconBadge.translatesAutoresizingMaskIntoConstraints = false

        let appIcon = NSImageView()
        appIcon.image = symbolImage(
            named: "server.rack",
            pointSize: 15,
            weight: .semibold,
            color: DashboardTheme.accent
        )
        appIcon.imageScaling = .scaleProportionallyUpOrDown
        appIcon.translatesAutoresizingMaskIntoConstraints = false
        iconBadge.addSubview(appIcon)

        let title = makeLabel("Reflex", font: DashboardTheme.fontTitle, color: DashboardTheme.primaryText)
        let subtitle = makeLabel(
            "Bridge control & diagnostics",
            font: DashboardTheme.fontCaption,
            color: DashboardTheme.secondaryText
        )

        let textStack = NSStackView(views: [title, subtitle])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1
        textStack.translatesAutoresizingMaskIntoConstraints = false

        // Leave room for traffic lights on the leading edge of a transparent titlebar.
        let leadingSpacer = NSView()
        leadingSpacer.translatesAutoresizingMaskIntoConstraints = false
        leadingSpacer.widthAnchor.constraint(equalToConstant: 62).isActive = true

        let row = NSStackView(views: [leadingSpacer, iconBadge, textStack])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(row)

        NSLayoutConstraint.activate([
            iconBadge.widthAnchor.constraint(equalToConstant: 34),
            iconBadge.heightAnchor.constraint(equalToConstant: 34),
            appIcon.centerXAnchor.constraint(equalTo: iconBadge.centerXAnchor),
            appIcon.centerYAnchor.constraint(equalTo: iconBadge.centerYAnchor),
            appIcon.widthAnchor.constraint(equalToConstant: 18),
            appIcon.heightAnchor.constraint(equalToConstant: 18),

            row.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            row.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
            row.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    private func makeCard(content: NSView, title: String?) -> NSView {
        let card = NSView()
        card.wantsLayer = true
        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer?.cornerRadius = DashboardTheme.cardCornerRadius
        card.layer?.masksToBounds = false
        card.layer?.backgroundColor = DashboardTheme.cardBackground.cgColor
        card.layer?.borderWidth = DashboardTheme.cardBorderWidth
        card.layer?.borderColor = DashboardTheme.cardBorder.cgColor
        card.layer?.shadowColor = DashboardTheme.cardShadow.cgColor
        card.layer?.shadowOpacity = DashboardTheme.cardShadowOpacity
        card.layer?.shadowRadius = DashboardTheme.cardShadowRadius
        card.layer?.shadowOffset = DashboardTheme.cardShadowOffset

        // Inner fill keeps content clipped to rounded corners without killing the outer shadow.
        let fill = NSView()
        fill.wantsLayer = true
        fill.layer?.cornerRadius = DashboardTheme.cardCornerRadius
        fill.layer?.backgroundColor = NSColor.clear.cgColor
        fill.layer?.masksToBounds = true
        fill.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(fill)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        fill.addSubview(stack)

        if let title {
            let titleLabel = makeLabel(title.uppercased(), font: DashboardTheme.fontSection, color: DashboardTheme.secondaryText)
            stack.addArrangedSubview(titleLabel)
        }

        content.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(content)

        NSLayoutConstraint.activate([
            fill.topAnchor.constraint(equalTo: card.topAnchor),
            fill.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            fill.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            fill.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            stack.topAnchor.constraint(equalTo: fill.topAnchor, constant: DashboardTheme.cardPadding),
            stack.leadingAnchor.constraint(equalTo: fill.leadingAnchor, constant: DashboardTheme.cardPadding),
            stack.trailingAnchor.constraint(equalTo: fill.trailingAnchor, constant: -DashboardTheme.cardPadding),
            stack.bottomAnchor.constraint(equalTo: fill.bottomAnchor, constant: -DashboardTheme.cardPadding)
        ])

        return card
    }

    private func makeButton(
        title: String,
        symbolName: String,
        tint: NSColor,
        isProminent: Bool,
        action: Selector
    ) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.isBordered = true
        button.font = DashboardTheme.fontBody
        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = isProminent ? .white : tint
        button.image = symbolImage(
            named: symbolName,
            pointSize: DashboardTheme.buttonIconSize,
            weight: .semibold,
            color: isProminent ? .white : tint
        )
        button.toolTip = title
        button.setButtonType(.momentaryPushIn)

        if isProminent {
            button.bezelColor = tint
        }

        button.heightAnchor.constraint(equalToConstant: DashboardTheme.buttonHeight).isActive = true
        return button
    }

    private func makeLabel(_ text: String, font: NSFont, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func makeWrappingLabel(_ text: String, font: NSFont, color: NSColor) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = font
        label.textColor = color
        label.isSelectable = false
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func symbolImage(
        named name: String,
        pointSize: CGFloat,
        weight: NSFont.Weight,
        color: NSColor
    ) -> NSImage? {
        let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        let sizeConfig = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight, scale: .medium)
        let colorConfig = NSImage.SymbolConfiguration(paletteColors: [color])
        let configured = base?
            .withSymbolConfiguration(sizeConfig.applying(colorConfig))
        configured?.isTemplate = false
        return configured
    }

    // MARK: - Feedback helpers

    private func statusSymbol(for text: String, color: NSColor) -> String {
        let lower = text.lowercased()
        if lower.contains("error") { return "exclamationmark.triangle.fill" }
        if lower.contains("testing") || lower.contains("starting") { return "arrow.triangle.2.circlepath" }
        if color == DashboardTheme.statusRunning || lower.contains("running") { return "checkmark.circle.fill" }
        if lower.contains("idle") || lower.contains("ready") { return "pause.circle.fill" }
        return "circle.fill"
    }

    private func statusDetail(for text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("error") {
            return "Something went wrong. Check logs or permissions, then try again."
        }
        if lower.contains("testing") {
            return "Running bridge diagnostics. This may take a moment."
        }
        if lower.contains("starting") {
            return "Launching the MCP bridge process…"
        }
        if lower.contains("running") {
            return "Bridge is online and accepting connections."
        }
        if lower.contains("ready") || lower.contains("idle") {
            return "Start the MCP bridge when you are ready."
        }
        return text
    }

    private func permissionColor(for text: String) -> NSColor {
        let lower = text.lowercased()
        if lower.contains("checking") {
            return DashboardTheme.statusStarting
        }
        if lower.contains("needed") || lower.contains("⚠️") {
            return DashboardTheme.statusError
        }
        if lower.contains("ok") || lower.contains("✅") {
            return DashboardTheme.statusRunning
        }
        return DashboardTheme.secondaryText
    }

    private func animateStatusChange() {
        guard let layer = statusPulseView.layer else { return }
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = 0.92
        animation.toValue = 1.0
        animation.duration = 0.22
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(animation, forKey: "statusPulse")
    }

    private func flashButton(_ button: NSButton) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.08
            button.animator().alphaValue = 0.7
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.14
                button.animator().alphaValue = button.isEnabled ? 1.0 : 0.45
            }
        }
    }
}