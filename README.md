# mcp-computer-use

Enterprise-grade macOS MCP server that gives your AI agent eyes, hands, and a terminal.

## Tools

- **Screenshot / display**
  - `screenshot` — capture a display and return a base64 PNG.
  - `screenshot_region` — capture a region of the screen.
  - `get_display_info` — list connected displays.
  - `get_cursor_position` — get the mouse pointer location.
  - `ocr_screenshot` — run OCR on the screen and return all text.
  - `find_text_on_screen` — find bounding boxes of text on the screen.

- **Mouse / keyboard**
  - `mouse_move`, `mouse_click`, `mouse_scroll`
  - `keyboard_type`, `key`, `hold_key`

- **System / apps**
  - `open_app` — open/activate an app by name.
  - `list_windows` — list visible windows.
  - `focus_window` — focus a window.
  - `clipboard_get`, `clipboard_set`
  - `run_shell_command` — run a shell command (allowlisted).
  - `confirm_sensitive_action` — approve a pending shell or file action.
  - `get_status` — show server status and permission state.
  - `stop` — stop the MCP server process.

- **File system**
  - `read_file`, `write_file`, `list_dir`, `delete_file`

- **OCR / automation**
  - `ocr_screenshot`, `find_text_on_screen`
  - `click_text` — click text found by OCR.

- **Processes**
  - `process_start` — start a long-running shell command.
  - `process_read` — read output from a running process.
  - `process_kill` — send a signal to a running process.

- **Batch**
  - `batch_operations` — run a JSON list of operations sequentially.

## Setup

```bash
cd /Users/curnutte/CascadeProjects/mcp-computer-use
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Permissions

Grant your terminal/IDE the following permissions in `System Settings → Privacy & Security`:

- **Screen Recording** — needed for screenshots, OCR, and Quartz window listing.
- **Accessibility** — needed for mouse/keyboard control and window focus.
- **Input Monitoring** — needed for the `Ctrl+Alt+Q` global kill switch (pynput will warn until this is granted).

If the pynput warning "This process is not trusted! Input event monitoring will not be possible..." appears, the kill switch is armed but cannot receive hotkeys until the host process is added to `Input Monitoring`.

## Test

```bash
source .venv/bin/activate
python test_client.py
```

## Windsurf config

Add to `~/.codeium/windsurf/mcp_config.json`:

```json
{
  "mcpServers": {
    "mcp-computer-use": {
      "command": "/Users/curnutte/CascadeProjects/mcp-computer-use/.venv/bin/python",
      "args": ["-m", "mcp_computer_use"],
      "cwd": "/Users/curnutte/CascadeProjects/mcp-computer-use"
    }
  }
}
```

Restart Windsurf.

## Using the skill

The `use_skill.py` script demonstrates how the server can be used to run terminal commands and manage the project.

```bash
source .venv/bin/activate
python use_skill.py
```

## Configuration

Create `~/.mcp-computer-use/config.json` to override defaults:

```json
{
  "max_screenshot_dim": 1280,
  "allowed_shell_commands": ["git", "python", "python3", "node", "npm", "ls", "pwd", "cat", "echo", "which"],
  "blocked_shell_commands": ["rm -rf", "sudo", "mkfs", "dd", ">/dev/null", "shutdown", "reboot", "poweroff"],
  "confirm_sensitive": true
}
```

## Kill switch

The server arms a global `Ctrl+Alt+Q` hotkey via `pynput` when supported. If it cannot be armed, the server still runs and the process can be killed by the user or an agent calling the `stop` tool.

## License

MIT
