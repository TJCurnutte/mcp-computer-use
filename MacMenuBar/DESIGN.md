# MCPMenuBar — Design Document

A persistent macOS menu-bar host for the `mcp-computer-use` Python MCP server. The Swift app only launches and bridges; all tool logic stays in the existing Python package.

---

## 1. Architecture

`MCPMenuBar` is a Swift/Cocoa `LSUIElement` menu-bar application:

- No Dock icon, no main window.
- Uses `NSStatusBar` to place an icon in the system status area (top-right).
- On launch it:
  1. Ensures `~/.mcp-computer-use/logs` exists.
  2. Starts a TCP listener on `127.0.0.1:0` (random high port) via the `Network` framework.
  3. Writes the assigned port to `~/.mcp-computer-use/mcp.port`.
  4. For each incoming IDE connection, spawns a fresh Python subprocess running `.venv/bin/python -m mcp_computer_use`.
  5. Bridges the IDE TCP socket with the Python process `stdin`/`stdout`/`stderr`.

The Python FastMCP server continues to speak JSON-RPC over stdio. Swift does not parse MCP messages; it shuttles bytes and tracks process lifetime.

### Data flow

```
Cursor / Windsurf / Devin CLI
        |
   TCP 127.0.0.1:<port>          (port from ~/.mcp-computer-use/mcp.port)
        |
  +--- MCPMenuBar (Swift) --------+
  |  NWListener                   |
  |   | per NWConnection          |
  |   v                           |
  |  BridgeConnection             |
  |   | spawns                    |
  |   v                           |
  |  [Process] .venv/bin/python  |
  |   `-m mcp_computer_use        |
  +-------------------------------+
