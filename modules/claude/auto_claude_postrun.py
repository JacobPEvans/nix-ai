#!/usr/bin/env python3
"""
Auto-Claude Post-Run Processing

Handles post-run operations:
- Token usage calculation from JSONL logs
- Context usage threshold checks
- Control file updates
- Event emission

Usage:
    python3 auto_claude_postrun.py token-usage <log_file>
    python3 auto_claude_postrun.py check-context <log_file> --run-id ID --repo NAME
    python3 auto_claude_postrun.py update-control <repo>
    python3 auto_claude_postrun.py emit-event <type> --run-id ID --repo NAME [--key value ...]
"""

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path

from auto_claude_utils import emit_event

CONTROL_FILE = Path.home() / ".claude/auto-claude-control.json"
EVENTS_LOG = Path.home() / ".claude/logs/events.jsonl"
CONTEXT_WINDOW = 200_000  # Standard tier


def calculate_token_usage(log_file: Path) -> int:
    """Calculate total tokens used from JSONL log file."""
    if not log_file.exists():
        return 0

    total = 0
    with log_file.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                data = json.loads(line)
                if data.get("type") == "message" and data.get("message", {}).get("role") == "assistant":
                    usage = data.get("message", {}).get("usage", {})
                    total += usage.get("input_tokens", 0) + usage.get("output_tokens", 0)
            except json.JSONDecodeError:
                # Skip malformed JSON lines (partial writes, corruption)
                continue
    return total


def check_context_usage(
    log_file: Path,
    run_id: str,
    repo: str,
    threshold_pct: int = 90,
) -> dict:
    """Check context usage and emit events if needed."""
    total_tokens = calculate_token_usage(log_file)
    usage_pct = (total_tokens * 100) // CONTEXT_WINDOW if CONTEXT_WINDOW > 0 else 0
    tokens_remaining = CONTEXT_WINDOW - total_tokens

    result = {
        "tokens_used": total_tokens,
        "tokens_remaining": tokens_remaining,
        "usage_pct": usage_pct,
        "context_window": CONTEXT_WINDOW,
        "exceeded_threshold": usage_pct > threshold_pct,
    }

    # Emit context checkpoint event
    emit_event(
        EVENTS_LOG,
        "context_checkpoint",
        run_id,
        repo,
        tokens_used=total_tokens,
        tokens_remaining=tokens_remaining,
        usage_pct=usage_pct,
        context_window=CONTEXT_WINDOW,
    )

    if result["exceeded_threshold"]:
        emit_event(
            EVENTS_LOG,
            "context_warning",
            run_id,
            repo,
            usage_pct=usage_pct,
            reason="exceeded_threshold",
        )

    return result


def update_control_file(repo: str) -> bool:
    """Update control file with last run info."""
    if not CONTROL_FILE.exists():
        return False

    try:
        control = json.loads(CONTROL_FILE.read_text())
        control["last_run"] = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
        control["last_run_repo"] = repo
        CONTROL_FILE.write_text(json.dumps(control, indent=2))
        return True
    except (json.JSONDecodeError, OSError):
        # Control file corrupt or inaccessible - non-critical, continue
        return False


def emit_run_event(
    event_type: str,
    run_id: str,
    repo: str,
    exit_code: int | None = None,
    duration_sec: int | None = None,
    budget: float | None = None,
    **kwargs,
) -> dict:
    """Emit a run lifecycle event."""
    extra = {}
    if exit_code is not None:
        extra["exit_code"] = exit_code
        extra["status"] = "success" if exit_code == 0 else "failed"
    if duration_sec is not None:
        extra["duration_sec"] = duration_sec
        extra["duration_min"] = duration_sec // 60
    if budget is not None:
        extra["budget"] = budget
    extra.update(kwargs)

    return emit_event(EVENTS_LOG, event_type, run_id, repo, **extra)


def main():
    parser = argparse.ArgumentParser(description="Auto-Claude post-run processing")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # token-usage
    p_tokens = subparsers.add_parser("token-usage", help="Calculate token usage from log")
    p_tokens.add_argument("log_file", type=Path, help="Path to JSONL log file")

    # check-context
    p_context = subparsers.add_parser("check-context", help="Check context usage and emit events")
    p_context.add_argument("log_file", type=Path, help="Path to JSONL log file")
    p_context.add_argument("--run-id", required=True, help="Run ID")
    p_context.add_argument("--repo", required=True, help="Repository name")
    p_context.add_argument("--threshold", type=int, default=90, help="Warning threshold %%")

    # update-control
    p_update = subparsers.add_parser("update-control", help="Update control file with last run")
    p_update.add_argument("repo", help="Repository name")

    # emit-event
    p_emit = subparsers.add_parser("emit-event", help="Emit a structured event")
    p_emit.add_argument("event_type", help="Event type (e.g., run_started, run_completed)")
    p_emit.add_argument("--run-id", required=True, help="Run ID")
    p_emit.add_argument("--repo", required=True, help="Repository name")
    p_emit.add_argument("--exit-code", type=int, help="Exit code")
    p_emit.add_argument("--duration", type=int, help="Duration in seconds")
    p_emit.add_argument("--budget", type=float, help="Budget in USD")
    p_emit.add_argument("--extra", nargs="*", help="Extra key=value pairs")

    args = parser.parse_args()

    if args.command == "token-usage":
        tokens = calculate_token_usage(args.log_file)
        print(tokens)

    elif args.command == "check-context":
        result = check_context_usage(
            args.log_file,
            args.run_id,
            args.repo,
            threshold_pct=args.threshold,
        )
        print(json.dumps(result))
        if result["exceeded_threshold"]:
            sys.exit(1)

    elif args.command == "update-control":
        success = update_control_file(args.repo)
        print("OK" if success else "FAILED")
        sys.exit(0 if success else 1)

    elif args.command == "emit-event":
        extra = {}
        if args.extra:
            for pair in args.extra:
                if "=" in pair:
                    k, v = pair.split("=", 1)
                    # Try to parse as number
                    try:
                        v = int(v)
                    except ValueError:
                        # Not an int, try float
                        try:
                            v = float(v)
                        except ValueError:
                            # Not a number, keep as string
                            pass
                    extra[k] = v

        # If budget was passed via --extra, use it; otherwise use --budget arg
        # This prevents "multiple values for keyword argument" errors
        budget = extra.pop("budget", None) or args.budget
        event = emit_run_event(
            args.event_type,
            args.run_id,
            args.repo,
            exit_code=args.exit_code,
            duration_sec=args.duration,
            budget=budget,
            **extra,
        )
        print(json.dumps(event))


if __name__ == "__main__":
    main()
