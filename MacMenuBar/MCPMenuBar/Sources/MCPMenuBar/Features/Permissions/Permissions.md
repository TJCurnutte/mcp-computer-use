# Permissions Feature

## Files

- `PermissionsManager.swift` — `PermissionsManager` and `PermissionStatus`
- `PermissionsView.swift` — `NSView`-based checklist (optional)
- `Permissions.md` — this file

## What it does

`PermissionsManager` checks and requests the three privacy permissions the app needs:

- **Accessibility** — `AXIsProcessTrustedWithOptions`
- **Screen Recording** — `CGPreflightScreenCaptureAccess` / `CGRequestScreenCaptureAccess`
- **Input Monitoring** — `IOHIDCheckAccess` / `IOHIDRequestAccess` (`kIOHIDRequestTypeListenEvent`)

It exposes a `PermissionStatus` list for onboarding and dashboard UIs and can open the correct System Settings > Privacy & Security pane for each permission.

## Public API

```swift
let manager = PermissionsManager()

// Check individual permissions
manager.checkAccessibility()
manager.checkScreenRecording()
manager.checkInputMonitoring()

// Request them (shows the system prompt and/or opens System Settings)
manager.requestAccessibility()
manager.requestScreenRecording()
manager.requestInputMonitoring()

// Open the right pane directly
manager.openSystemSettings(for: .screenRecording)

// Aggregate helpers
if manager.allPermissionsGranted() { ... }
manager.status(for: .accessibility)
manager.refresh()
```

## Integration for onboarding

1. Create one shared `PermissionsManager` instance in the onboarding controller.
2. Call `manager.requestX()` from the permission page buttons.
3. Observe `manager.$statuses` or `manager.allPermissionsGranted()` to enable the **Continue** button.
4. Use `PermissionsView` to show a live checklist:

```swift
let view = PermissionsView(permissionsManager: manager)
```

## Integration for dashboard

```swift
let manager = PermissionsManager()
manager.startMonitoring(interval: 1.0)

// Bind `manager.statuses` to a list UI.
```

## Notes

- `PermissionsManager` is intended to supersede `PermissionChecker.swift`. Do not modify or delete `PermissionChecker.swift` per the master-plan rules; the main integration agent can swap in `PermissionsManager` later.
- The System Settings URL scheme uses the legacy `x-apple.systempreferences:com.apple.preference.security?Privacy_*` anchors because they still work on macOS 13+ and open the right sub-pane.
- `PermissionChecker` currently prompts automatically. `PermissionsManager` separates **check** (no prompt) from **request** (prompts/opens settings) so the UI can be explicit.