```

---

## 2. IPC between IDE and Python

### Transport: TCP loopback, one subprocess per connection

- **Listener address**: `127.0.0.1` only. Public or `0.0.0.0` binding is disallowed.
- **Port selection**: `NWListener(using: .tcp, on: .any)`. The `Network` framework assigns a random high port. This avoids fixed-port conflicts.
- **Port discovery**: On listener startup, `ServerManager.writePortFile` writes the kernel-assigned port to:
  ```
  ~/.mcp-computer-use/mcp.port
  ```
  File format: a single ASCII integer, e.g. `49321` (no newline required). On stop the file is removed.
- **Multiple clients**: `SocketListener` runs an async `newConnectionHandler`. Each accepted `NWConnection` is wrapped in a new `BridgeConnection`, which spawns its own Python process. IDE clients are isolated and do not share state; one client exiting does not affect others or the listener.
- **Byte forwarding**: `BridgeConnection` uses `NWConnection.receive` and `FileHandle` async read handlers:
  - `NWConnection` data → `stdinPipe.fileHandleForWriting`
  - `stdoutPipe.fileHandleForReading` → `NWConnection.send`
  - `stderrPipe.fileHandleForReading` → `Logger` (`[py stderr] ...`)
  - No MCP framing is done in Swift; newline-delimited JSON-RPC flows through unchanged.

### Port file lifecycle

1. App starts → `SocketListener` ready → `ServerManager.listenerReady(port:)` writes the file.
2. App stops or listener fails → `ServerManager.stop()` removes the file.
3. Client bridge (`MacMenuBar/bridge/mcp_bridge.py`) retries reading the file, then connects.

---

## 3. Subprocess Management

### `ServerManager`

- Owns the `SocketListener` instance.
- Maintains `activeBridges: [BridgeConnection]` and removes bridges when they stop.
- `start()`: starts the listener and updates the menu state to `.starting`, then `.running(port:)`.
- `stop()`: cancels all active bridges, stops the listener, removes the port file, updates menu state to `.idle`.
- Handles `SocketListenerDelegate` callbacks and notifies `MenuManager` of state changes on the main queue.

### `BridgeConnection`

- Spawns a `Process` with:
  - `executableURL` = `<repo-root>/.venv/bin/python`
  - `arguments` = `["-m", "mcp_computer_use"]`
  - `currentDirectoryURL` = `<repo-root>`
  - `environment` = inherited environment plus `PYTHONUNBUFFERED=1`, `MCP_LOG_LEVEL=INFO`, and a useful `PATH`.
- Uses three `Pipe`s:
  - `stdinPipe` → child `stdin`
  - `stdoutPipe` → child `stdout` → socket
  - `stderrPipe` → child `stderr` → `Logger`
- `Process.terminationHandler` calls `stop()`, which cancels the `NWConnection` and notifies `ServerManager` via `BridgeConnectionDelegate.bridgeDidStop(_:)`.
- `stop()` is idempotent and ensures the child process is terminated if still running.

### Restart / crash behavior

- **Listener failure**: `ServerManager.listenerFailed(error:)` logs the error and updates the menu icon to `.error`. The architecture should schedule a rebind with a new random port after a short delay (not currently implemented in the skeleton but recommended).
- **Python crash per client**: only that `BridgeConnection` closes; the listener stays up and the next IDE connection spawns a fresh process.
- **App crash / quit**: `AppDelegate.applicationWillTerminate` calls `serverManager.stop()`, which cancels all connections, terminates children, and removes the port file.
- **Login restart**: the `LaunchAgent` should keep the app alive (see §7).

---

## 4. Swift Project Layout

SPM package: `MacMenuBar/MCPMenuBar/`

```
MacMenuBar/MCPMenuBar/
├── Package.swift
├── build_app.sh
├── install.sh
├── Info.plist
├── Sources/
│   └── MCPMenuBar/
│       ├── AppDelegate.swift       // @main entry, wires managers
│       ├── MenuManager.swift       // NSStatusItem, menu, SF Symbol icon state
│       ├── ServerManager.swift     // Listener lifecycle + BridgeConnection
│       ├── SocketListener.swift    // NWListener wrapper
│       ├── PermissionChecker.swift // TCC checks + open Settings
│       ├── Paths.swift             // ~/.mcp-computer-use and log paths
│       └── Logger.swift            // File logger to mcp-menubar.log
```

### File purposes

| File | Purpose |
|------|---------|
| `AppDelegate.swift` | `@main` `NSApplicationDelegate`. Creates `MenuManager`, `ServerManager`, `PermissionChecker`; starts the server; handles `applicationWillTerminate`. |
| `MenuManager.swift` | Builds the status item, menu items, delegates menu actions, and updates icon/color based on `ServerState`. |
| `ServerManager.swift` | Owns `SocketListener`; tracks active `BridgeConnection` instances; writes/removes `mcp.port`. Also defines `BridgeConnection` and its stdio/socket pump. |
| `SocketListener.swift` | Thin `NWListener` wrapper with `start()`/`stop()` and delegate callbacks for `ready`, `failed`, and `accepted`. |
| `PermissionChecker.swift` | Checks Accessibility and Screen Recording preflights; opens Privacy & Security panes. |
| `Paths.swift` | Central paths: `~/.mcp-computer-use`, `logs`, `mcp.port`. |
| `Logger.swift` | Append-only file logger with ISO8601 timestamps and 1 MiB rotation. |

### `Package.swift` (current)

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MCPMenuBar",
    platforms: [.macOS(.v13)],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MCPMenuBar",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("Network")
            ]
        )
    ]
)
```

The app uses `Foundation`, `AppKit`, `ApplicationServices`, `CoreGraphics`, and `Network`.

---

## 5. Build / Packaging

### Step 1 — compile

```bash
cd /Users/curnutte/CascadeProjects/mcp-computer-use/MacMenuBar/MCPMenuBar
swift build -c release
```

Produces `.build/release/MCPMenuBar`.

### Step 2 — wrap into `.app`

`MacMenuBar/MCPMenuBar/build_app.sh` creates `MacMenuBar/MCPMenuBar/build/MCPMenuBar.app`:

