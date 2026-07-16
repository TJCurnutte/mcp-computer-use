# Reflex IPC Protocol

The Reflex app runs a TCP server on the loopback interface. The bridge
(`MacMenuBar/bridge/mcp_bridge.py`) and the menu-bar app use this protocol.

## Transport

- **Address:** `127.0.0.1` (IPv4 loopback only).
- **Discovery:** the app writes the listening port to `~/.mcp-computer-use/mcp.port`.
- **Atomic port file:** the file is written with `String(..., atomically: true)`
  (a temp file + rename) and is removed when the listener stops or fails.

## Framing

Protocol-agnostic: each message is a single line of UTF-8 text terminated by `\n`.
The payload is normally newline-delimited JSON (JSON-RPC, MCP, etc.) but the
transport layer does not interpret it.

## Heartbeat

The server sends a transport heartbeat line every 30 seconds:

```json
{"__mcp_menubar_heartbeat": 1}
```

The bridge receives this line, resets its watchdog, and does **not** forward it
to stdout. The bridge watchdog times out after 120 seconds of silence from the
server, then tears down the socket so the bridge exits.

## TCP keepalive

The bridge enables `SO_KEEPALIVE` and tunes macOS `TCP_KEEPALIVE` (idle = 30 s,
interval = 10 s, count = 3) so dead TCP peers are detected in about 60 seconds.

## Process lifecycle

Each accepted connection spawns a Python `mcp_computer_use` process. If the
process crashes or the connection fails, the server cancels the `NWConnection`,
logs the event, and the listener continues accepting new clients.

## Large messages

The bridge uses 1 MiB socket buffers and flushes after each line to support
large base64 image lines.
