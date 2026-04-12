#!/usr/bin/env python3
"""SwiftBar Auto-Claude Status Plugin."""

import json
import shlex
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Optional

HOME = Path.home()
CONTROL_FILE = HOME / ".claude" / "auto-claude-control.json"
LOG_DIR = HOME / ".claude" / "logs"
CTL_SCRIPT = HOME / ".claude" / "scripts" / "auto-claude-ctl.sh"


def get_active_sessions() -> int:
    """Count running auto-claude sessions.

    Auto-claude runs: claude -p <prompt> --output-format stream-json ...
    We look for the specific --output-format flag used by auto-claude.
    """
    try:
        result = subprocess.run(
            ["pgrep", "-f", "claude.*--output-format stream-json"],
            capture_output=True,
            text=True,
        )
        return len(result.stdout.strip().split("\n")) if result.stdout.strip() else 0
    except Exception:
        return 0


def parse_iso_time(iso_str: str) -> Optional[datetime]:
    """Parse ISO timestamp."""
    try:
        return datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
    except Exception:
        return None


def get_status() -> tuple[str, str, str]:
    """Return (icon, status_text, color)."""
    if not CONTROL_FILE.exists():
        return "🤖", "No control file", "gray"

    try:
        with open(CONTROL_FILE) as f:
            data = json.load(f)
    except Exception:
        return "⚠️", "Error reading control file", "red"

    active = get_active_sessions()
    if active > 0:
        return "🔄", f"Running ({active} sessions)", "blue"

    pause_until = data.get("pause_until")
    if pause_until:
        pause_time = parse_iso_time(pause_until)
        if pause_time:
            # Ensure `now` and `pause_time` are comparable (both naive or both aware)
            try:
                if pause_time.tzinfo is not None:
                    now = datetime.now(pause_time.tzinfo)
                else:
                    now = datetime.now()
                if now < pause_time:
                    return "⏸️", f"Paused until {pause_time.strftime('%H:%M')}", "orange"
            except Exception:
                # If anything goes wrong comparing times (e.g. unexpected tzinfo),
                # ignore the pause and fall through to the normal status logic.
                pass

    skip_count = data.get("skip_count", 0)
    if skip_count > 0:
        return "⏭️", f"Skipping {skip_count} runs", "yellow"

    return "🤖", "Active", "green"


