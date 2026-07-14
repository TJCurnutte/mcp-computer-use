# MCPMenuBar 2.0 — Master Plan

## Goal

Turn the current `mcp-computer-use` server into a real, polished macOS app that a user can drag into `/Applications`, walk through first-run setup, and actually see/control from the menu bar. Make it "smarter" with a dashboard, global hotkey, auto-restart, and robust permissions handling.

## Why the user sees nothing right now

The current `MCPMenuBar` is an `LSUIElement` status-bar app. It starts a TCP listener and runs the Python server, but:
- It has no visible first-run window, so the user cannot tell it is running.
- The menu-bar icon may be hidden behind the "..." overflow or the user may not know where to look.
- There is no onboarding, no drag-to-installer, and no explanation of what to do next.
- Permissions are not requested proactively; the user only gets a system prompt when the tool is first used.
- The bridge config is not auto-installed.

## Success criteria

1. A user can download a `.dmg`, drag `MCPMenuBar.app` to `/Applications`, and double-click it.
2. On first launch, a visible onboarding window appears, walks through:
   - "Move to Applications" check (if not already there)
   - Accessibility / Screen Recording / Input Monitoring permissions
   - Devin / Windsurf / Cursor MCP config auto-install (or snippet copy)
   - A quick "Test Connection" that calls `get_status` and `screenshot`
3. The app shows a persistent top-right icon with a useful menu and a dashboard window.
4. A global hotkey (e.g., `⌃⌥M` or `⇧⌘M`) opens the dashboard or triggers a "computer use" prompt.
5. The app auto-restarts on crash, handles reconnection, and shows clear status/errors.
6. The build produces a `.dmg` and a `.zip` suitable for distribution.
7. All changes are committed and pushed to `TJCurnutte/mcp-computer-use`.

## Architecture and conventions

- **Swift target**: `MacMenuBar/MCPMenuBar/Sources/MCPMenuBar/`.
- **Feature isolation**: Each agent creates a `FeatureName` group under `Sources/MCPMenuBar/Features/`. The only allowed top-level source edits are:
  - `AppDelegate.swift` (main agent integration only)
  - `MenuManager.swift` (main agent integration only)
  - `ServerManager.swift` / `SocketListener.swift` (Agent 8 IPC only)
  - `bridge/mcp_bridge.py` (Agent 8 only)
- **Shared services**: `Logger`, `Paths`, `ServerManager` (existing). New services should be `ObservableObject` or delegate-based where possible.
- **UI style**: Use `NSWindowController` + `NSViewController` for macOS windows. Prefer `NSTabView` for onboarding pages.
- **Distribution**: `MacMenuBar/Distribution/` will hold DMG/zip assets and scripts.

## 10-agent deployment

| # | Agent | Mission | Key outputs |
|---|-------|---------|--------------|
| 1 | **Packager** | Create a drag-to-Applications DMG and `.zip` installer. | `MacMenuBar/Distribution/create_dmg.sh`, `MacMenuBar/Distribution/README.md`, `.dmg` assets |
| 2 | **Onboarding UI** | Build the first-run onboarding window and page UI. | `Sources/MCPMenuBar/Features/Onboarding/OnboardingWindow.swift`, `OnboardingPageView.swift` |
| 3 | **Onboarding Logic** | Implement first-run state machine, /Applications check, and permissions walkthrough. | `Sources/MCPMenuBar/Features/Onboarding/OnboardingController.swift` |
| 4 | **Lifecycle & Visibility** | Ensure the app shows a visible window at first launch, handles activation, and wires onboarding into `AppDelegate` via extension/hooks. | `Sources/MCPMenuBar/Features/Lifecycle/AppLifecycleManager.swift`, `INTEGRATION.md` |
| 5 | **Permissions Manager** | Proactive TCC checks, request dialogs, and status reporting. | `Sources/MCPMenuBar/Features/Permissions/PermissionsManager.swift` |
| 6 | **Dashboard** | Build a status/control window: start/stop, port, logs, permissions, test. | `Sources/MCPMenuBar/Features/Dashboard/DashboardWindow.swift`, `DashboardController.swift` |
| 7 | **Global Hotkey** | Add a global shortcut to open the dashboard / trigger a prompt. | `Sources/MCPMenuBar/Features/Hotkey/GlobalHotkey.swift` |
| 8 | **IPC & Bridge** | Harden the TCP bridge and listener: add heartbeat, clean errors, reconnection, and single-port stability. | `Sources/MCPMenuBar/ServerManager.swift` (refactor), `SocketListener.swift`, `bridge/mcp_bridge.py` |
| 9 | **Startup & LaunchAgent** | In-app "Start at Login" toggle and self-installing LaunchAgent. | `Sources/MCPMenuBar/Features/Startup/StartupManager.swift`, `LaunchAgent/com.curnutte.mcp-computer-use.plist` update |
| 10 | **QA & Docs** | Write tests, update README/integration guides, and produce a QA checklist. | `MacMenuBar/tests/`, `MacMenuBar/README.md`, `MacMenuBar/integration.md` updates |

## Integration order

1. Agents create isolated files.
2. Main agent (orchestrator) merges into `AppDelegate`, `MenuManager`, and `ServerManager`.
3. Main agent builds `.app`, packages `.dmg`/`.zip`, and runs `test_bridge`.
4. Commit and push.

## Risk mitigations

- All agents must **not** modify existing files outside their scope.
- Agents must provide `README.md` in their feature directory if the main agent must wire anything.
- Build must remain green after each agent's output.
- No hardcoded secrets or sudo in scripts.
