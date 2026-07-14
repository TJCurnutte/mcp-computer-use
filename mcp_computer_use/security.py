"""Security guardrails for the computer-use server."""

import re
import shlex
import subprocess
from pathlib import Path
from typing import List

from .config import CONFIG
from .utils import get_logger

logger = get_logger("mcp-computer-use.security")


class SecurityPolicy:
    """Enforces allowlists, blocklists, and confirmation checks."""

    def __init__(self, config):
        self.config = config

    def is_allowed_path(self, path: str) -> bool:
        """Check whether a path is under an allowed directory."""
        try:
            target = Path(path).resolve()
        except Exception:
            return False
        for allowed in self.config.allowed_directories:
            try:
                if target.is_relative_to(Path(allowed).resolve()):
                    return True
            except Exception:
                pass
        return False

    def is_dangerous_shell(self, command: str) -> bool:
        """Check whether a shell command contains blocked patterns.

        Multi-word blocked patterns are matched as literal substrings.
        Single-word patterns are matched as whole tokens to avoid
        false positives like 'dd' matching 'add'.
        """
        cmd = command.strip().lower()
        try:
            tokens = shlex.split(cmd)
        except ValueError:
            tokens = cmd.split()
        for blocked in self.config.blocked_shell_commands:
            blocked = blocked.lower().strip()
            if not blocked:
                continue
            if len(blocked.split()) > 1:
                if blocked in cmd:
                    return True
            else:
                if blocked in tokens:
                    return True
        return False

    def is_allowed_shell(self, command: str) -> bool:
        """Check whether the command base is in the allowlist."""
        try:
            parts = shlex.split(command)
        except ValueError:
            parts = command.split()
        if not parts:
            return False
        base = Path(parts[0]).name
        allowed = [Path(c).name for c in self.config.allowed_shell_commands]
        if base in allowed:
            return True
        # Also allow absolute paths to allowed binaries
        try:
            result = subprocess.run(["which", base], capture_output=True, text=True)
            if result.returncode == 0:
                binary = result.stdout.strip()
                if Path(binary).name in allowed:
                    return True
        except Exception:
            pass
        return False

    def requires_confirmation(self, command: str) -> bool:
        """Check whether a command requires explicit user confirmation."""
        cmd_lower = command.lower()
        for keyword in self.config.require_confirmation_for:
            if keyword.lower() in cmd_lower:
                return True
        return False

    def validate_shell_command(self, command: str) -> str:
        """Validate a shell command and return an error message or empty string."""
        if self.is_dangerous_shell(command):
            return f"Command blocked by security policy: {command}"
        if not self.is_allowed_shell(command):
            return f"Command not in allowlist: {command}"
        return ""


SECURITY = SecurityPolicy(CONFIG)


def explain_command(command: str) -> str:
    """Return a human-readable explanation of what a command will do."""
    parts = shlex.split(command)
    if not parts:
        return "empty command"
    return f"Will execute shell command: {command}"
