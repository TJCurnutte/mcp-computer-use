import json
import os
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import List


def _safe_int(value, default: int) -> int:
    try:
        return int(value)
    except (ValueError, TypeError):
        return default


def _safe_float(value, default: float) -> float:
    try:
        return float(value)
    except (ValueError, TypeError):
        return default


@dataclass
class Config:
    """Runtime configuration loaded from environment variables and config file."""

    max_screenshot_dim: int = 1280
    screenshot_format: str = "JPEG"
    jpeg_quality: int = 85
    pause_between_actions: float = 0.0
    move_duration: float = 0.0
    fail_safe: bool = True
    log_level: str = "INFO"
    log_dir: Path = field(default_factory=lambda: Path.home() / ".mcp-computer-use" / "logs")

    # Security
    allowed_shell_commands: List[str] = field(default_factory=lambda: [
        "git", "python", "python3", "node", "npm", "npx", "yarn", "pip", "pip3", "uv",
        "ls", "pwd", "cat", "echo", "which", "whoami", "uname", "env", "printenv",
        "bash", "sh", "zsh", "for", "while", "if", "case", "until", "function",
        "find", "grep", "sed", "awk", "head", "tail", "less", "more", "diff", "patch",
        "mkdir", "touch", "cp", "mv", "rm", "rmdir", "open", "osascript", "defaults",
        "df", "du", "ps", "top", "htop", "lsof", "netstat", "ifconfig", "networksetup",
        "pmset", "system_profiler", "mdfind", "launchctl", "plutil", "xcode-select", "xcrun",
        "swift", "brew", "port", "code", "cursor", "windsurf", "claude", "zed", "fleet",
        "tar", "zip", "unzip", "gzip", "gunzip", "rsync", "scp", "sftp", "curl", "wget",
        "ssh", "ssh-keygen", "sqlite3", "sqlite", "say", "screencapture", "caffeinate",
        "qlmanage", "pbcopy", "pbpaste", "mcp",
        "ping", "traceroute", "dig", "nslookup", "host",
        "kill", "pkill", "killall",
    ])
    blocked_shell_commands: List[str] = field(default_factory=lambda: ["rm -rf", "sudo", "su -", "mkfs", "dd", ">/dev/null", "shutdown", "reboot", "poweroff", "halt", "init 0"])
    require_confirmation_for: List[str] = field(default_factory=lambda: ["rm", "kill", "pkill", "killall"])
    allowed_directories: List[str] = field(default_factory=lambda: [str(Path.home())])

    # Confirmation mode
    confirm_sensitive: bool = True

    @classmethod
    def load(cls, config_path: Path = None) -> "Config":
        config = cls()

        # Environment variables
        config.max_screenshot_dim = _safe_int(
            os.getenv("MCP_MAX_SCREENSHOT_DIM", config.max_screenshot_dim), config.max_screenshot_dim
        )
        config.pause_between_actions = _safe_float(
            os.getenv("MCP_PAUSE", config.pause_between_actions), config.pause_between_actions
        )
        config.move_duration = _safe_float(
            os.getenv("MCP_MOVE_DURATION", config.move_duration), config.move_duration
        )
        config.log_level = os.getenv("MCP_LOG_LEVEL", config.log_level)

        env_allow = os.getenv("MCP_ALLOWED_SHELL_COMMANDS")
        if env_allow:
            config.allowed_shell_commands = [s.strip() for s in env_allow.split(",") if s.strip()]

        env_block = os.getenv("MCP_BLOCKED_SHELL_COMMANDS")
        if env_block:
            config.blocked_shell_commands = [s.strip() for s in env_block.split(",") if s.strip()]

        # Config file
        path = config_path or Path.home() / ".mcp-computer-use" / "config.json"
        if path.exists():
            try:
                data = json.loads(path.read_text())
                for k, v in data.items():
                    if hasattr(config, k):
                        setattr(config, k, v)
            except Exception as e:
                print(f"Warning: failed to load config {path}: {e}", file=sys.stderr)

        config.log_dir.mkdir(parents=True, exist_ok=True)
        return config


# Singleton config instance
CONFIG = Config.load()
