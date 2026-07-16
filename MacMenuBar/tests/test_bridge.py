#!/usr/bin/env python3
"""Smoke test for the mcp_bridge stdio-to-TCP bridge.

Usage:
    python tests/test_bridge.py
    python tests/test_bridge.py --screenshot

The script expects `~/.mcp-computer-use/mcp.port` to exist (written by
Reflex). It starts `mcp_bridge.py`, sends an MCP `initialize` request,
lists tools, calls `get_status`, and optionally calls `screenshot`.

If the menu-bar app is not running, the test exits cleanly with a helpful
message instead of crashing.
"""

import asyncio
import json
import logging
import select
import subprocess
import sys
from contextlib import AsyncExitStack
from pathlib import Path
from typing import Any

# Suppress noisy-but-harmless POSIX process-group termination warnings from the
# optional `mcp` SDK on macOS.
logging.getLogger("mcp.os.posix.utilities").setLevel(logging.ERROR)
logging.getLogger("mcp.client.stdio").setLevel(logging.ERROR)
logging.getLogger("anyio").setLevel(logging.ERROR)

BRIDGE = Path(__file__).resolve().parents[1] / "bridge" / "mcp_bridge.py"
PORT_FILE = Path.home() / ".mcp-computer-use" / "mcp.port"


def _read_response(proc: subprocess.Popen, timeout: float = 15.0) -> Any:
    """Read one JSON-RPC line from the bridge stdout, or None on timeout/EOF."""
    try:
        ready, _, _ = select.select([proc.stdout], [], [], timeout)
        if not ready:
            return None
        line = proc.stdout.readline()
        if not line:
            return None
        return json.loads(line.decode("utf-8"))
    except (json.JSONDecodeError, OSError):
        return None


def _print_nested_exception(exc: BaseException) -> None:
    """Print a (possibly grouped) exception in a concise way."""
    if isinstance(exc, BaseExceptionGroup):
        for e in exc.exceptions:
            _print_nested_exception(e)
    else:
        print(f"  {type(exc).__name__}: {exc}", file=sys.stderr)


def _send(proc: subprocess.Popen, obj: Any) -> None:
    line = json.dumps(obj) + "\n"
    proc.stdin.write(line.encode("utf-8"))
    proc.stdin.flush()


def _print_bridge_error(proc: subprocess.Popen) -> None:
    try:
        err = proc.stderr.read(4096).decode("utf-8", errors="replace")
        if err.strip():
            print("Bridge stderr:", err.strip(), file=sys.stderr)
    except OSError:
        pass


def stdlib_test() -> int:
    proc = subprocess.Popen(
        [sys.executable, str(BRIDGE)],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    try:
        # MCP initialize request
        init_id = 1
        _send(
            proc,
            {
                "jsonrpc": "2.0",
                "id": init_id,
                "method": "initialize",
                "params": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {},
                    "clientInfo": {"name": "test-bridge", "version": "0.1.0"},
                },
            },
        )
        init_resp = _read_response(proc)
        if init_resp is None:
            print("Bridge closed before initialize response.", file=sys.stderr)
            _print_bridge_error(proc)
            return 1
        print("initialize response:", init_resp)

        # Required initialized notification
        _send(proc, {"jsonrpc": "2.0", "method": "notifications/initialized"})

        # List tools
        _send(proc, {"jsonrpc": "2.0", "id": 2, "method": "tools/list"})
        list_resp = _read_response(proc)
        if list_resp:
            tools = list_resp.get("result", {}).get("tools", [])
            print(f"tools/list: {len(tools)} tools available")

        # Call get_status
        _send(
            proc,
            {
                "jsonrpc": "2.0",
                "id": 3,
                "method": "tools/call",
                "params": {"name": "get_status", "arguments": {}},
            },
        )
        status_resp = _read_response(proc)
        if status_resp and "result" in status_resp:
            content = status_resp["result"].get("content", [])
            if content and content[0].get("type") == "text":
                status_text = content[0].get("text", "")
                try:
                    status = json.loads(status_text)
                except json.JSONDecodeError:
                    status = status_text
                print("get_status:", json.dumps(status) if isinstance(status, dict) else status)
        else:
            print("No get_status response (server may not be running).", file=sys.stderr)
            _print_bridge_error(proc)
            return 1

        # Optional screenshot
        if "--screenshot" in sys.argv:
            _send(
                proc,
                {
                    "jsonrpc": "2.0",
                    "id": 4,
                    "method": "tools/call",
                    "params": {
                        "name": "screenshot",
                        "arguments": {"display": 0, "scale": True},
                    },
                },
            )
            ss_resp = _read_response(proc)
            if ss_resp and "result" in ss_resp:
                content = ss_resp["result"].get("content", [])
                if content and content[0].get("type") == "text":
                    ss_text = content[0].get("text", "")
                    try:
                        ss = json.loads(ss_text)
                    except json.JSONDecodeError:
                        ss = {}
                    keys = [k for k in ss.keys() if k != "image"]
                    print("screenshot response keys (excluding image):", keys)

        print("Bridge test passed.")
        return 0
    except Exception as exc:
        print("Test error:", file=sys.stderr)
        _print_nested_exception(exc)
        _print_bridge_error(proc)
        return 1
    finally:
        if proc.stdin:
            try:
                proc.stdin.close()
            except OSError:
                pass
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=5)


# Optional richer test path using the official `mcp` SDK if available.
try:
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.stdio import stdio_client

    HAS_MCP = True
except Exception:
    HAS_MCP = False


async def mcp_test() -> int:
    params = StdioServerParameters(
        command=sys.executable,
        args=[str(BRIDGE)],
        env=None,
    )
    try:
        async with AsyncExitStack() as stack:
            stdio_transport = await stack.enter_async_context(stdio_client(params))
            session = await stack.enter_async_context(ClientSession(*stdio_transport))
            await session.initialize()

            status_result = await session.call_tool("get_status", arguments={})
            if status_result.content and status_result.content[0].type == "text":
                status_text = status_result.content[0].text
                try:
                    status = json.loads(status_text)
                except json.JSONDecodeError:
                    status = status_text
                print("get_status:", json.dumps(status) if isinstance(status, dict) else status)

            if "--screenshot" in sys.argv:
                ss_result = await session.call_tool(
                    "screenshot", arguments={"display": 0, "scale": True}
                )
                if ss_result.content and ss_result.content[0].type == "text":
                    ss_text = ss_result.content[0].text
                    try:
                        ss = json.loads(ss_text)
                    except json.JSONDecodeError:
                        ss = {}
                    keys = [k for k in ss.keys() if k != "image"]
                    print("screenshot response keys (excluding image):", keys)

            print("Bridge test passed.")
            return 0
    except Exception as exc:
        print("mcp SDK test error:", file=sys.stderr)
        _print_nested_exception(exc)
        return 1


def main() -> int:
    if not BRIDGE.exists():
        print(f"Bridge not found at {BRIDGE}", file=sys.stderr)
        return 1
    if not PORT_FILE.exists():
        print(f"{PORT_FILE} is missing. Is Reflex running?", file=sys.stderr)
        return 0

    print(f"Found port file: {PORT_FILE}")
    if HAS_MCP:
        return asyncio.run(mcp_test())
    return stdlib_test()


if __name__ == "__main__":
    sys.exit(main())
