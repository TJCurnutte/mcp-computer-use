"""Emergency kill switch for the computer-use server."""

import os
import threading

from .utils import get_logger

logger = get_logger("mcp-computer-use.kill_switch")

_HK = None


def start_kill_switch(hotkey: str = "<ctrl>+<alt>+q"):
    """Start a global hotkey listener that exits the process when triggered.

    On macOS this requires Accessibility permission for the host process.
    """
    global _HK
    try:
        from pynput import keyboard

        def on_activate():
            logger.warning("Kill switch activated. Exiting.")
            os._exit(0)

        h = keyboard.GlobalHotKeys({hotkey: on_activate})
        h.start()
        _HK = h
        logger.info(f"Kill switch armed on {hotkey}")
    except Exception as e:
        logger.warning(f"Could not arm kill switch: {e}")


def stop_kill_switch():
    if _HK:
        _HK.stop()
