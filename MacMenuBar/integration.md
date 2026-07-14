# MCPMenuBar Integration Guide

This directory wires the `MCPMenuBar` macOS menu-bar app (built by Agent 2) to
stdio-only MCP clients such as the Devin CLI, Cursor, and Windsurf.

At runtime:

1. `MCPMenuBar` starts a Python MCP server internally and exposes it over TCP.
2. It writes the listening port to `~/.mcp-computer-use/mcp.port`.
3. `bridge/mcp_bridge.py` reads that port, connects to `127.0.0.1:<port>`, and
   proxies newline-delimited JSON-RPC between stdio and the TCP socket.
4. IDEs configure `mcp_bridge.py` as a normal stdio MCP server.

---

## Devin CLI config snippet

Edit `~/.config/devin/config.json` so the `mcpServers` section contains both
the existing `mac-use-mcp` server and the new `mcp-computer-use` bridge. Do
not remove or alter `mac-use-mcp`.

```json
{
  "version": 1,
  "mcpServers": {
    "mac-use-mcp": {
      "command": "/Users/curnutte/.local/bin/node",
      "args": [
        "/Users/curnutte/.hermes/node/lib/node_modules/mac-use-mcp/dist/index.js"
      ]
    },
    "mcp-computer-use": {
      "command": "/Users/curnutte/CascadeProjects/mcp-computer-use/.venv/bin/python",
      "args": [
        "/Users/curnutte/CascadeProjects/mcp-computer-use/MacMenuBar/bridge/mcp_bridge.py"
      ],
      "cwd": "/Users/curnutte/CascadeProjects/mcp-computer-use"
    }
  },
  "permissions": {
    "allow": [
      "mcp__*"
    ]
  }
}
```

After saving, restart the Devin CLI or start a new session.

---

## Windsurf / Cursor config snippet

Add the `mcp-computer-use` server to the IDE's MCP config file.

- **Windsurf:** `~/.codeium/windsurf/mcp_config.json`
- **Cursor:** `~/.cursor/mcp.json`

```json
{
  "mcpServers": {
    "mcp-computer-use": {
      "command": "/Users/curnutte/CascadeProjects/mcp-computer-use/.venv/bin/python",
      "args": [
        "/Users/curnutte/CascadeProjects/mcp-computer-use/MacMenuBar/bridge/mcp_bridge.py"
      ],
      "cwd": "/Users/curnutte/CascadeProjects/mcp-computer-use"
    }
  }
}
```

Restart the IDE window after editing the file.

---

## Verifying the connection

With `MCPMenuBar` running (either launched manually or via the LaunchAgent),
run:

```bash
cd /Users/curnutte/CascadeProjects/mcp-computer-use/MacMenuBar
python tests/test_bridge.py
```

Add `--screenshot` to also exercise the screenshot tool:

```bash
python tests/test_bridge.py --screenshot
```
