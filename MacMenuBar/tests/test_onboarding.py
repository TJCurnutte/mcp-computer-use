#!/usr/bin/env python3
"""Onboarding flow test.

Simulates the post-onboarding flow by:
1. Checking that ~/.mcp-computer-use/onboarding-complete exists.
2. Checking that the Reflex port file is present.
3. Running tests/test_bridge.py and confirming it reports a pass.

Usage:
    python tests/test_onboarding.py
"""

import subprocess
import sys
from pathlib import Path

ONBOARDING_FILE = Path.home() / ".mcp-computer-use" / "onboarding-complete"
PORT_FILE = Path.home() / ".mcp-computer-use" / "mcp.port"
BRIDGE_TEST = Path(__file__).resolve().parent / "test_bridge.py"


def main() -> int:
    if not ONBOARDING_FILE.exists():
        print(
            f"Onboarding marker not found: {ONBOARDING_FILE}\n"
            "Complete first-run onboarding before running this test.",
            file=sys.stderr,
        )
        return 1

    if not PORT_FILE.exists():
        print(
            f"Port file not found: {PORT_FILE}\n"
            "Make sure Reflex is running and has written its TCP port.",
            file=sys.stderr,
        )
        return 1

    print(f"Found onboarding marker: {ONBOARDING_FILE}")
    print(f"Found port file: {PORT_FILE}")

    try:
        result = subprocess.run(
            [sys.executable, str(BRIDGE_TEST)],
            capture_output=True,
            text=True,
            timeout=60,
        )
    except subprocess.TimeoutExpired:
        print("test_bridge.py timed out after 60s.", file=sys.stderr)
        return 1

    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)

    if result.returncode != 0:
        print("test_bridge.py failed.", file=sys.stderr)
        return 1

    if "Bridge test passed." not in result.stdout:
        print("test_bridge.py did not report a successful bridge test.", file=sys.stderr)
        return 1

    print("Onboarding test passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
