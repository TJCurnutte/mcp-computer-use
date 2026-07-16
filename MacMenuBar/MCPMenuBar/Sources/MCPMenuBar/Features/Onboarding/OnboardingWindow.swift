import AppKit
import Foundation

/// The onboarding window controller.
///
/// Wraps `OnboardingPageViewController` (Agent 2's UI) and exposes the
/// `delegate`/`show()`/`close()` interface `OnboardingController` expects.
final class OnboardingWindow: NSWindowController {
    weak var onboardingDelegate: OnboardingDelegate? {
        didSet {
            pageViewController?.onboardingDelegate = onboardingDelegate
        }
    }

    private var pageViewController: OnboardingPageViewController?

    init(delegate: OnboardingDelegate?) {
        let pageViewController = OnboardingPageViewController()
        pageViewController.onboardingDelegate = delegate
        self.pageViewController = pageViewController

        let contentSize = NSSize(width: 680, height: 440)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = pageViewController
        window.title = "Reflex Setup"
        window.minSize = NSSize(width: 600, height: 400)
        window.isReleasedWhenClosed = false

        super.init(window: window)
        self.onboardingDelegate = delegate
    }

    convenience init() {
        self.init(delegate: nil)
    }

    convenience init(onboardingDelegate: OnboardingDelegate?) {
        self.init(delegate: onboardingDelegate)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showOnboarding() {
        show()
    }

    func closeOnboarding() {
        close()
    }
}
