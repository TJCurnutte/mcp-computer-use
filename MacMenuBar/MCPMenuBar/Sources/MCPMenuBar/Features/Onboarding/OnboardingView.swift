import AppKit
import Foundation

/// The root onboarding container view: a centered icon, title, explanation,
/// action button, and Back/Next navigation.
final class OnboardingView: NSView {

    var onBack: (() -> Void)?
    var onNext: (() -> Void)?
    var onAction: (() -> Void)?

    let backButton = NSButton(title: "Back", target: nil, action: nil)
    let nextButton = NSButton(title: "Next", target: nil, action: nil)
    let actionButton = NSButton(title: "Action", target: nil, action: nil)

    private let iconImageView = NSImageView()
    private let titleTextField = NSTextField(labelWithString: "")
    private let bodyTextField = NSTextField(wrappingLabelWithString: "")
    private let headerStack = NSStackView()
    private let footerStack = NSStackView()
    private let rootStack = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        // Icon
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.imageScaling = .scaleProportionallyDown
        iconImageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 48, weight: .regular)
        iconImageView.contentTintColor = NSColor.controlAccentColor
        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 64),
            iconImageView.heightAnchor.constraint(equalToConstant: 64)
        ])

        // Title
        titleTextField.alignment = .center
        titleTextField.font = NSFont.preferredFont(forTextStyle: .title2)
        titleTextField.textColor = NSColor.labelColor

        // Body
        bodyTextField.alignment = .center
        bodyTextField.font = NSFont.preferredFont(forTextStyle: .body)
        bodyTextField.textColor = NSColor.secondaryLabelColor
        bodyTextField.translatesAutoresizingMaskIntoConstraints = false

        // Buttons
        for button in [backButton, nextButton, actionButton] {
            button.bezelStyle = .rounded
            button.target = self
        }
        backButton.action = #selector(backTapped)
        nextButton.action = #selector(nextTapped)
        actionButton.action = #selector(actionTapped)
        nextButton.keyEquivalent = "\r"

        // Header stack
        headerStack.orientation = .vertical
        headerStack.alignment = .centerX
        headerStack.spacing = 16
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.addArrangedSubview(iconImageView)
        headerStack.addArrangedSubview(titleTextField)
        headerStack.addArrangedSubview(bodyTextField)
        headerStack.addArrangedSubview(actionButton)

        // Body width matches the header stack so the wrapping label resizes correctly.
        NSLayoutConstraint.activate([
            bodyTextField.widthAnchor.constraint(equalTo: headerStack.widthAnchor, constant: -48)
        ])

        // Footer stack
        footerStack.orientation = .horizontal
        footerStack.alignment = .centerY
        footerStack.distribution = .equalSpacing
        footerStack.translatesAutoresizingMaskIntoConstraints = false
        footerStack.addArrangedSubview(backButton)
        footerStack.addArrangedSubview(nextButton)

        // Root stack pins header to top and footer to bottom.
        rootStack.orientation = .vertical
        rootStack.alignment = .width
        rootStack.spacing = 0
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        rootStack.addView(headerStack, in: .top)
        rootStack.addView(footerStack, in: .bottom)

        addSubview(rootStack)
        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            rootStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            rootStack.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            rootStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24)
        ])
    }

    func configure(for page: OnboardingPage) {
        titleTextField.stringValue = page.title
        bodyTextField.stringValue = page.body

        if let image = NSImage(systemSymbolName: page.iconName, accessibilityDescription: nil) {
            image.isTemplate = true
            iconImageView.image = image
        }

        if let actionTitle = page.actionButtonTitle {
            actionButton.title = actionTitle
            actionButton.isHidden = false
        } else {
            actionButton.isHidden = true
        }

        backButton.isEnabled = page.isBackEnabled
        nextButton.title = page.nextButtonTitle
    }

    @objc private func backTapped() { onBack?() }
    @objc private func nextTapped() { onNext?() }
    @objc private func actionTapped() { onAction?() }
}
