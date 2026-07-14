# MacMenuBar Integration

This folder connects the `MCPMenuBar` macOS menu-bar app to stdio-based MCP
clients like the Devin CLI, Cursor, and Windsurf.

## What lives here

- `bridge/mcp_bridge.py` — stdio-to-TCP proxy that Devin/IDEs invoke as their
  MCP server command.
- `LaunchAgent/com.curnutte.mcp-computer-use.plist` — macOS LaunchAgent that
  starts `MCPMenuBar` at user login.
- `scripts/install_launchagent.sh` — copies the plist and loads it with
  `launchctl`.
- `tests/` — integration tests:
  - `test_bridge.py` — smoke test that checks the bridge can connect, send
    an MCP `initialize`, call `get_status`, and optionally take a screenshot.
  - `test_onboarding.py` — checks the onboarding-complete marker and runs
    `test_bridge.py`.
  - `test_permissions.py` — verifies Accessibility and Screen Recording status
    via the bridge.
  - `QA.md` — manual QA checklist.
- `integration.md` — exact config snippets for Devin CLI, Windsurf, and Cursor.
- `USAGE.md` — user-facing walkthrough from download to first use.

## Build the menu-bar app

The Swift app itself lives in `MCPMenuBar/` and is produced by the builder
agent:

```bash
cd /Users/curnutte/CascadeProjects/mcp-computer-use/MacMenuBar/MCPMenuBar
./build_app.sh
```

`build_app.sh` writes `build/MCPMenuBar.app`. Install it to `/Applications`:

```bash
./install.sh      # uses sudo to copy build/MCPMenuBar.app to /Applications
```

Or copy it manually:

```bash
cp -R build/MCPMenuBar.app /Applications/MCPMenuBar.app
```

## Install the LaunchAgent

The LaunchAgent starts `MCPMenuBar` at login and logs to
`~/.mcp-computer-use/logs/`.

```bash
cd /Users/curnutte/CascadeProjects/mcp-computer-use/MacMenuBar
./scripts/install_launchagent.sh
```

To start it immediately without logging out:

```bash
launchctl start com.curnutte.mcp-computer-use
```

## Onboarding & dashboard

On first launch, `MCPMenuBar` opens an onboarding window that walks through:

1. Moving the app to `/Applications` (if not already there).
2. Granting **Accessibility**, **Screen Recording**, and **Input Monitoring**
   permissions for the Python interpreter (`mcp-computer-use/.venv/bin/python`).
3. Installing Devin / Windsurf / Cursor MCP config.
4. Running a **Test Connection** that calls `get_status` and `screenshot`.

After onboarding, the app lives in the menu bar and a dashboard window shows
live status: start/stop server, current port, logs, permissions, and a quick
bridge test. A global hotkey opens the dashboard.

## Configure your IDE / agent

See `integration.md` for the exact JSON to add to:

- `~/.config/devin/config.json` (Devin CLI)
- `~/.codeium/windsurf/mcp_config.json` (Windsurf)
- `~/.cursor/mcp.json` (Cursor)

For Devin CLI, keep the existing `mac-use-mcp` server unchanged and add the
`mcp-computer-use` bridge entry.

## Test the integration

With `MCPMenuBar` running (LaunchAgent or manually), run:

```bash
cd /Users/curnutte/CascadeProjects/mcp-computer-use/MacMenuBar
../.venv/bin/python tests/test_bridge.py
```

To also exercise the screenshot tool:

```bash
../.venv/bin/python tests/test_bridge.py --screenshot
```

After completing onboarding, verify the onboarding marker and run the bridge test:

```bash
../.venv/bin/python tests/test_onboarding.py
```

Verify Accessibility and Screen Recording permissions via the bridge:

```bash
../.venv/bin/python tests/test_permissions.py
```

If a test reports that `~/.mcp-computer-use/mcp.port` is missing, the
menu-bar app is not running or has not written its port yet.

## How a Devin CLI client connects

1. Devin spawns `mcp_bridge.py` as a stdio MCP server.
2. The bridge reads `~/.mcp-computer-use/mcp.port` and retries briefly if the
   file is not yet present.
3. It opens a TCP connection to `127.0.0.1:<port>`, where `MCPMenuBar` is
   listening.
4. It proxies newline-delimited JSON-RPC: stdin → socket and socket → stdout.
5. When the socket closes or the user interrupts, the bridge exits cleanly.