```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

swift build -c release

mkdir -p build/MCPMenuBar.app/Contents/MacOS
cp .build/release/MCPMenuBar build/MCPMenuBar.app/Contents/MacOS/MCPMenuBar
chmod +x build/MCPMenuBar.app/Contents/MacOS/MCPMenuBar

cp Info.plist build/MCPMenuBar.app/Contents/Info.plist
printf 'APPL????' > build/MCPMenuBar.app/Contents/PkgInfo

codesign -s - --force --deep build/MCPMenuBar.app

echo "Built: $SCRIPT_DIR/build/MCPMenuBar.app"
```

### Step 3 — install

```bash
cp -R MacMenuBar/MCPMenuBar/build/MCPMenuBar.app /Applications/MCPMenuBar.app
```

Then install the LaunchAgent (§7).

---

## 6. Permissions

### Which binary needs TCC permissions?

macOS grants Accessibility, Screen Recording, and Input Monitoring to the **process that calls the protected API**. The Swift wrapper only owns the menu and the socket; the spawned Python process uses `pyautogui`, `Quartz`, `mss`, and `pynput`. Therefore the user must grant the permissions to the **Python interpreter** that `.venv/bin/python` resolves to.

### Recommended `Check Permissions` flow

`PermissionChecker` should perform two checks:

1. **Swift host checks** (already in `PermissionChecker.swift`):
   - Accessibility: `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])`
   - Screen Recording: `CGPreflightScreenCaptureAccess()` / `CGRequestScreenCaptureAccess()`
2. **Python child check** (recommended addition):
   Spawn a one-off `Process`:
   ```bash
   /Users/curnutte/CascadeProjects/mcp-computer-use/.venv/bin/python -c \
     "from mcp_computer_use.actions import get_status; import json; print(get_status())"
   ```
   with `cwd = /Users/curnutte/CascadeProjects/mcp-computer-use`.
   - Parse the JSON to report Accessibility/Screen Recording/Input Monitoring status from the Python side.
   - Input Monitoring can be preflighted in Python by importing `pynput` and attempting a dummy `GlobalHotKeys` listener, or in Swift via `IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)`.

If any permission is missing, `PermissionChecker` opens the correct System Settings pane:

```swift
NSWorkspace.shared.open(
    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
)
NSWorkspace.shared.open(
    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
)
NSWorkspace.shared.open(
    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
)
```

### First-run assistant

On first launch, if permissions are missing, show a brief modal that tells the user to add the Python interpreter (the real `.venv/bin/python` target) to Accessibility, Screen Recording, and Input Monitoring, then re-run `Check Permissions`.

The app never requests `sudo` or admin rights.

---

## 7. LaunchAgent

Path: `~/Library/LaunchAgents/com.curnutte.mcp-computer-use.plist`

Recommended contents:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.curnutte.mcp-computer-use</string>

    <key>ProgramArguments</key>
    <array>
        <string>/Applications/MCPMenuBar.app/Contents/MacOS/MCPMenuBar</string>
    </array>

    <key>EnvironmentVariables</key>
    <dict>
        <key>MCP_SERVER_ROOT</key>
        <string>/Users/curnutte/CascadeProjects/mcp-computer-use</string>
        <key>PYTHONUNBUFFERED</key>
        <string>1</string>
    </dict>

    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>10</integer>

    <key>StandardOutPath</key>
    <string>/Users/curnutte/.mcp-computer-use/logs/MCPMenuBar.out.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/curnutte/.mcp-computer-use/logs/MCPMenuBar.err.log</string>
</dict>
</plist>
```

### Install / uninstall

```bash
# Install
cd /Users/curnutte/CascadeProjects/mcp-computer-use/MacMenuBar
./scripts/install_launchagent.sh

