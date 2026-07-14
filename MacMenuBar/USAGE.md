# MCPMenuBar — User Walkthrough

A step-by-step guide from download to first use.

## 1. Download and install

1. Download the latest `.dmg` or `.zip` from the release page.
2. Open the `.dmg` and drag `MCPMenuBar.app` to `/Applications`.
3. Double-click `/Applications/MCPMenuBar.app` to launch it.

> **Tip:** The first time you open an app downloaded from the internet, macOS may
> show a security warning. Go to `System Settings → Privacy & Security` and click
> **Open Anyway**.

## 2. First-run onboarding

When `MCPMenuBar` launches for the first time, an onboarding window appears:

1. **Move to Applications** — confirms the app is in `/Applications/MCPMenuBar.app`.
2. **Permissions** — opens `System Settings → Privacy & Security` and asks for:
   - **Accessibility** — for mouse and keyboard control.
   - **Screen Recording** — for screenshots and OCR.
   - **Input Monitoring** — for the global kill-switch hotkey (`Ctrl+Alt+Q`).
3. **IDE config** — installs the MCP config for Devin, Windsurf, and/or Cursor.
4. **Test Connection** — calls `get_status` and `screenshot` to verify everything works.

The onboarding window closes automatically and `MCPMenuBar` moves to the menu bar.

## 3. Menu bar and dashboard

Look for the `MCPMenuBar` icon in the top-right menu bar. Click it to:

- See the current server status and port.
- Start or stop the server.
- Check permissions.
- Open the dashboard.
- Open logs in Finder.
- Copy the bridge address.
- Quit the app.

Open the dashboard from the menu or with the global hotkey (default `⌃⌥M` or
`⇧⌘M`, depending on the build). The dashboard shows:

- Server state (idle / starting / running / error)
- Current TCP port
- Logs and permissions
- A quick **Test Connection** button

## 4. Configure your IDE

The onboarding step writes the MCP config for you. If you skipped it, add the
`mcp-computer-use` server manually:

- **Devin CLI:** `~/.config/devin/config.json`
- **Windsurf:** `~/.codeium/windsurf/mcp_config.json`
- **Cursor:** `~/.cursor/mcp.json`

See `integration.md` for the exact JSON snippets.

## 5. Start at login

To start `MCPMenuBar` automatically when you log in, run:

```bash
cd /Users/curnutte/CascadeProjects/mcp-computer-use/MacMenuBar
./scripts/install_launchagent.sh
```

This installs and loads a LaunchAgent that runs `/Applications/MCPMenuBar.app`.

## 6. Verify the setup

Run the integration tests:

```bash
cd /Users/curnutte/CascadeProjects/mcp-computer-use/MacMenuBar
../.venv/bin/python tests/test_bridge.py
../.venv/bin/python tests/test_bridge.py --screenshot
../.venv/bin/python tests/test_onboarding.py
../.venv/bin/python tests/test_permissions.py
```

If `test_permissions.py` fails, re-run onboarding or grant permissions for the
Python interpreter at `mcp-computer-use/.venv/bin/python` in
`System Settings → Privacy & Security`.

## 7. Use it

Open your IDE or Devin CLI. The `mcp-computer-use` MCP server is now available
and can:

- Take screenshots and run OCR.
- Move and click the mouse.
- Type and press keys.
- Run allowlisted shell commands.
- Read and write files in allowed directories.

The Python interpreter (`mcp-computer-use/.venv/bin/python`) is the process that
needs Accessibility, Screen Recording, and Input Monitoring permissions.
