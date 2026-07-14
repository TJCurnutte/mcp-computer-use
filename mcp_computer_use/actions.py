"""Concrete actions for the computer-use server."""

import json
import os
import shutil
import subprocess
import threading
import time
import uuid
from pathlib import Path
from typing import Optional

import pyautogui
from .config import CONFIG
from .ocr import find_text, find_text_lines, ocr_image
from .process_manager import PROCESS_MANAGER
from .security import SECURITY
from .utils import (
    capture,
    click_scale_for_all_screens,
    get_logger,
    image_to_base64,
    list_displays,
    resize_for_model,
    scale_to_logical,
    scale_to_physical,
)

logger = get_logger("mcp-computer-use.actions")

pyautogui.FAILSAFE = CONFIG.fail_safe


# ---------------------------------------------------------------------------
# Screenshot / display
# ---------------------------------------------------------------------------

def get_display_info() -> dict:
    return {
        "displays": list_displays(),
        "scale_factor": _get_scale_factor(),
    }


def _get_scale_factor() -> float:
    try:
        import Quartz
        main_id = Quartz.CGMainDisplayID()
        bounds = Quartz.CGDisplayBounds(main_id)
        pixel_width = Quartz.CGDisplayPixelsWide(main_id)
        return pixel_width / bounds.size.width
    except Exception:
        return 1.0


def take_screenshot(display: int = 0, scale: bool = True) -> dict:
    img, monitor = capture(display)
    original_width, original_height = img.width, img.height
    if scale:
        img = resize_for_model(img, CONFIG.max_screenshot_dim)
    b64 = image_to_base64(img, CONFIG.screenshot_format, CONFIG.jpeg_quality)
    return {
        "width": img.width,
        "height": img.height,
        "original_width": original_width,
        "original_height": original_height,
        "display": display,
        "scale_factor": _get_scale_factor(),
        "click_scale": click_scale_for_all_screens(CONFIG.max_screenshot_dim) if scale else 1.0,
        "image": f"data:image/png;base64,{b64}",
    }


def screenshot_region(left: int, top: int, width: int, height: int, scale: bool = True) -> dict:
    """Capture a region of the screen and return a base64 PNG."""
    img, _ = capture(region=(left, top, width, height))
    original_width, original_height = img.width, img.height
    if scale:
        img = resize_for_model(img, CONFIG.max_screenshot_dim)
    b64 = image_to_base64(img, CONFIG.screenshot_format, CONFIG.jpeg_quality)
    return {
        "width": img.width,
        "height": img.height,
        "original_width": original_width,
        "original_height": original_height,
        "region": (left, top, width, height),
        "scale_factor": _get_scale_factor(),
        "image": f"data:image/png;base64,{b64}",
    }


def get_cursor_position() -> dict:
    px, py = pyautogui.position()
    scale = click_scale_for_all_screens(CONFIG.max_screenshot_dim)
    x, y = scale_to_logical(px, py, scale)
    return {"x": x, "y": y, "physical_x": px, "physical_y": py, "click_scale": scale}


# ---------------------------------------------------------------------------
# Mouse / keyboard
# ---------------------------------------------------------------------------

def _physical_point(x: int, y: int) -> tuple:
    scale = click_scale_for_all_screens(CONFIG.max_screenshot_dim)
    return scale_to_physical(x, y, scale)


def mouse_move(x: int, y: int, duration: Optional[float] = None) -> dict:
    dur = duration if duration is not None else CONFIG.move_duration
    px, py = _physical_point(x, y)
    pyautogui.moveTo(px, py, duration=dur)
    return {"x": px, "y": py}


def mouse_click(x: int, y: int, button: str = "left", clicks: int = 1) -> dict:
    px, py = _physical_point(x, y)
    pyautogui.click(px, py, button=button, clicks=clicks, duration=0.1)
    return {"clicked": True, "x": px, "y": py, "button": button, "clicks": clicks}