# Uninstall
launchctl unload -w ~/Library/LaunchAgents/com.curnutte.mcp-computer-use.plist
rm ~/Library/LaunchAgents/com.curnutte.mcp-computer-use.plist
```

**Note:** the LaunchAgent currently checked into `MacMenuBar/LaunchAgent/com.curnutte.mcp-computer-use.plist` has `KeepAlive` set to `false`. For automatic crash restart, set it to `true` as shown above.

---

## 8. Devin CLI Integration

### Devin config

`~/.config/devin/config.json` should include:

```json
{
  "version": 1,
  "mcpServers": {
    "mcp-computer-use": {
      "command": "/Users/curnutte/CascadeProjects/mcp-computer-use/.venv/bin/python",
      "args": [
        "/Users/curnutte/CascadeProjects/mcp-computer-use/MacMenuBar/bridge/mcp_bridge.py"
      ],
      "cwd": "/Users/curnutte/CascadeProjects/mcp-computer-use"
    }
  },
  "permissions": {
    "allow": ["mcp__*"]
  }
}
```

### Bridge script

`MacMenuBar/bridge/mcp_bridge.py` (already present) reads the port from `~/.mcp-computer-use/mcp.port`, connects to `127.0.0.1:<port>`, then proxies newline-delimited JSON-RPC between stdio and the socket using line-based file objects.

It is dependency-free (`socket`, `sys`, `threading`, `time`, `pathlib`) and can be used by Cursor, Windsurf, Claude, and Devin.

---

## 9. Menu Items

`MenuManager.swift` builds the `NSStatusItem` menu:

| Menu item | Behavior |
|-----------|----------|
| **Status label** | Disabled label like `MCPMenuBar: Idle` or `Running on port 49321`. |
| **Start Server** | Calls `ServerManager.start()`. |
| **Stop Server** | Calls `ServerManager.stop()`. |
| **Check Permissions** | Runs `PermissionChecker.checkAndRequest()`. |
| **Open Logs** | Opens `~/.mcp-computer-use/logs` in Finder. |
| **Copy Bridge Path** | Copies `127.0.0.1:<port>` to the pasteboard (or the bridge script path). |
| **Quit** | Calls `NSApp.terminate`. |

### Icon state

`MenuManager.setIcon(_:)` uses the SF Symbol `cursorarrow.rays` and tints it:

- `.idle` → `.systemGray`
- `.starting` → `.systemYellow`
- `.running` → `.systemGreen`
- `.error` → `.systemRed`

The `NSImage.isTemplate` is set to `false` so the tint is respected.

---

## 10. Security / Reliability

- **No secrets**: The app stores no API keys or credentials. All configuration comes from `~/.mcp-computer-use/config.json` or the `Process` environment.
- **No sudo**: The app and child processes run as the current user. The Python `SecurityPolicy` already blocks `sudo`, `rm -rf`, `mkfs`, `dd`, `shutdown`, etc.
- **Crash restart**:
  - `LaunchAgent` with `KeepAlive` true restarts the app if it terminates.
  - The Swift `ServerManager` should rebind with a new random port on listener failure (recommended addition).
  - One Python process per client means a crash in one IDE session does not affect others.
- **Kill switch**:
  - The Python server arms the global `Ctrl+Alt+Q` hotkey via `pynput` when Input Monitoring is granted.
  - Menu `Stop Server` and `Quit` terminate all `BridgeConnection` children.
  - Calling the `stop` MCP tool also ends the Python process.
- **Log paths** (all under `~/.mcp-computer-use/logs/`):
  - `mcp-menubar.log` — Swift app lifecycle and Python stderr.
  - `MCPMenuBar.out.log` / `MCPMenuBar.err.log` — `launchd` output.
  - `server.log` — Python FastMCP server log.
- **Local-only networking**: The `NWListener` binds to `127.0.0.1` only. No remote connections.
- **No privilege escalation**: No system extensions, helper tools, or root are used.

---

## 11. Notes for Builder Agents

- `MacMenuBar/MCPMenuBar/Info.plist` is the bundle template used by `build_app.sh`.
- The `MCP_SERVER_ROOT` env var in the LaunchAgent is not yet consumed by the Swift code; the repo path is currently hardcoded in `ServerManager.spawnProcess`. Future work: read `MCP_SERVER_ROOT` in `Paths` or `Config`.
- `PermissionChecker` currently checks the Swift host only; add a Python child diagnostic to fully satisfy §6.
- `ServerManager` currently does not auto-rebind after a listener failure; add a timed retry for true crash resilience.
