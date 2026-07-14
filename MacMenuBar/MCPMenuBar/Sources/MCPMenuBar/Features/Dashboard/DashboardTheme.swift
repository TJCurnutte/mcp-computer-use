// FILE: Sources/MCPMenuBar/Features/Dashboard/DashboardTheme.swift
import AppKit

/// Shared color, typography, and layout values for the dashboard.
/// Agents should change the values here, not the names, so the dashboard
/// stays consistent across DashboardViewController, DashboardController, and DashboardWindow.
enum DashboardTheme {
    // MARK: - Colors
    static let backgroundColor: NSColor = .clear
    static let cardBackground: NSColor = NSColor.controlBackgroundColor.withAlphaComponent(0.82)
    static let primaryText: NSColor = .labelColor
    static let secondaryText: NSColor = .secondaryLabelColor
    static let accent: NSColor = .controlAccentColor

    static let statusIdle: NSColor = .secondaryLabelColor
    static let statusStarting: NSColor = .systemYellow
    static let statusRunning: NSColor = .systemGreen
    static let statusError: NSColor = .systemRed

    // MARK: - Glass / Native refinements
    static let cardBorder: NSColor = NSColor.separatorColor.withAlphaComponent(0.45)
    static let cardShadow: NSColor = NSColor.black.withAlphaComponent(0.12)
    static let glassTint: NSColor = .clear
    static let accentHover: NSColor = NSColor.controlAccentColor.withAlphaComponent(0.85)
    static let buttonFill: NSColor = NSColor.controlBackgroundColor.withAlphaComponent(0.55)
    static let buttonBorder: NSColor = NSColor.separatorColor.withAlphaComponent(0.35)
    static let headerDivider: NSColor = NSColor.separatorColor.withAlphaComponent(0.45)

    // MARK: - Typography
    static let fontTitle: NSFont = .systemFont(ofSize: 20, weight: .semibold)
    static let fontHeadline: NSFont = .systemFont(ofSize: 13, weight: .semibold)
    static let fontBody: NSFont = .systemFont(ofSize: 13, weight: .medium)
    static let fontMonospaced: NSFont = .monospacedSystemFont(ofSize: 11.5, weight: .regular)
    static let fontCaption: NSFont = .systemFont(ofSize: 11, weight: .regular)
    static let fontSmall: NSFont = .systemFont(ofSize: 10, weight: .medium)
    static let fontSection: NSFont = .systemFont(ofSize: 11, weight: .semibold)

    // MARK: - Layout
    static let spacing: CGFloat = 14
    static let padding: CGFloat = 20
    static let cardCornerRadius: CGFloat = 14
    static let buttonHeight: CGFloat = 34
    static let buttonIconSize: CGFloat = 13

    // MARK: - Card / control helpers
    static let cardPadding: CGFloat = 16
    static let cardBorderWidth: CGFloat = 0.5
    static let buttonCornerRadius: CGFloat = 9
    static let headerHeight: CGFloat = 56
    static let contentTopInset: CGFloat = 52
    static let cardShadowRadius: CGFloat = 10
    static let cardShadowOffset = CGSize(width: 0, height: -1)
    static let cardShadowOpacity: Float = 0.12
    static let minWindowSize = NSSize(width: 520, height: 560)
    static let defaultWindowSize = NSSize(width: 560, height: 680)
}