def get_recent_logs(limit: int = 5) -> list[tuple[str, str, str]]:
    """Return [(name, size, path), ...] for recent logs."""
    if not LOG_DIR.exists():
        return []

    logs = sorted(LOG_DIR.glob("*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True)
    result = []
    for log in logs[:limit]:
        size = log.stat().st_size
        if size > 1024 * 1024:
            size_str = f"{size / (1024 * 1024):.1f}MB"
        elif size > 1024:
            size_str = f"{size / 1024:.1f}KB"
        else:
            size_str = f"{size}B"
        result.append((log.stem, size_str, str(log)))
    return result


def get_last_run_info() -> Optional[dict]:
    """Extract last run info from most recent log file."""
    if not LOG_DIR.exists():
        return None

    # Find most recent .jsonl log file (exclude events.jsonl and any summary files)
    logs = sorted(
        [
            l for l in LOG_DIR.glob("*.jsonl")
            if l.name not in ["events.jsonl", "summary.log"]
            and not l.name.startswith("summary")
        ],
        key=lambda p: p.stat().st_mtime,
        reverse=True
    )

    if not logs:
        return None

    log_file = logs[0]
    try:
        # Extract repo name and run_id from filename
        # Format: "{repo}_{YYYYMMDD}_{HHMMSS}.jsonl"
        # Use rsplit to handle repo names with underscores (e.g., "my_repo_20251228_150002")
        parts = log_file.stem.rsplit("_", 2)  # Split from right, max 2 splits
        if len(parts) >= 3:
            repo_name = parts[0]
            run_id = f"{parts[1]}_{parts[2]}"  # Reconstruct run_id from date_time
        else:
            # Fallback for unexpected format
            repo_name = log_file.stem
            run_id = None

        # Get file modification time
        mtime = datetime.fromtimestamp(log_file.stat().st_mtime)
        time_str = mtime.strftime("%H:%M")

        # Find exit_code from events.jsonl (where run_completed events are written)
        exit_status = None
        events_file = LOG_DIR / "events.jsonl"
        if run_id and events_file.exists():
            with open(events_file, "rb") as f:
                # Read last ~10KB to find recent run_completed events
                try:
                    f.seek(-10240, 2)  # Seek 10KB from end
                except OSError:
                    # File smaller than 10KB, read from start
                    f.seek(0)
                lines = f.read().decode("utf-8", errors="ignore").splitlines()

            # Search for run_completed event matching this run_id
            for line in reversed(lines):
                line = line.strip()
                if not line:
                    continue
                try:
                    event = json.loads(line)
                    if event.get("event") == "run_completed" and event.get("run_id") == run_id:
                        exit_status = event.get("exit_code")
                        break
                except json.JSONDecodeError:
                    continue

        return {
            "repo": repo_name,
            "time": time_str,
            "exit_status": exit_status
        }
    except (IOError, IndexError):
        return None


def main():
    icon, status, color = get_status()
    ctl = shlex.quote(str(CTL_SCRIPT))
    log_dir = shlex.quote(str(LOG_DIR))

    # Menu bar: show icon only (no status text)
    print(f"{icon} | color={color}")
    print("---")

    # Auto-Claude Status section
    print(f"Auto-Claude Status: {status} | color={color} disabled=true")
    print("---")

    # Last run info section
    last_run = get_last_run_info()
    if last_run:
        # Handle None exit_status (unknown) vs 0 (success) vs non-zero (failure)
        exit_status = last_run["exit_status"]
        if exit_status is None:
            status_icon = "?"
            status_text = "unknown"
        elif exit_status == 0:
            status_icon = "✓"
            status_text = f"exit {exit_status}"
        else:
            status_icon = "✗"
            status_text = f"exit {exit_status}"

        print(f"Last run: {last_run['time']} | disabled=true")
        print(f"  Repo: {last_run['repo']} | disabled=true")
        print(f"  Status: {status_icon} ({status_text}) | disabled=true")
    else:
        print("Last run: No runs yet | disabled=true")
    print("---")

    # Control actions
    print(f"Run Now | bash={ctl} param1='run' terminal=false refresh=true")
    print(f"Resume | bash={ctl} param1='resume' terminal=false refresh=true")
    print(f"Skip next run | bash={ctl} param1='skip' param2='1' terminal=false refresh=true")

    # Pause submenu with all options
    print("--Pause for:")
    for hours in [1, 2, 4, 6, 8, 12]:
        label = f"{hours} hour" if hours == 1 else f"{hours} hours"
        print(f"----{label} | bash={ctl} param1='pause' param2='{hours}' terminal=false refresh=true")

    # Calculate hours until midnight for "pause until midnight" option
    now = datetime.now()
    midnight = now.replace(hour=23, minute=59, second=59, microsecond=0)
    hours_until_midnight = max(1, int((midnight - now).total_seconds() / 3600) + 1)
    print(f"----Until midnight | bash={ctl} param1='pause' param2='{hours_until_midnight}' terminal=false refresh=true")

    # Add 1 day and 2 days options
    print(f"----1 day | bash={ctl} param1='pause' param2='24' terminal=false refresh=true")
    print(f"----2 days | bash={ctl} param1='pause' param2='48' terminal=false refresh=true")

    print("---")

    # Recent logs section
    print("Recent Logs | size=12")
    logs = get_recent_logs()
    if logs:
        for name, size, path in logs:
            # Properly escape path for shell safety - use 'open' to open with default app
            escaped_path = shlex.quote(path)
            print(f"  {name} ({size}) | bash='open {escaped_path}' terminal=false")
    else:
        print("  No logs found | color=gray")

    print("---")

    # Bottom actions
    print(f"Open Logs Folder | bash='open {log_dir}' terminal=false")
    print(f"View Status | bash={ctl} param1='status' terminal=true")
    print("---")
    print("Refresh | refresh=true")


if __name__ == "__main__":
    main()
