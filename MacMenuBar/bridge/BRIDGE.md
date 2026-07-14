# mcp_bridge

`mcp_bridge.py` is a stdio-to-TCP bridge for MCPMenuBar. It is a drop-in
stdio MCP transport that forwards newline-delimited JSON lines between the
client's stdin/stdout and the MCPMenuBar TCP server on `127.0.0.1`.

## Usage

```
python3 MacMenuBar/bridge/mcp_bridge.py
```

## Behavior

1. Read `~/.mcp-computer-use/mcp.port` (retrying for up to 5 seconds).
2. Connect to `127.0.0.1:<port>`.
3. Enable TCP keepalive and large socket buffers.
4. Start two threads:
   - `forward-stdin`: reads stdin and sends each line to the server.
   - `heartbeat-watchdog`: expects a heartbeat from the server at least every
     120 seconds; if not, it shuts down the socket so the bridge exits.
5. The read loop writes server lines to stdout. It drops server heartbeat
   lines (`{"__mcp_menubar_heartbeat": 1}`) so the client never sees them.
6. Flushes after each line to keep JSON-RPC clients responsive and to handle
   large base64 image lines.

## Error codes

| Code | Meaning | Example message |
|------|---------|-----------------|
| 0 | Clean shutdown | — |
| 1 | MCPMenuBar is not running / no valid port | `MCPMenuBar is not running (could not read a valid port ...)` |
| 2 | Connection refused or other connect error | `Connection refused. MCPMenuBar is not running on 127.0.0.1:<port>.` |
| 3 | Permission denied | `Permission denied reading ...` |
| 4 | Connection timed out | `Connection timed out. MCPMenuBar is not responding ...` |
| 5 | Server unresponsive (heartbeat timeout) | `Server is unresponsive (heartbeat timeout).` |

## Notes

- The bridge is a dumb line pipe; it does not parse JSON-RPC, so it works with
  any MCP client that uses stdio.
- It is meant to be launched by an MCP client config, not run directly.
