import AppKit
import Foundation

/// The ordered onboarding pages and their content.
enum OnboardingPage: CaseIterable {
    case welcome
    case moveToApplications
    case permissions
    case ideConfig
    case test

    var title: String {
        switch self {
        case .welcome:            return "Welcome to Reflex"
        case .moveToApplications: return "Move to Applications"
        case .permissions:        return "Grant Permissions"
        case .ideConfig:          return "Configure Your IDE"
        case .test:               return "Test the Connection"
        }
    }

    var body: String {
        switch self {
        case .welcome:
            return "Reflex runs in your menu bar and bridges macOS control to your MCP client. This setup only takes a minute."
        case .moveToApplications:
            return "For the best experience, keep Reflex in your /Applications folder. If it is not already there, move it now."
        case .permissions:
            return "Reflex needs Accessibility, Screen Recording, and Input Monitoring permissions to control your Mac safely."
        case .ideConfig:
            return "Install the MCP bridge config for your IDE (Devin, Windsurf, Cursor, etc.) so it can talk to Reflex."
        case .test:
            return "Run a quick status check and screenshot to confirm everything is connected."
        }
    }

    var iconName: String {
        switch self {
        case .welcome:            return "hand.wave.fill"
        case .moveToApplications: return "folder"
        case .permissions:        return "lock.shield"
        case .ideConfig:          return "gearshape.2"
        case .test:               return "checkmark.circle"
        }
    }

    var actionButtonTitle: String? {
        switch self {
        case .welcome:            return nil
        case .moveToApplications: return "Move to Applications"
        case .permissions:        return "Open System Settings"
        case .ideConfig:          return "Install IDE Config"
        case .test:               return "Test Connection"
        }
    }

    var nextButtonTitle: String {
        switch self {
        case .welcome: return "Get Started"
        case .test:    return "Finish"
        default:       return "Next"
        }
    }

    var isBackEnabled: Bool {
        switch self {
        case .welcome: return false
        default:       return true
        }
    }
}

/// The view controller that owns the onboarding view and drives the page flow.
final class OnboardingPageViewController: NSViewController {

    weak var onboardingDelegate: OnboardingDelegate?

    private let pages: [OnboardingPage] = OnboardingPage.allCases
    private var currentIndex: Int = 0

    override func loadView() {
        view = OnboardingView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let onboardingView = view as? OnboardingView else { return }

        onboardingView.onBack = { [weak self] in self?.goBack() }
        onboardingView.onNext = { [weak self] in self?.goNext() }
        onboardingView.onAction = { [weak self] in self?.performAction() }

        updateView()
    }

    private func updateView() {
        let page = pages[currentIndex]
        (view as? OnboardingView)?.configure(for: page)
    }

    @objc private func goBack() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        updateView()
    }

    @objc private func goNext() {
        if currentIndex == pages.count - 1 {
            onboardingDelegate?.onboardingDidFinish()
        } else {
            currentIndex += 1
            updateView()
        }
    }

    @objc private func performAction() {
        switch pages[currentIndex] {
        case .moveToApplications:
            onboardingDelegate?.onboardingDidRequestMoveToApplications()
        case .permissions:
            onboardingDelegate?.onboardingDidRequestPermissions()
        case .ideConfig:
            onboardingDelegate?.onboardingDidRequestInstallConfig()
        case .test:
            onboardingDelegate?.onboardingDidRequestTest()
        case .welcome:
            break
        }
    }
}