def mouse_scroll(x: int, y: int, scroll_x: int = 0, scroll_y: int = 0) -> dict:
    px, py = _physical_point(x, y)
    pyautogui.moveTo(px, py)
    if scroll_x:
        pyautogui.hscroll(scroll_x)
    if scroll_y:
        pyautogui.scroll(scroll_y)
    return {"scrolled": True, "x": px, "y": py, "scroll_x": scroll_x, "scroll_y": scroll_y}


def keyboard_type(text: str) -> dict:
    pyautogui.typewrite(text, interval=0.01)
    return {"typed": text}


def key(keys: str) -> dict:
    parts = [p.strip() for p in keys.split("+")]
    if len(parts) > 1:
        pyautogui.keyDown(*parts[:-1])
        pyautogui.keyDown(parts[-1])
        pyautogui.keyUp(parts[-1])
        pyautogui.keyUp(*parts[:-1])
    else:
        pyautogui.keyDown(parts[0])
        pyautogui.keyUp(parts[0])
    return {"key": keys}


def hold_key(key: str, duration: float = 1.0) -> dict:
    pyautogui.keyDown(key)
    time.sleep(duration)
    pyautogui.keyUp(key)
    return {"held": key, "duration": duration}


def wait(duration: float = 1.0) -> dict:
    time.sleep(duration)
    return {"waited": duration}


# ---------------------------------------------------------------------------
# Terminal / shell
# ---------------------------------------------------------------------------

PENDING_ACTIONS = {}
PENDING_LOCK = threading.Lock()


def process_start(command: str, cwd: Optional[str] = None) -> dict:
    """Start a long-running shell command and return a process ID."""
    error = SECURITY.validate_shell_command(command)
    if error:
        return {"error": error, "command": command}
    if CONFIG.confirm_sensitive and SECURITY.requires_confirmation(command):
        pending_id = str(uuid.uuid4())
        with PENDING_LOCK:
            PENDING_ACTIONS[pending_id] = {"type": "process_start", "command": command, "cwd": cwd}
        return {"requires_confirmation": True, "pending_id": pending_id, "command": command}
    return PROCESS_MANAGER.start(command, cwd)


def process_read(process_id: str, timeout: float = 0.5, max_lines: int = 100) -> dict:
    """Read output from a running process."""
    return PROCESS_MANAGER.read(process_id, timeout, max_lines)


def process_kill(process_id: str, signal: str = "SIGTERM") -> dict:
    """Send a signal to a running process."""
    return PROCESS_MANAGER.kill(process_id, signal)


def _exec_shell_command(command: str, timeout: int, cwd: Optional[str]) -> dict:
    try:
        logger.info(f"Running shell command: {command}")
        result = subprocess.run(
            command,
            shell=True,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=cwd,
        )
        return {
            "command": command,
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
        }
    except subprocess.TimeoutExpired:
        return {"error": "command timed out", "command": command}
    except Exception as e:
        return {"error": str(e), "command": command}


def run_shell_command(command: str = "", timeout: int = 60, cwd: Optional[str] = None, pending_id: str = "") -> dict:
    if pending_id:
        with PENDING_LOCK:
            action = PENDING_ACTIONS.pop(pending_id, None)
        if not action:
            return {"error": "pending action not found", "pending_id": pending_id}
        if action["type"] == "shell":
            return _exec_shell_command(action["command"], action["timeout"], action["cwd"])
        return {"error": "unsupported pending action type", "type": action.get("type")}

    error = SECURITY.validate_shell_command(command)
    if error:
        return {"error": error, "command": command}

    if CONFIG.confirm_sensitive and SECURITY.requires_confirmation(command):
        pending_id = str(uuid.uuid4())
        with PENDING_LOCK:
            PENDING_ACTIONS[pending_id] = {"type": "shell", "command": command, "timeout": timeout, "cwd": cwd}
        return {
            "requires_confirmation": True,
            "pending_id": pending_id,
            "command": command,
            "message": "This command matches a sensitive pattern. Use confirm_sensitive_action with pending_id to approve.",
        }

    return _exec_shell_command(command, timeout, cwd)


