# Lifecycle Integration Notes

## Files added

- `AppLifecycleManager.swift` — singleton that decides first-run vs. subsequent-run behavior.
- `WindowActivator.swift` — helper to activate `NSApplication` and bring an `NSWindow` forward.
- `FirstRunChecker.swift` — reads/writes `~/.mcp-computer-use/onboarding-complete`.
- `Lifecycle.md` — this file.

## What the main agent must wire

1. In `AppDelegate.swift`:
   - Call `AppLifecycleManager.shared.start()` after the menu bar is set up.
   - Example:

     ```swift
     func applicationDidFinishLaunching(_ notification: Notification) {
         Logger.shared.log("Reflex launched")

         permissionChecker = PermissionChecker()
         menuManager = MenuManager(delegate: self)
         serverManager = ServerManager()
         serverManager.delegate = self

         menuManager.updateStatus(text: "Idle", state: .idle)
         serverManager.start()

         AppLifecycleManager.shared.start()
     }
     ```

2. In `MenuManager.swift` (optional but recommended):
   - Add menu items that call `AppLifecycleManager.shared.showOnboarding()` and
     `AppLifecycleManager.shared.showDashboard()`.

3. In `AppDelegate.swift` (optional, after Agent 2 and Agent 6 land):
   - Replace the placeholder windows with the real onboarding/dashboard windows by
     setting factory closures **before** `start()` is called:

     ```swift
     AppLifecycleManager.shared.onboardingWindowFactory = { OnboardingWindow() }
     AppLifecycleManager.shared.dashboardWindowFactory = { DashboardWindow() }
     AppLifecycleManager.shared.start()
     ```

     If the real UI returns `NSWindowController`s, return `.window` instead, e.g.:

     ```swift
     AppLifecycleManager.shared.onboardingWindowFactory = { OnboardingWindowController().window }
     ```

## Behavior

- On first launch (`~/.mcp-computer-use/onboarding-complete` does not exist):
  - `AppLifecycleManager.start()` calls `showOnboarding()`.
  - `WindowActivator` switches `NSApplication` activation policy to `.regular` and
    calls `activate(ignoringOtherApps: true)` so the window is visible and has a Dock icon.
- On subsequent launches:
  - `start()` does nothing; the app remains in `.accessory` status-bar mode.
- `showOnboarding()` and `showDashboard()` reuse a single window instance and bring it forward.
- `completeOnboarding()` writes the first-run flag, switches back to `.accessory`,
  and closes the onboarding window.
- `isRunningFromApplications()` checks `Bundle.main.bundlePath` for `/Applications/`.

## Caveats / compile notes

- `WindowActivator` uses `NSApplication.setActivationPolicy(_:)`. If `AppDelegate.main()`
  sets the policy to `.accessory` before `app.run()`, switching to `.regular` later
  may not visually take effect until the next app launch on some macOS versions. The
  safest approach is to let `AppLifecycleManager` decide the initial policy before
  `app.run()` (see example below).
- `AppLifecycleManager` is isolated in `Features/Lifecycle/` and does not modify
  `AppDelegate.swift` or `MenuManager.swift`.

## Recommended `AppDelegate.main()` tweak

The main agent may want to change `AppDelegate.main()` from:

```swift
app.setActivationPolicy(.accessory)
```

to:

```swift
app.setActivationPolicy(AppLifecycleManager.shared.isFirstRun ? .regular : .accessory)
```

This ensures the onboarding window appears in the Dock and is key on first launch.
