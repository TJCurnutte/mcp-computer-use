#!/usr/bin/env python3
"""MCP stdio-to-TCP bridge for the MCPMenuBar menu-bar helper.

Usage:
    /usr/bin/env python3 MacMenuBar/bridge/mcp_bridge.py

The bridge reads the TCP port from ~/.mcp-computer-use/mcp.port, connects to
127.0.0.1:<port>, then forwards newline-delimited JSON messages between
stdin/stdout and the socket. This lets a stdio-only MCP client (Devin CLI,
Cursor, Windsurf, Claude) talk to the menu-bar app's TCP server.

The bridge expects the server to send a periodic transport heartbeat so it can
exit cleanly if the server becomes unresponsive. The heartbeat is a JSON line:

    {"__mcp_menubar_heartbeat": 1}

Bridge behavior is documented in MacMenuBar/bridge/BRIDGE.md.
"""
from __future__ import annotations

import json
import socket
import sys
import threading
import time
from pathlib import Path

PORT_FILE = Path.home() / ".mcp-computer-use" / "mcp.port"
PORT_RETRIES = 50
PORT_RETRY_DELAY = 0.1
CONNECT_TIMEOUT = 5.0
SOCKET_BUFFER_SIZE = 1024 * 1024
HEARTBEAT_INTERVAL = 30.0
HEARTBEAT_TIMEOUT = 120.0
HEARTBEAT_PREFIX = b'{"__mcp_menubar_heartbeat":'
HEARTBEAT_MAX_LEN = 128


def get_port() -> int | None:
    """Read the TCP port from the menu-bar helper, retrying briefly.

    Raises PermissionError if the port file exists but cannot be read.
    """
    last_permission_error: PermissionError | None = None
    for _ in range(PORT_RETRIES):
        try:
            if not PORT_FILE.exists():
                time.sleep(PORT_RETRY_DELAY)
                continue
            text = PORT_FILE.read_text(encoding="utf-8").strip()
            port = int(text)
            if 1 <= port <= 65535:
                return port
            return None
        except PermissionError as exc:
            last_permission_error = exc
            time.sleep(PORT_RETRY_DELAY)
        except (ValueError, OSError):
            time.sleep(PORT_RETRY_DELAY)
    if last_permission_error is not None:
        raise last_permission_error
    return None


def set_socket_options(sock: socket.socket) -> None:
    """Enable TCP keepalive and large buffers for the socket."""
    try:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)
    except (OSError, ValueError):
        pass

    # macOS uses TCP_KEEPALIVE for idle time; Linux uses TCP_KEEPIDLE.
    # Python's socket module did not expose macOS TCP_KEEPALIVE before 3.10,
    # but the constant is 0x10 in <netinet/tcp.h>.
    tcp_keepalive_idle = getattr(socket, "TCP_KEEPALIVE", 0x10)
    try:
        sock.setsockopt(socket.IPPROTO_TCP, tcp_keepalive_idle, int(HEARTBEAT_INTERVAL))
    except (OSError, ValueError):
        pass

    for opt, val in (
        (socket.TCP_KEEPINTVL, 10),
        (socket.TCP_KEEPCNT, 3),
        (socket.TCP_NODELAY, 1),
    ):
        try:
            sock.setsockopt(socket.IPPROTO_TCP, opt, val)
        except (OSError, ValueError, AttributeError):
            pass

    try:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, SOCKET_BUFFER_SIZE)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, SOCKET_BUFFER_SIZE)
    except (OSError, ValueError):
        pass


def is_heartbeat(line: bytes) -> bool:
    """Return True if the line is a transport heartbeat from the server."""
    if not line.startswith(HEARTBEAT_PREFIX):
        return False
    if len(line) > HEARTBEAT_MAX_LEN:
        return False
    try:
        obj = json.loads(line)
        return obj.get("__mcp_menubar_heartbeat") == 1
    except (json.JSONDecodeError, AttributeError, TypeError):
        return False


