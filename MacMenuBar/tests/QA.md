# MCPMenuBar Manual QA Checklist

Run through this list before shipping a new build.

## Install

- [ ] Download the `.dmg` or `.zip`.
- [ ] Drag `MCPMenuBar.app` to `/Applications`.
- [ ] Double-click `/Applications/MCPMenuBar.app`.

## First run

- [ ] The first-run onboarding window appears.
- [ ] The permissions prompt opens (Accessibility / Screen Recording / Input Monitoring).
- [ ] Grant permissions in `System Settings → Privacy & Security` for the Python interpreter that `.venv/bin/python` resolves to.

## Config

- [ ] Devin/Windsurf/Cursor config is updated or copied to the IDE.
- [ ] `mcp-computer-use` is present in the IDE's MCP config pointing to `MacMenuBar/bridge/mcp_bridge.py`.

## Integration tests

- [ ] `../.venv/bin/python tests/test_bridge.py` passes.
- [ ] `../.venv/bin/python tests/test_onboarding.py` passes.
- [ ] `../.venv/bin/python tests/test_permissions.py` passes.
- [ ] `../.venv/bin/python tests/test_bridge.py --screenshot` returns a screenshot.

## Runtime

- [ ] The menu-bar icon appears in the top-right and shows a status menu.
- [ ] The dashboard window opens.
- [ ] The global hotkey opens the dashboard.
- [ ] Start/Stop, Check Permissions, Open Logs, and Copy Bridge Path menu items work.
- [ ] LaunchAgent loads at login (`launchctl list | grep com.curnutte.mcp-computer-use`).

## Sign-off

- [ ] All boxes checked.
- [ ] No crashes in `~/.mcp-computer-use/logs/MCPMenuBar.err.log`.
