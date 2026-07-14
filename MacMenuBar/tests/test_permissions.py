#!/usr/bin/env python3
"""Verify Accessibility and Screen Recording permissions via the bridge.

Usage:
    python tests/test_permissions.py

The test expects ~/.mcp-computer-use/mcp.port to exist. It spawns
bridge/mcp_bridge.py, calls the get_status tool, and asserts:

    permissions.screen_recording == True
    permissions.accessibility == True

If the server does not yet expose permissions.accessibility in get_status,
the test falls back to a run_shell_command probe that checks
AXIsProcessTrustedWithOptions. The bridge port file is written by MCPMenuBar.
"""

from __future__ import annotations

import asyncio
import builtins
import json
import select
import shlex
import subprocess
import sys
from contextlib import AsyncExitStack
from pathlib import Path

BRIDGE = Path(__file__).resolve().parents[1] / "bridge" / "mcp_bridge.py"
PORT_FILE = Path.home() / ".mcp-computer-use" / "mcp.port"
PYTHON = Path(__file__).resolve().parents[2] / ".venv" / "bin" / "python"

ACCESSIBILITY_SCRIPT = (
    "import ApplicationServices; "
    "opts = {ApplicationServices.kAXTrustedCheckOptionPrompt: False}; "
    'print("ACCESSIBILITY:", ApplicationServices.AXIsProcessTrustedWithOptions(opts))'
)
ACCESSIBILITY_PROBE = f"{shlex.quote(str(PYTHON))} -c {shlex.quote(ACCESSIBILITY_SCRIPT)}"

# Optional official MCP SDK path.
try:
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.stdio import stdio_client

    HAS_MCP = True
except Exception:
    HAS_MCP = False


def _print_nested_exception(exc: BaseException) -> None:
    BaseExceptionGroupType = getattr(builtins, "BaseExceptionGroup", None)
    if BaseExceptionGroupType is not None and isinstance(exc, BaseExceptionGroupType):
        for e in exc.exceptions:
            _print_nested_exception(e)
    else:
        print(f"  {type(exc).__name__}: {exc}", file=sys.stderr)


def _read_response(proc: subprocess.Popen, timeout: float = 15.0) -> dict | None:
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


def _send(proc: subprocess.Popen, obj: dict) -> None:
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


def _call_tool_stdlib(proc: subprocess.Popen, name: str, arguments: dict) -> dict | None:
    """Send a tools/call request and return the JSON-RPC result, or None."""
    req_id = _call_tool_stdlib.next_id  # type: ignore[attr-defined]
    _call_tool_stdlib.next_id += 1  # type: ignore[attr-defined]
    _send(
        proc,
        {
            "jsonrpc": "2.0",
            "id": req_id,
            "method": "tools/call",
            "params": {"name": name, "arguments": arguments},
        },
    )
    return _read_response(proc)


_call_tool_stdlib.next_id = 2  # type: ignore[attr-defined]


def _extract_text(result: dict) -> str:
    content = result.get("content", [])
    if content and content[0].get("type") == "text":
        return content[0].get("text", "")
    return ""


def _check_screen_recording(status: dict) -> bool:
    perms = status.get("permissions", {})
    return bool(perms.get("screen_recording"))


def _check_accessibility_from_status(status: dict) -> bool | None:
    perms = status.get("permissions", {})
    value = perms.get("accessibility")
    if value is None:
        return None
    return bool(value)


def _parse_shell_output(text: str) -> bool:
    """Return True if the accessibility probe reports True."""
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return False
    stdout = data.get("stdout", "")
    return "ACCESSIBILITY: True" in stdout


def stdlib_test() -> int:
    proc = subprocess.Popen(
        [sys.executable, str(BRIDGE)],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    try:
        # MCP initialize
        _send(
            proc,
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "initialize",
                "params": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {},
                    "clientInfo": {"name": "test-permissions", "version": "0.1.0"},
                },
            },
        )
        init_resp = _read_response(proc)
        if init_resp is None:
            print("Bridge closed before initialize response.", file=sys.stderr)
            _print_bridge_error(proc)
            return 1

        _send(proc, {"jsonrpc": "2.0", "method": "notifications/initialized"})

        # get_status
        status_resp = _call_tool_stdlib(proc, "get_status", {})
        if status_resp is None or "result" not in status_resp:
            print("No get_status response.", file=sys.stderr)
            _print_bridge_error(proc)
            return 1

        status_text = _extract_text(status_resp["result"])
        try:
            status = json.loads(status_text)
        except json.JSONDecodeError:
            print(f"get_status returned non-JSON: {status_text!r}", file=sys.stderr)
            return 1

        if status.get("status") != "ok":
            print(f"get_status reported status: {status.get('status')}", file=sys.stderr)
            return 1

        if not _check_screen_recording(status):
            print("Screen Recording permission is not granted.", file=sys.stderr)
            return 1

        accessibility = _check_accessibility_from_status(status)
        if accessibility is None:
            # get_status does not expose accessibility yet; probe via shell.
            print("get_status does not expose accessibility; using shell probe.", flush=True)
            shell_resp = _call_tool_stdlib(
                proc, "run_shell_command", {"command": ACCESSIBILITY_PROBE, "timeout": 10}
            )
            if shell_resp is None or "result" not in shell_resp:
                print("Accessibility probe failed: no response.", file=sys.stderr, flush=True)
                return 1
            shell_text = _extract_text(shell_resp["result"])
            accessibility = _parse_shell_output(shell_text)

        if not accessibility:
            print("Accessibility permission is not granted.", file=sys.stderr, flush=True)
            return 1

        print("Permissions test passed.")
        return 0
    except Exception as exc:
        print("Test error:", file=sys.stderr)
        _print_nested_exception(exc)
        _print_bridge_error(proc)
        return 1
    finally:
        # Stop the bridge process first. Closing stdin first can block if the
        # bridge's reader is stuck, so we terminate/kill before closing the pipe.
        try:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)
        except Exception:
            pass
        finally:
            try:
                if proc.stdin:
                    proc.stdin.close()
            except OSError:
                pass


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
                    print(f"get_status returned non-JSON: {status_text!r}", file=sys.stderr)
                    return 1
            else:
                print("No get_status response.", file=sys.stderr)
                return 1

            if status.get("status") != "ok":
                print(f"get_status reported status: {status.get('status')}", file=sys.stderr)
                return 1

            if not _check_screen_recording(status):
                print("Screen Recording permission is not granted.", file=sys.stderr)
                return 1

            accessibility = _check_accessibility_from_status(status)
            if accessibility is None:
                print("get_status does not expose accessibility; using shell probe.", flush=True)
                shell_result = await session.call_tool(
                    "run_shell_command",
                    arguments={"command": ACCESSIBILITY_PROBE, "timeout": 10},
                )
                if shell_result.content and shell_result.content[0].type == "text":
                    shell_text = shell_result.content[0].text
                    accessibility = _parse_shell_output(shell_text)
                else:
                    accessibility = False

            if not accessibility:
                print("Accessibility permission is not granted.", file=sys.stderr, flush=True)
                return 1

            print("Permissions test passed.")
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
        print(
            f"{PORT_FILE} is missing. Is MCPMenuBar running and has it written its TCP port?",
            file=sys.stderr,
        )
        return 1

    if HAS_MCP:
        return asyncio.run(mcp_test())
    return stdlib_test()


if __name__ == "__main__":
    sys.exit(main())
