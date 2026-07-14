#!/usr/bin/env python3
"""MCP stdio-to-TCP bridge for the MCPMenuBar menu-bar helper.

Usage:
    /usr/bin/env python3 MacMenuBar/bridge/mcp_bridge.py

The bridge reads the TCP port from ~/.mcp-computer-use/mcp.port, connects to
127.0.0.1:<port>, then forwards newline-delimited JSON-RPC messages between
stdin/stdout and the socket. This lets a stdio-only MCP client (Devin CLI,
Cursor, Windsurf, Claude) talk to the menu-bar app's TCP server.
"""

import socket
import sys
import threading
import time
from pathlib import Path

PORT_FILE = Path.home() / ".mcp-computer-use" / "mcp.port"
PORT_RETRIES = 50
PORT_RETRY_DELAY = 0.1


def get_port() -> int | None:
    """Read the TCP port from the menu-bar helper, retrying briefly."""
    for _ in range(PORT_RETRIES):
        try:
            if PORT_FILE.exists():
                text = PORT_FILE.read_text(encoding="utf-8").strip()
                port = int(text)
                if 1 <= port <= 65535:
                    return port
        except (ValueError, OSError):
            pass
        time.sleep(PORT_RETRY_DELAY)
    return None


def forward_stdin(stdin, wfile, sock) -> None:
    """Forward lines from stdin to the socket."""
    try:
        while True:
            line = stdin.readline()
            if not line:
                break
            wfile.write(line)
            wfile.flush()
    except (BrokenPipeError, ConnectionResetError, OSError, ValueError):
        pass
    finally:
        # Signal that we have no more data to send; this lets the read loop
        # finish cleanly when the remote server closes the connection.
        try:
            sock.shutdown(socket.SHUT_WR)
        except OSError:
            pass


def read_socket(rfile) -> None:
    """Forward lines from the socket to stdout."""
    try:
        while True:
            line = rfile.readline()
            if not line:
                break
            sys.stdout.buffer.write(line)
            sys.stdout.buffer.flush()
    except (BrokenPipeError, ConnectionResetError, OSError, ValueError):
        pass


def main() -> int:
    port = get_port()
    if port is None:
        print(
            f"mcp_bridge: could not read a valid port from {PORT_FILE}. "
            "Is MCPMenuBar running and has it written its TCP port?",
            file=sys.stderr,
        )
        return 1

    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect(("127.0.0.1", port))
    except OSError as exc:
        print(
            f"mcp_bridge: could not connect to 127.0.0.1:{port}: {exc}. "
            "Make sure MCPMenuBar is running.",
            file=sys.stderr,
        )
        return 2

    # Line-based binary file objects as requested.
    rfile = sock.makefile("rb")
    wfile = sock.makefile("wb")

    stdin_thread = threading.Thread(
        target=forward_stdin,
        args=(sys.stdin.buffer, wfile, sock),
        daemon=True,
    )
    stdin_thread.start()

    try:
        read_socket(rfile)
    except KeyboardInterrupt:
        pass
    finally:
        try:
            sock.close()
        except OSError:
            pass

    return 0


if __name__ == "__main__":
    sys.exit(main())
