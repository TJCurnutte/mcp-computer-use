import Foundation
import AppKit
import Combine

/// A single row in the permissions checklist.
final class PermissionRowView: NSView {
    private let type: PermissionType
    private let manager: PermissionsManager

    private let nameLabel = NSTextField()
    private let statusLabel = NSTextField()
    private let settingsButton = NSButton()

    init(manager: PermissionsManager, type: PermissionType) {
        self.manager = manager
        self.type = type
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(with status: PermissionStatus) {
        nameLabel.stringValue = status.permissionType.displayName
        statusLabel.stringValue = status.description
        statusLabel.textColor = status.isGranted ? .systemGreen : .systemRed
        settingsButton.isEnabled = !status.isGranted
    }

    @objc func openSettings(_ sender: Any?) {
        manager.openSystemSettings(for: type)
    }

    private func setup() {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.distribution = .fill
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        nameLabel.isEditable = false
        nameLabel.isBordered = false
        nameLabel.isBezeled = false
        nameLabel.backgroundColor = .clear
        nameLabel.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addView(nameLabel, in: .leading)

        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.isBezeled = false
        statusLabel.backgroundColor = .clear
        statusLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        stack.addView(statusLabel, in: .leading)

        settingsButton.title = "Open Settings"
        settingsButton.bezelStyle = .rounded
        settingsButton.target = self
        settingsButton.action = #selector(openSettings(_:))
        settingsButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        stack.addView(settingsButton, in: .leading)
    }
}

/// A small AppKit checklist showing permission status and "Open Settings" buttons.
///
/// Bind it to a `PermissionsManager` to keep the checklist live.
final class PermissionsView: NSView {
    private let manager: PermissionsManager
    private var rowViews: [PermissionType: PermissionRowView] = [:]
    private var cancellable: AnyCancellable?

    init(permissionsManager: PermissionsManager) {
        self.manager = permissionsManager
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setup()

        cancellable = manager.$statuses
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.update()
            }

        manager.refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        cancellable?.cancel()
    }

    @objc func update() {
        for status in manager.statuses {
            rowViews[status.permissionType]?.update(with: status)
        }
    }

    private func setup() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.distribution = .fill
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])

        for type in PermissionType.allCases {
            let row = PermissionRowView(manager: manager, type: type)
            rowViews[type] = row
            stack.addView(row, in: .leading)
        }

        let refreshButton = NSButton(title: "Refresh", target: self, action: #selector(update))
        refreshButton.bezelStyle = .rounded
        stack.addView(refreshButton, in: .leading)
    }
}
