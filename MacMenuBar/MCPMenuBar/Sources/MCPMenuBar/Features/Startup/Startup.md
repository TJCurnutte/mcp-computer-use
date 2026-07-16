# Startup / LaunchAgent Integration

## What `StartupManager` does

`StartupManager` is a singleton (`StartupManager.shared`) that self-manages the
`com.curnutte.mcp-computer-use` LaunchAgent so `Reflex.app` can start at
login.

Public API:

```swift
func isLaunchAgentInstalled() -> Bool
func installLaunchAgent() -> Bool
func uninstallLaunchAgent() -> Bool
func isRunningAtLogin() -> Bool
func toggleStartAtLogin() -> Bool   // @objc, usable as a menu action
```

`StartupManager` is an `ObservableObject` and publishes `startAtLoginEnabled`,
which UI can observe to reflect the current state.

## How it finds the LaunchAgent plist

1. `Bundle.main.url(forResource:withExtension:subdirectory:)` — for packaged
   `Contents/Resources/LaunchAgent/com.curnutte.mcp-computer-use.plist`.
2. `Bundle.main.resourceURL`/`LaunchAgent` — fallback if the packager places the
   plist at the top of `Contents/Resources`.
3. Walks up from the executable until it finds `MacMenuBar/LaunchAgent/...`.
   This works when running from the build tree or `.build/debug`.
4. If none of the above is found, it falls back to a built-in template that
   matches the repository plist.

For a distributed `.app`, make sure the packager copies
`MacMenuBar/LaunchAgent/com.curnutte.mcp-computer-use.plist` into
`Reflex.app/Contents/Resources/LaunchAgent/`.

## Wiring the menu

In `MenuManager.swift` (or `AppDelegate.swift`) add a menu item:

```swift
let startAtLoginItem = NSMenuItem(
    title: "Start at Login",
    action: #selector(StartupManager.shared.toggleStartAtLogin),
    keyEquivalent: ""
)
startAtLoginItem.target = StartupManager.shared
menu.addItem(startAtLoginItem)
```

To keep the menu state correct, observe `StartupManager.shared.startAtLoginEnabled`:

```swift
StartupManager.shared.$startAtLoginEnabled
    .receive(on: DispatchQueue.main)
    .sink { [weak self] enabled in
        self?.updateStartAtLoginItem(state: enabled)
    }
    .store(in: &cancellables)
```

## LaunchAgent plist

The repository plist at
`MacMenuBar/LaunchAgent/com.curnutte.mcp-computer-use.plist` uses the
`__HOME__` placeholder for log paths. Both `install_launchagent.sh` and
`StartupManager` expand it to the current user's home directory before copying
it to `~/Library/LaunchAgents/`.

Key properties:

- `ProgramArguments`: `/Applications/Reflex.app/Contents/MacOS/MCPMenuBar`
- `RunAtLoad`: `true`
- `KeepAlive`: `false`
- `StandardOutPath`/`StandardErrorPath`: `~/.mcp-computer-use/logs/Reflex.*.log`

## Manual install

```bash
./MacMenuBar/scripts/install_launchagent.sh
```

This script is safe to re-run, does not use `sudo`, and creates
`~/.mcp-computer-use/logs`.

## Notes

- `launchctl load -w` is used to enable the agent.
- `launchctl unload -w` is used to disable and remove it.
- `toggleStartAtLogin()` calls `refreshStatus()` and posts no extra notification
  beyond `startAtLoginEnabled` updates.
