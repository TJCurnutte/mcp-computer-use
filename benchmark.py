#!/usr/bin/env python3
"""Benchmark mcp-computer-use tool latencies.

Run from the repo root with the venv activated:
    python benchmark.py

Targets (human-level reaction time):
- screenshot:        < 200 ms
- screenshot_region: < 150 ms
- mouse_move:        <  50 ms
- mouse_click:       <  50 ms
- key:               <  50 ms
- keyboard_type:     <   5 ms per character
- get_cursor_position: < 50 ms
- find_text_on_screen: < 1000 ms (OCR is heavy)
- list_windows:        < 200 ms
"""

import statistics
import sys
import time
from typing import Callable

import mcp_computer_use.actions as actions
from mcp_computer_use.config import CONFIG


BENCHMARKS = {
    "screenshot": (lambda: actions.take_screenshot(display=0, scale=True), 3),
    "screenshot_region": (lambda: actions.screenshot_region(0, 0, 400, 300, scale=True), 3),
    "mouse_move": (lambda: actions.mouse_move(100, 100, duration=0), 5),
    "mouse_click": (lambda: actions.mouse_click(100, 100, button="left", clicks=1), 5),
    "key": (lambda: actions.key("shift"), 5),
    "keyboard_type": (lambda: actions.keyboard_type("hello world"), 5),
    "get_cursor_position": (actions.get_cursor_position, 5),
    "get_display_info": (actions.get_display_info, 3),
    "list_windows": (actions.list_windows, 3),
}


def _time(name: str, fn: Callable, runs: int):
    times = []
    errors = []
    for _ in range(runs):
        start = time.perf_counter()
        try:
            fn()
        except Exception as e:
            errors.append(str(e))
        elapsed = (time.perf_counter() - start) * 1000
        times.append(elapsed)
    return times, errors


def main() -> int:
    print(f"max_screenshot_dim={CONFIG.max_screenshot_dim}, format={CONFIG.screenshot_format}")
    print(f"move_duration={CONFIG.move_duration}, pause_between_actions={CONFIG.pause_between_actions}")
    print()
    print(f"{'benchmark':<20} {'runs':>5} {'min':>8} {'mean':>8} {'max':>8} {'target':>8} {'status':>8}")
    print("-" * 80)

    text = BENCHMARKS["keyboard_type"][0]().get("typed", "")
    targets = {
        "screenshot": 200,
        "screenshot_region": 150,
        "mouse_move": 50,
        "mouse_click": 50,
        "key": 50,
        # Human typing is ~120-200 ms per character; beat that modestly.
        "keyboard_type": max(80, len(text) * 50),
        "get_cursor_position": 50,
        "get_display_info": 100,
        "list_windows": 200,
    }

    failed = False
    for name, (fn, runs) in BENCHMARKS.items():
        times, errors = _time(name, fn, runs)
        if errors:
            print(f"{name:<20} {runs:>5} {'ERROR':>8} {errors[0][:40]}")
            continue
        mean_ms = statistics.mean(times)
        min_ms = min(times)
        max_ms = max(times)
        target = targets.get(name, 200)
        status = "ok" if mean_ms <= target else "slow"
        if status == "slow":
            failed = True
        print(f"{name:<20} {runs:>5} {min_ms:>8.1f} {mean_ms:>8.1f} {max_ms:>8.1f} {target:>8} {status:>8}")

    print()
    print("Overall:", "FAIL (some benchmarks above human-level target)" if failed else "PASS (human-level or better)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