def confirm_sensitive_action(pending_id: str) -> dict:
    """Execute a previously queued sensitive action."""
    return run_shell_command(pending_id=pending_id)


# ---------------------------------------------------------------------------
# Clipboard
# ---------------------------------------------------------------------------

def clipboard_get() -> dict:
    try:
        process = subprocess.run(["pbpaste"], capture_output=True, text=True)
        return {"text": process.stdout, "returncode": process.returncode}
    except Exception as e:
        return {"error": str(e)}


def clipboard_set(text: str) -> dict:
    try:
        process = subprocess.run(["pbcopy"], input=text, text=True, capture_output=True)
        return {"set": True, "returncode": process.returncode}
    except Exception as e:
        return {"error": str(e)}


# ---------------------------------------------------------------------------
# Application / window management via AppleScript
# ---------------------------------------------------------------------------

def open_app(name: str) -> dict:
    script = f'tell application "{name}" to activate'
    return _run_applescript(script)


def list_windows() -> dict:
    """List windows using Quartz (Screen Recording permission)."""
    try:
        import Quartz
        window_list = Quartz.CGWindowListCopyWindowInfo(
            Quartz.kCGWindowListOptionOnScreenOnly | Quartz.kCGWindowListExcludeDesktopElements,
            Quartz.kCGNullWindowID,
        )
        windows = []
        for win in window_list:
            bounds = win.get(Quartz.kCGWindowBounds, {})
            if bounds.get("X") is None:
                continue
            windows.append(
                {
                    "app": win.get(Quartz.kCGWindowOwnerName, ""),
                    "title": win.get(Quartz.kCGWindowName, ""),
                    "window_id": win.get(Quartz.kCGWindowNumber),
                    "pid": win.get(Quartz.kCGWindowOwnerPID),
                    "x": bounds.get("X"),
                    "y": bounds.get("Y"),
                    "width": bounds.get("Width"),
                    "height": bounds.get("Height"),
                    "layer": win.get(Quartz.kCGWindowLayer),
                    "alpha": win.get(Quartz.kCGWindowAlpha),
                }
            )
        return {
            "windows": windows,
            "count": len(windows),
            "scale_factor": _get_scale_factor(),
            "click_scale": click_scale_for_all_screens(CONFIG.max_screenshot_dim),
        }
    except Exception as e:
        logger.exception("Quartz list_windows failed, falling back to AppleScript")
        return _run_applescript(list_windows_applescript())


def list_windows_applescript() -> str:
    return '''
    tell application "System Events"
        set windowList to {}
        repeat with p in (get processes whose background only is false)
            try
                set appName to name of p
                repeat with w in windows of p
                    set wName to name of w
                    set wPos to position of w
                    set wSize to size of w
                    set end of windowList to {appName, wName, item 1 of wPos, item 2 of wPos, item 1 of wSize, item 2 of wSize}
                end repeat
            end try
        end repeat
    end tell
    return windowList
    '''


def focus_window(app_name: str, window_name: Optional[str] = None) -> dict:
    if window_name:
        script = f'''
        tell application "System Events"
            tell process "{app_name}"
                set frontmost to true
                set w to first window whose name contains "{window_name}"
                set value of attribute "AXMain" of w to true
                set value of attribute "AXFocused" of w to true
            end tell
        end tell
        '''
    else:
        script = f'tell application "{app_name}" to activate'
    return _run_applescript(script)


def _run_applescript(script: str) -> dict:
    try:
        result = subprocess.run(["osascript", "-e", script], capture_output=True, text=True)
        return {
            "script": script,
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
        }
    except Exception as e:
        return {"error": str(e)}


# ---------------------------------------------------------------------------
# Batch / compound
# ---------------------------------------------------------------------------

