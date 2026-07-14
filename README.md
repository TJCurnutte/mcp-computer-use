# mcp-computer-use

A local macOS MCP server that gives your AI agent eyes and hands.

## Tools

- `get_display_info` — list connected displays.
- `get_cursor_position` — get the mouse pointer location.
- `screenshot` — capture a display and return a base64 PNG.
- `mouse_move` — move the cursor.
- `mouse_click` — click, double-click, right-click.
- `mouse_scroll` — scroll at a coordinate.
- `keyboard_type` — type text.
- `key` — press a key or modifier combo.
- `hold_key` — hold a key for N seconds.
- `wait` — pause for N seconds.

## Setup

```bash
cd /Users/curnutte/CascadeProjects/mcp-computer-use
/Users/curnutte/.local/bin/python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Permissions

Grant your terminal/IDE **Accessibility** and **Screen Recording** access in:
`System Settings → Privacy & Security`.

## Test

```bash
python server.py
# In another terminal:
python test_client.py
```

## Windsurf config

Add to `~/.codeium/windsurf/mcp_config.json`:

```json
{
  "mcpServers": {
    "mcp-computer-use": {
      "command": "/Users/curnutte/CascadeProjects/mcp-computer-use/.venv/bin/python",
      "args": ["/Users/curnutte/CascadeProjects/mcp-computer-use/server.py"],
      "cwd": "/Users/curnutte/CascadeProjects/mcp-computer-use"
    }
  }
}
```

Restart Windsurf.
