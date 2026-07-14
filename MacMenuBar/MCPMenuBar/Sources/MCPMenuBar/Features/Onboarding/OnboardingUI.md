# Onboarding UI

This feature provides the first-run setup window for MCPMenuBar.

## Files

- `OnboardingWindow.swift` — `NSWindowController` subclass that creates the setup window.
- `OnboardingPage.swift` — `OnboardingPageViewController` that drives the five-page flow (Welcome, Move to Applications, Permissions, IDE Config, Test).
- `OnboardingView.swift` — `NSView` container that shows the page icon, title, body, action button, and Back/Next navigation.
- `OnboardingDelegate.swift` — protocol for the object that performs the actual work.

## Usage

```swift
import AppKit

class AppCoordinator: OnboardingDelegate {
    func showSetup() {
        let window = OnboardingWindow(onboardingDelegate: self)
        window.showOnboarding()
    }

    // MARK: - OnboardingDelegate

    func onboardingDidRequestMoveToApplications() {
        // Check /Applications location or prompt the user.
    }

    func onboardingDidRequestPermissions() {
        // Open System Settings to Accessibility / Screen Recording / Input Monitoring.
    }

    func onboardingDidRequestInstallConfig() {
        // Install or copy the MCP config for the user's IDE.
    }

    func onboardingDidRequestTest() {
        // Call get_status and/or screenshot to verify the bridge.
    }

    func onboardingDidFinish() {
        // Persist first-run completion and resume normal status-bar operation.
    }
}
```

## Behavior

- The window is titled **"MCPMenuBar Setup"**, centered, resizable, and has a minimum size of 600×400.
- Pages are shown in order:
  1. **Welcome** — explains the app.
  2. **Move to Applications** — asks the user to keep the app in `/Applications`.
  3. **Permissions** — asks for Accessibility, Screen Recording, and Input Monitoring.
  4. **IDE Config** — installs the MCP bridge config for Devin / Windsurf / Cursor.
  5. **Test** — runs a quick status/screenshot test.
- Each page displays an SF Symbol, a title, a short explanation, and a step-specific action button.
- **Back/Next** buttons navigate through the pages. On the last page the Next button becomes **Finish** and calls `onboardingDidFinish()`.

## Wiring notes

- `OnboardingWindow` forwards all `OnboardingDelegate` calls to the object you pass in.
- `OnboardingWindow` closes itself after `onboardingDidFinish()` is called.
- Do not modify `AppDelegate.swift` or `MenuManager.swift` in this feature; that will be done by the integration agent.
