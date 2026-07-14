import AppKit
import Foundation

/// Manages the high-level app lifecycle: first-run onboarding, window visibility,
/// and status-bar-only subsequent launches.
final class AppLifecycleManager {
    static let shared = AppLifecycleManager()

    private let firstRunChecker = FirstRunChecker.shared
    private var onboardingWindow: NSWindow?
    private var dashboardWindow: NSWindow?

    /// Optional factory closures the main agent can set to inject the real
    /// onboarding and dashboard windows once Agent 2 and Agent 6 land them.
    var onboardingWindowFactory: (() -> NSWindow?)?
    var dashboardWindowFactory: (() -> NSWindow?)?

    private init() {}

    var isFirstRun: Bool {
        firstRunChecker.isFirstRun
    }

    /// Call once from `AppDelegate.applicationDidFinishLaunching(_:)`.
    /// On first launch it shows the onboarding window and activates the app.
    /// On subsequent launches it leaves the app in the status-bar mode.
    func start() {
        if isFirstRun {
            Logger.shared.log("First launch detected; showing onboarding")
            showOnboarding()
        } else {
            Logger.shared.log("Subsequent launch; status-bar only")
        }
    }

    /// Shows the onboarding window, activating the app.
    func showOnboarding() {
        if onboardingWindow == nil {
            onboardingWindow = onboardingWindowFactory?() ?? makeDefaultOnboardingWindow()
        }
        WindowActivator.bringToFront(onboardingWindow)
    }

    /// Shows the dashboard window, activating the app.
    func showDashboard() {
        if dashboardWindow == nil {
            dashboardWindow = dashboardWindowFactory?() ?? makeDefaultDashboardWindow()
        }
        WindowActivator.bringToFront(dashboardWindow)
    }

    /// Marks onboarding as complete and returns the app to accessory mode.
    /// The onboarding window can call this (or the main agent can) when the user finishes setup.
    func completeOnboarding() {
        firstRunChecker.markOnboardingComplete()
        WindowActivator.activateApp(policy: .accessory)
        onboardingWindow?.close()
    }

    /// Returns `true` if the running bundle is located under `/Applications`.
    func isRunningFromApplications() -> Bool {
        let bundlePath = Bundle.main.bundlePath
        let resolvedPath = URL(fileURLWithPath: bundlePath).resolvingSymlinksInPath().path
        return bundlePath.hasPrefix("/Applications/") || resolvedPath.hasPrefix("/Applications/")
    }

    // MARK: - Default placeholder windows

    private func makeDefaultOnboardingWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MCPMenuBar Onboarding"
        window.isReleasedWhenClosed = false
        window.contentView = placeholderView(title: "Welcome to MCPMenuBar")
        return window
    }

    private func makeDefaultDashboardWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MCPMenuBar Dashboard"
        window.isReleasedWhenClosed = false
        window.contentView = placeholderView(title: "MCPMenuBar Dashboard")
        return window
    }

    private func placeholderView(title: String) -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let label = NSTextField(labelWithString: title)
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])

        return view
    }
}