def batch(operations: list) -> dict:
    """Run a list of simple operations sequentially. Each operation is a dict
    with keys: action, and the corresponding tool arguments."""
    results = []
    for op in operations:
        try:
            action = op.pop("action")
            handler = BATCH_HANDLERS.get(action)
            if handler:
                results.append(handler(**op))
            else:
                results.append({"error": f"unknown action {action}"})
        except Exception as e:
            results.append({"error": str(e)})
        time.sleep(CONFIG.pause_between_actions)
    return {"results": results, "count": len(results)}


# ---------------------------------------------------------------------------
# OCR
# ---------------------------------------------------------------------------

def ocr_screenshot(display: int = 0, scale: bool = True) -> dict:
    """Capture a screenshot and return all text recognized by OCR."""
    img, _ = capture(display)
    if scale:
        img = resize_for_model(img, CONFIG.max_screenshot_dim)
    return {
        "text": ocr_image(img),
        "display": display,
        "width": img.width,
        "height": img.height,
    }


def find_text_on_screen(text: str, display: int = 0, scale: bool = True) -> dict:
    """Capture a screenshot and return bounding boxes for the given text."""
    try:
        img, _ = capture(display)
        if scale:
            img = resize_for_model(img, CONFIG.max_screenshot_dim)
        line_matches = find_text_lines(img, text)
        word_matches = find_text(img, text)
        return {
            "query": text,
            "display": display,
            "width": img.width,
            "height": img.height,
            "line_matches": line_matches,
            "word_matches": word_matches,
            "count": len(word_matches),
        }
    except Exception as e:
        logger.exception("OCR failed")
        return {"error": str(e), "query": text}


# ---------------------------------------------------------------------------
# Status / permissions
# ---------------------------------------------------------------------------

def get_status() -> dict:
    """Return server status and permission state."""
    perms = {}
    try:
        import Quartz
        # Screenshot permission is implicitly tested by a quick capture
        try:
            capture(0)
            perms["screen_recording"] = True
        except Exception as e:
            perms["screen_recording"] = False
            perms["screen_recording_error"] = str(e)
    except Exception:
        perms["screen_recording"] = False
    perms["failsafe_enabled"] = pyautogui.FAILSAFE
    perms["allowed_shell_commands"] = CONFIG.allowed_shell_commands
    perms["blocked_shell_commands"] = CONFIG.blocked_shell_commands
    return {
        "status": "ok",
        "version": "0.2.0",
        "permissions": perms,
        "config": {
            "max_screenshot_dim": CONFIG.max_screenshot_dim,
            "pause_between_actions": CONFIG.pause_between_actions,
            "move_duration": CONFIG.move_duration,
            "confirm_sensitive": CONFIG.confirm_sensitive,
        },
    }


def stop() -> dict:
    """Stop the MCP server process."""
    import os
    import threading
    def _exit():
        time.sleep(0.5)
        os._exit(0)
    threading.Thread(target=_exit, daemon=True).start()
    return {"stopped": True}


# ---------------------------------------------------------------------------
# File system
# ---------------------------------------------------------------------------

def read_file(path: str) -> dict:
    """Read a file under allowed directories."""
    if not SECURITY.is_allowed_path(path):
        return {"error": "path not in allowed directories", "path": path}
    try:
        content = Path(path).read_text(encoding="utf-8", errors="replace")
        return {"path": path, "content": content}
    except Exception as e:
        return {"error": str(e), "path": path}


def write_file(path: str, content: str) -> dict:
    """Write a file under allowed directories."""
    if not SECURITY.is_allowed_path(path):
        return {"error": "path not in allowed directories", "path": path}
    try:
        p = Path(path)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content, encoding="utf-8")
        return {"path": path, "written": True, "bytes": len(content.encode("utf-8"))}
    except Exception as e:
        return {"error": str(e), "path": path}


