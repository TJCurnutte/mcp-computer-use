import AppKit

/// Shared color, typography, and layout values for the dashboard.
/// Agents should change the values here, not the names, so the dashboard
/// stays consistent across DashboardViewController, DashboardController, and DashboardWindow.
enum DashboardTheme {
    // MARK: - Colors
    static let backgroundColor: NSColor = NSColor.windowBackgroundColor.withAlphaComponent(0.78)
    static let cardBackground: NSColor = NSColor.controlBackgroundColor.withAlphaComponent(0.65)
    static let primaryText: NSColor = .labelColor
    static let secondaryText: NSColor = .secondaryLabelColor
    static let accent: NSColor = .controlAccentColor

    static let statusIdle: NSColor = .secondaryLabelColor
    static let statusStarting: NSColor = .systemYellow
    static let statusRunning: NSColor = .systemGreen
    static let statusError: NSColor = .systemRed

    // MARK: - Glass/Native refinements
    static let cardBorder: NSColor = NSColor.separatorColor.withAlphaComponent(0.35)
    static let cardShadow: NSColor = NSColor.black.withAlphaComponent(0.18)
    static let glassTint: NSColor = NSColor.windowBackgroundColor.withAlphaComponent(0.45)
    static let accentHover: NSColor = NSColor.controlAccentColor.withAlphaComponent(0.80)

    // MARK: - Typography
    static let fontTitle: NSFont = NSFont.boldSystemFont(ofSize: 22)
    static let fontHeadline: NSFont = NSFont.boldSystemFont(ofSize: 15)
    static let fontBody: NSFont = NSFont.systemFont(ofSize: 13)
    static let fontMonospaced: NSFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    static let fontCaption: NSFont = NSFont.systemFont(ofSize: 11)
    static let fontSmall: NSFont = NSFont.systemFont(ofSize: 10)

    // MARK: - Layout
    static let spacing: CGFloat = 16
    static let padding: CGFloat = 24
    static let cardCornerRadius: CGFloat = 16
    static let buttonHeight: CGFloat = 32
    static let buttonIconSize: CGFloat = 16

    // MARK: - New layout helpers
    static let cardPadding: CGFloat = 20
    static let cardBorderWidth: CGFloat = 1
    static let buttonCornerRadius: CGFloat = 8
    static let headerHeight: CGFloat = 52
}
