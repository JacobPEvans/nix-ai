#!/usr/bin/env python3
"""
Shared utilities for auto-claude Python modules.

This module provides common functions used across preflight, postrun,
and other auto-claude components.
"""

import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def load_bws_env(path: Path | None = None) -> dict[str, str]:
    """Load BWS .env file into dict."""
    if path is None:
        path = Path.home() / ".config/bws/.env"
    config = {}
    if not path.exists():
        return config
    for line in path.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            # Strip inline comments (but preserve # inside quotes)
            if "#" in line:
                # Simple approach: if # appears after =, strip from # onwards
                # This works for unquoted values and simple cases
                key_part, _, value_part = line.partition("=")
                if "#" in value_part:
                    # Check if # is inside quotes
                    in_quotes = False
                    quote_char = None
                    for i, char in enumerate(value_part):
                        if char in ("'", '"') and (i == 0 or value_part[i - 1] != "\\"):
                            if not in_quotes:
                                in_quotes = True
                                quote_char = char
                            elif char == quote_char:
                                in_quotes = False
                        elif char == "#" and not in_quotes:
                            value_part = value_part[:i]
                            break
                line = key_part + "=" + value_part

            if line.startswith("export "):
                line = line[7:]
            key, _, value = line.partition("=")
            value = value.strip().strip("'\"")
            config[key.strip()] = value
    return config


def get_keychain_password(service: str, account: str | None = None) -> str | None:
    """Get password from macOS keychain."""
    try:
        cmd = ["security", "find-generic-password", "-s", service, "-w"]
        if account:
            cmd = ["security", "find-generic-password", "-s", service, "-a", account, "-w"]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        # Keychain entry not found - this is expected for optional config
        return None


def get_repo_name(target_dir: str) -> str:
    """Get repo name - prefer git remote URL (works for worktrees), fall back to basename."""
    target_path = Path(target_dir)

    # Try git remote URL first
    git_dir = target_path / ".git"
    if git_dir.exists():
        try:
            result = subprocess.run(
                ["git", "remote", "get-url", "origin"],
                cwd=target_dir,
                capture_output=True,
                text=True,
                check=True,
            )
            url = result.stdout.strip()
            name = url.rsplit("/", 1)[-1]
            if name.endswith(".git"):
                name = name[:-4]
            if name:
                return name
        except subprocess.CalledProcessError:
            # Git command failed (not a git repo or no remote) - fall back to directory name
            pass

    return target_path.name


def sanitize_repo_name(name: str) -> str:
    """Convert repo name to keychain key format (uppercase, underscores for dashes/dots)."""
    return name.upper().replace("-", "_").replace(".", "_")


def emit_event(
    events_log: Path,
    event_type: str,
    run_id: str,
    repo: str,
    **kwargs: Any,
) -> dict[str, Any]:
    """Emit a structured JSON event to the events log."""
    event = {
        "event": event_type,
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "run_id": run_id,
        "repo": repo,
        **kwargs,
    }
    with open(events_log, "a") as f:
        f.write(json.dumps(event) + "\n")
    return event


def iso_to_epoch(iso_str: str) -> int | None:
    """Convert ISO8601 timestamp to epoch seconds."""
    try:
        # Handle various ISO formats
        iso_str = iso_str.replace("Z", "+00:00")
        if "." in iso_str:
            iso_str = iso_str.split(".")[0] + "+00:00" if "+" not in iso_str else iso_str
        dt = datetime.fromisoformat(iso_str)
        return int(dt.timestamp())
    except (ValueError, AttributeError):
        return None
