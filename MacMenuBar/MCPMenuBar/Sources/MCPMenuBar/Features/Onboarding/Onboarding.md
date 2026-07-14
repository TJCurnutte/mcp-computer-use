# Onboarding Integration Notes

## Files

- `OnboardingController.swift` — `ObservableObject` + `OnboardingDelegate` that manages the flow.
- `OnboardingState.swift` — enum of the five onboarding steps.
- `OnboardingDelegate.swift` — protocol used by the UI to forward user actions.
- `OnboardingWindow.swift` — thin window wrapper around `OnboardingPageViewController`.

## Expected `OnboardingWindow` interface

The controller only expects:

```swift
final class OnboardingWindow: NSWindowController {
    weak var onboardingDelegate: OnboardingDelegate?
    func show()
    func close()
}
```

The implementation creates an `NSWindow` whose `contentViewController` is `OnboardingPageViewController` and sets its `onboardingDelegate` to `self.onboardingDelegate`. If Agent 2 provides a different window controller, it can be passed to `init(window:)`.

## Wiring in `AppDelegate`

```swift
import Foundation

let flagURL = Paths.mcpDirectory.appendingPathComponent("onboarding-complete")
let shouldOnboard = !FileManager.default.fileExists(atPath: flagURL.path)

if shouldOnboard {
    let onboarding = OnboardingController(
        // Optional: pass explicit paths if MCP_SERVER_ROOT is not set.
        repoRoot: URL(fileURLWithPath: "/Users/curnutte/CascadeProjects/mcp-computer-use"),
        bridgeURL: URL(fileURLWithPath: "/Users/curnutte/CascadeProjects/mcp-computer-use/MacMenuBar/bridge/mcp_bridge.py")
    )
    onboarding.start()
}
```

If `OnboardingController` is initialized with `window: nil`, it creates an `OnboardingWindow` containing `OnboardingPageViewController`.

## What the controller does

1. `moveToApplications` — checks `Bundle.main.bundlePath` against `/Applications/MCPMenuBar.app`.
2. `permissions` — uses `PermissionChecker` for Accessibility and Screen Recording.
3. `installConfig` — updates `~/.config/devin/config.json` and `~/.codeium/windsurf/mcp_config.json` if they exist; otherwise shows a copyable snippet.
4. `test` — spawns `mcp_bridge.py` as a subprocess and sends `get_status` and `screenshot` JSON-RPC calls.
5. `complete` — writes `~/.mcp-computer-use/onboarding-complete` and closes the window.

## Dependencies

- `PermissionChecker` (existing) for TCC checks.
- `Logger` and `Paths` (existing) for logging and path helpers.
- `mcp_bridge.py` script at `MacMenuBar/bridge/mcp_bridge.py`.
- `MCP_SERVER_ROOT` env var, or explicit `repoRoot`/`bridgeURL` in `init`.

## Notes for Agent 2

`OnboardingWindow.swift` now wraps `OnboardingPageViewController` and `OnboardingView`. `OnboardingPageViewController` already calls `OnboardingDelegate` methods from its action buttons. The controller updates `OnboardingController.state` (it is `@Published`) after each action so it can be observed by a custom UI if needed.
