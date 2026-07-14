# Hotkey Feature

## Files

- `GlobalHotkey.swift` — low-level global/local shortcut registration.
- `HotkeyManager.swift` — app-level wrapper that wires the hotkey to the dashboard.
- `Hotkey.md` — this file.

## Default shortcut

`Control + Option + M` (`⌃⌥M`).

`HotkeyManager` exposes `keyCode` and `modifiers` so the main integration can change it later.

## Public API

```swift
// Start listening and wire it to the dashboard
HotkeyManager.shared.dashboardController = dashboardController
HotkeyManager.shared.start()

// Stop
HotkeyManager.shared.stop()

// Change the shortcut
HotkeyManager.shared.keyCode = UInt16(kVK_ANSI_M)
HotkeyManager.shared.modifiers = [.command, .shift]
HotkeyManager.shared.start()
```

## How it works

1. `GlobalHotkey` tries `Carbon` `RegisterEventHotKey` first. This is a true global hotkey and does **not** require any privacy permission.
2. If `Carbon` fails, it falls back to `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)` plus a local monitor. This path needs the app to be granted:
   - **Accessibility** (`Privacy & Security → Accessibility`)
   - **Input Monitoring** (`Privacy & Security → Input Monitoring`)
3. If global is not feasible, `NSEvent.addLocalMonitorForEvents` is used — the shortcut only works when the app is active.

## Permission handling

`HotkeyManager` uses `PermissionsManager` to check and request the required permissions.

- `requestPermissions()` asks for `Accessibility` and `Input Monitoring`.
- `permissionExplanation` gives a short, user-friendly message.

The `NSEvent` global monitor is only used when both `Accessibility` and `Input Monitoring` are granted. If not, the app falls back to the local monitor (or Carbon, which works without permission).

## Integration

In `AppDelegate.applicationDidFinishLaunching`:

```swift
HotkeyManager.shared.dashboardController = dashboardController
HotkeyManager.shared.start()
```

`HotkeyManager` itself activates the app and calls `dashboardController?.show()` when the hotkey fires.

## Notes

- `GlobalHotkey` uses `DispatchQueue.main.async` to fire the action so UI calls happen on the main thread.
- `HotkeyManager` does not currently auto-restart after the user grants permissions; call `HotkeyManager.shared.start()` again (or poll `PermissionsManager`) if you want live upgrade.
- `Package.swift` does not need explicit framework links; `Carbon` and `IOKit` are auto-linked by the Swift compiler when imported.