class HeartbeatWatchdog:
    """Monitor server-side heartbeat and tear down the socket on timeout."""

    def __init__(self, sock: socket.socket, timeout: float = HEARTBEAT_TIMEOUT) -> None:
        self.sock = sock
        self.timeout = timeout
        self.last_seen = time.time()
        self.lock = threading.Lock()
        self.shutdown = threading.Event()
        self.timed_out = threading.Event()
        self.thread = threading.Thread(
            target=self._run, daemon=True, name="heartbeat-watchdog"
        )

    def update(self) -> None:
        with self.lock:
            self.last_seen = time.time()

    def _run(self) -> None:
        while not self.shutdown.is_set():
            with self.lock:
                remaining = self.timeout - (time.time() - self.last_seen)
            if remaining <= 0:
                break
            if self.shutdown.wait(min(remaining, 1.0)):
                return
        self.timed_out.set()
        self.shutdown.set()
        try:
            self.sock.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass

    def start(self) -> None:
        self.thread.start()

    def stop(self) -> None:
        self.shutdown.set()


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
        try:
            sock.shutdown(socket.SHUT_WR)
        except OSError:
            pass


def read_socket(rfile, watchdog: HeartbeatWatchdog) -> None:
    """Forward lines from the socket to stdout, dropping transport heartbeats."""
    try:
        while True:
            line = rfile.readline()
            if not line:
                break
            watchdog.update()
            if is_heartbeat(line):
                continue
            sys.stdout.buffer.write(line)
            sys.stdout.buffer.flush()
    except (BrokenPipeError, ConnectionResetError, OSError, ValueError):
        pass


def main() -> int:
    try:
        port = get_port()
    except PermissionError as exc:
        print(
            f"mcp_bridge: Permission denied reading {PORT_FILE}: {exc}",
            file=sys.stderr,
        )
        return 3

    if port is None:
        print(
            f"mcp_bridge: MCPMenuBar is not running (could not read a valid port from {PORT_FILE}).",
            file=sys.stderr,
        )
        return 1

    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    connected = False
    try:
        set_socket_options(sock)
        sock.settimeout(CONNECT_TIMEOUT)
        sock.connect(("127.0.0.1", port))
        connected = True
    except ConnectionRefusedError:
        print(
            f"mcp_bridge: Connection refused. MCPMenuBar is not running on 127.0.0.1:{port}.",
            file=sys.stderr,
        )
        return 2
    except PermissionError as exc:
        print(
            f"mcp_bridge: Permission denied connecting to 127.0.0.1:{port}: {exc}",
            file=sys.stderr,
        )
        return 3
    except (socket.timeout, TimeoutError):
        print(
            f"mcp_bridge: Connection timed out. MCPMenuBar is not responding on 127.0.0.1:{port}.",
            file=sys.stderr,
        )
        return 4
    except OSError as exc:
        print(
            f"mcp_bridge: Could not connect to 127.0.0.1:{port}: {exc}. Is MCPMenuBar running?",
            file=sys.stderr,
        )
        return 2
    finally:
        if not connected:
            try:
                sock.close()
            except OSError:
                pass

    sock.settimeout(None)

    rfile = sock.makefile("rb", buffering=SOCKET_BUFFER_SIZE)
    wfile = sock.makefile("wb", buffering=SOCKET_BUFFER_SIZE)

    watchdog = HeartbeatWatchdog(sock)
    watchdog.start()

    stdin_thread = threading.Thread(
        target=forward_stdin,
        args=(sys.stdin.buffer, wfile, sock),
        daemon=True,
        name="forward-stdin",
    )
    stdin_thread.start()

    exit_code = 0
    try:
        read_socket(rfile, watchdog)
    except KeyboardInterrupt:
        pass
    finally:
        watchdog.stop()
        if watchdog.timed_out.is_set():
            print(
                "mcp_bridge: Server is unresponsive (heartbeat timeout).",
                file=sys.stderr,
            )
            exit_code = 5
        try:
            rfile.close()
        except (OSError, ValueError):
            pass
        try:
            wfile.close()
        except (OSError, ValueError):
            pass
        try:
            sock.close()
        except (OSError, ValueError):
            pass
        watchdog.thread.join(timeout=1.0)

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