def list_dir(path: str) -> dict:
    """List files and directories under allowed directories."""
    if not SECURITY.is_allowed_path(path):
        return {"error": "path not in allowed directories", "path": path}
    try:
        entries = []
        for item in Path(path).iterdir():
            entries.append({
                "name": item.name,
                "path": str(item),
                "is_dir": item.is_dir(),
                "size": item.stat().st_size if item.is_file() else None,
            })
        return {"path": path, "entries": entries}
    except Exception as e:
        return {"error": str(e), "path": path}


def _delete_file_impl(path: str) -> dict:
    """Perform the actual deletion without confirmation."""
    p = Path(path)
    if not p.exists():
        return {"error": "path does not exist", "path": path}
    if p.is_dir() and any(p.iterdir()):
        return {"error": "directory is not empty, use rm -r via shell", "path": path}
    try:
        if p.is_dir():
            p.rmdir()
        else:
            p.unlink()
        return {"deleted": True, "path": path}
    except Exception as e:
        return {"error": str(e), "path": path}


def delete_file(path: str) -> dict:
    """Delete a file or directory under allowed directories."""
    if not SECURITY.is_allowed_path(path):
        return {"error": "path not in allowed directories", "path": path}
    if CONFIG.confirm_sensitive:
        p = Path(path)
        if not p.exists():
            return {"error": "path does not exist", "path": path}
        if p.is_dir() and any(p.iterdir()):
            return {"error": "directory is not empty, use rm -r via shell", "path": path}
        pending_id = str(uuid.uuid4())
        with PENDING_LOCK:
            PENDING_ACTIONS[pending_id] = {"type": "delete_file", "path": path}
        return {"requires_confirmation": True, "pending_id": pending_id, "path": path}
    return _delete_file_impl(path)


def confirm_sensitive_action(pending_id: str) -> dict:
    """Execute a previously queued sensitive action."""
    with PENDING_LOCK:
        action = PENDING_ACTIONS.pop(pending_id, None)
    if not action:
        return {"error": "pending action not found", "pending_id": pending_id}
    if action["type"] == "shell":
        return _exec_shell_command(action["command"], action["timeout"], action["cwd"])
    if action["type"] == "delete_file":
        return _delete_file_impl(action["path"])
    if action["type"] == "process_start":
        return PROCESS_MANAGER.start(action["command"], action["cwd"])
    return {"error": "unsupported pending action type", "type": action.get("type")}


# ---------------------------------------------------------------------------
# Click text / OCR action
# ---------------------------------------------------------------------------

def click_text(text: str, display: int = 0, button: str = "left", click_index: int = 0) -> dict:
    """Find the given text on screen and click the center of the n-th match."""
    info = find_text_on_screen(text, display)
    if "error" in info:
        return info
    matches = info.get("word_matches") or info.get("line_matches") or []
    if not matches:
        return {"error": "text not found", "text": text}
    if click_index < 0 or click_index >= len(matches):
        click_index = 0
    match = matches[click_index]
    x, y = match["center_x"], match["center_y"]
    return mouse_click(x, y, button=button, clicks=1)


BATCH_HANDLERS = {
    "mouse_move": mouse_move,
    "mouse_click": mouse_click,
    "mouse_scroll": mouse_scroll,
    "keyboard_type": keyboard_type,
    "key": key,
    "hold_key": hold_key,
    "wait": wait,
    "screenshot": take_screenshot,
    "screenshot_region": screenshot_region,
    "get_cursor_position": get_cursor_position,
    "get_display_info": get_display_info,
    "clipboard_set": clipboard_set,
    "clipboard_get": clipboard_get,
    "run_shell_command": run_shell_command,
    "process_start": process_start,
    "process_read": process_read,
    "process_kill": process_kill,
    "open_app": open_app,
    "list_windows": list_windows,
    "focus_window": focus_window,
    "ocr_screenshot": ocr_screenshot,
    "find_text_on_screen": find_text_on_screen,
    "click_text": click_text,
    "get_status": get_status,
    "stop": stop,
    "read_file": read_file,
    "write_file": write_file,
    "list_dir": list_dir,
    "delete_file": delete_file,
    "confirm_sensitive_action": confirm_sensitive_action,
}

