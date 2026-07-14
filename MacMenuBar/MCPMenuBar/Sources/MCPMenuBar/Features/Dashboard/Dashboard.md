# Dashboard

A status/control window for MCPMenuBar.

## Files

- `DashboardWindow.swift` — `NSWindowController` subclass that builds the dashboard window.
- `DashboardViewController.swift` — AppKit view with status labels, server controls, permissions, logs, bridge test, and copy-config buttons.
- `DashboardController.swift` — Manages dashboard state, observes `ServerManager`, and updates the UI via delegate callbacks.
- `Dashboard.md` — this file.

## Wiring

1. Create and keep a `DashboardController` in `AppDelegate` (or the lifecycle manager):
   ```swift
   private var dashboardController: DashboardController!
   dashboardController = DashboardController(
       serverManager: serverManager,
       permissionChecker: permissionChecker
   )
   ```
   `DashboardController` sets `serverManager.delegate = self` in its `init`.

2. Forward server state to `MenuManager`/`AppDelegate` if needed:
   ```swift
   dashboardController.stateForwardDelegate = appDelegate
   ```
   Do not reassign `serverManager.delegate` after this, or the dashboard will stop receiving state updates.

3. Open the dashboard from a menu item or global hotkey:
   ```swift
   dashboardController.show()
   ```
   `DashboardWindow` will become key and the app will activate.

## Buttons

- **Start/Stop Server** — calls `ServerManager.start()` / `ServerManager.stop()`.
- **Check Permissions** — calls `PermissionChecker.checkAccessibility()` and `checkScreenRecording()`, updates the permissions label, and opens System Settings for any missing permissions.
- **Open Logs** — opens `~/.mcp-computer-use/logs` in Finder.
- **Test Bridge** — runs `MacMenuBar/tests/test_bridge.py` with the `.venv` python if present, otherwise `/usr/bin/python3`. It expects `~/.mcp-computer-use/mcp.port` to exist.
- **Copy Bridge Config** — copies the Devin CLI `mcpServers` snippet for `mcp-computer-use` to the pasteboard.

## Notes

- No external dependencies; uses `Foundation` and `AppKit`.
- The `repoURL` is the local repo path. For a bundled `.app`, adjust the `repoURL`/`pythonURL`/`mcpBridgeURL`/`testBridgeURL` paths or copy the bridge/test resources into the app bundle.
