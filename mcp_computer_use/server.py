"""FastMCP server entry point."""

import json
import os
import sys
from pathlib import Path

from mcp.server.fastmcp import FastMCP

from . import actions as act
from .config import CONFIG
from .kill_switch import start_kill_switch
from .utils import setup_logging

# Tesseract on macOS can fail if TMPDIR is /tmp, so point it to a stable place.
_tmp_dir = Path.home() / ".mcp-computer-use" / "tmp"
_tmp_dir.mkdir(parents=True, exist_ok=True)
for _var in ("TMPDIR", "TEMP", "TMP"):
    os.environ[_var] = str(_tmp_dir)

# Set up logging before anything else
setup_logging(CONFIG.log_dir, CONFIG.log_level)

# Arm the global emergency kill switch when Accessibility is granted.
start_kill_switch()

mcp = FastMCP("mcp-computer-use")


@mcp.tool()
def screenshot(display: int = 0, scale: bool = True) -> str:
    """Take a screenshot and return a base64-encoded PNG with metadata."""
    return json.dumps(act.take_screenshot(display, scale))


@mcp.tool()
def get_display_info() -> str:
    """Get information about all connected displays."""
    return json.dumps(act.get_display_info())


@mcp.tool()
def get_cursor_position() -> str:
    """Return the current mouse cursor position."""
    return json.dumps(act.get_cursor_position())


@mcp.tool()
def mouse_move(x: int, y: int, duration: float = 0.2) -> str:
    """Move the cursor to the given (x, y) coordinate in model screenshot space."""
    return json.dumps(act.mouse_move(x, y, duration))


@mcp.tool()
def mouse_click(
    x: int,
    y: int,
    button: str = "left",
    clicks: int = 1,
) -> str:
    """Click at the given (x, y) coordinate in model screenshot space."""
    return json.dumps(act.mouse_click(x, y, button, clicks))


@mcp.tool()
def mouse_scroll(x: int, y: int, scroll_x: int = 0, scroll_y: int = 0) -> str:
    """Scroll the mouse wheel at the given (x, y) coordinate."""
    return json.dumps(act.mouse_scroll(x, y, scroll_x, scroll_y))


@mcp.tool()
def keyboard_type(text: str) -> str:
    """Type the given text as if it were typed on the keyboard."""
    return json.dumps(act.keyboard_type(text))


@mcp.tool()
def key(keys: str) -> str:
    """Press a key or key combination, e.g. 'cmd+c' or 'shift+tab'.

    Modifiers should be joined with '+'.
    """
    return json.dumps(act.key(keys))


@mcp.tool()
def hold_key(key: str, duration: float = 1.0) -> str:
    """Hold a key down for a number of seconds."""
    return json.dumps(act.hold_key(key, duration))


@mcp.tool()
def wait(duration: float = 1.0) -> str:
    """Wait for a number of seconds."""
    return json.dumps(act.wait(duration))


@mcp.tool()
def run_shell_command(command: str = "", timeout: int = 60, cwd: str = "", pending_id: str = "") -> str:
    """Run a shell command. Only allowlisted commands are permitted."""
    return json.dumps(act.run_shell_command(command, timeout, cwd or None, pending_id))


@mcp.tool()
def open_app(name: str) -> str:
    """Open/activate a macOS application by name, e.g. 'Terminal' or 'Safari'."""
    return json.dumps(act.open_app(name))


@mcp.tool()
def list_windows() -> str:
    """List visible windows with app name, title, position, and size."""
    return json.dumps(act.list_windows())


@mcp.tool()
def focus_window(app_name: str, window_name: str = "") -> str:
    """Focus a window of an application."""
    return json.dumps(act.focus_window(app_name, window_name or None))


@mcp.tool()
def clipboard_get() -> str:
    """Read the current clipboard contents."""
    return json.dumps(act.clipboard_get())


@mcp.tool()
def clipboard_set(text: str) -> str:
    """Write text to the clipboard."""
    return json.dumps(act.clipboard_set(text))


@mcp.tool()
def batch_operations(operations: str) -> str:
    """Run a list of operations sequentially. Input is a JSON string of a list
    of objects with an 'action' key and the corresponding tool arguments."""
    try:
        ops = json.loads(operations)
    except json.JSONDecodeError as e:
        return json.dumps({"error": f"invalid JSON: {e}"})
    return json.dumps(act.batch(ops))


@mcp.tool()
def ocr_screenshot(display: int = 0) -> str:
    """Capture a screenshot and return all text recognized by OCR."""
    return json.dumps(act.ocr_screenshot(display))


@mcp.tool()
def find_text_on_screen(text: str, display: int = 0) -> str:
    """Find the bounding boxes of the given text on the screen."""
    return json.dumps(act.find_text_on_screen(text, display))


@mcp.tool()
def get_status() -> str:
    """Return server status and current permission state."""
    return json.dumps(act.get_status())


@mcp.tool()
def stop() -> str:
    """Stop the MCP server process."""
    return json.dumps(act.stop())


@mcp.tool()
def read_file(path: str) -> str:
    """Read a file under allowed directories."""
    return json.dumps(act.read_file(path))


@mcp.tool()
def write_file(path: str, content: str) -> str:
    """Write a file under allowed directories."""
    return json.dumps(act.write_file(path, content))


@mcp.tool()
def list_dir(path: str) -> str:
    """List files and directories under allowed directories."""
    return json.dumps(act.list_dir(path))


@mcp.tool()
def delete_file(path: str) -> str:
    """Delete a file or directory under allowed directories."""
    return json.dumps(act.delete_file(path))


@mcp.tool()
def confirm_sensitive_action(pending_id: str) -> str:
    """Confirm and execute a previously queued sensitive action."""
    return json.dumps(act.confirm_sensitive_action(pending_id))


@mcp.tool()
def click_text(text: str, display: int = 0, button: str = "left", click_index: int = 0) -> str:
    """Find the given text on screen and click the center of the n-th match."""
    return json.dumps(act.click_text(text, display, button, click_index))


def main():
    mcp.run()


if __name__ == "__main__":
    main()
