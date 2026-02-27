#!/usr/bin/env python3
"""
Keychain Error Handler

Handles keychain-related errors and emits diagnostic events for later analysis.
Integrates with auto-claude error tracking system.

Usage:
    python3 keychain_error_handler.py emit --run-id ID --repo NAME --service SERVICE --exit-code CODE --error ERROR
"""

import argparse
import os
import sys
from pathlib import Path
from typing import Optional

from auto_claude_utils import emit_event


def emit_keychain_error_event(
    events_log: Path,
    run_id: str,
    repo: str,
    service: str,
    account: Optional[str],
    exit_code: int,
    error_message: str,
) -> dict:
    """Emit a keychain error event to the events log."""
    return emit_event(
        events_log,
        "keychain_error",
        run_id,
        repo,
        service=service,
        account=account or "unknown",
        exit_code=exit_code,
        error_message=error_message,
    )


def main():
    parser = argparse.ArgumentParser(description="Handle keychain errors and emit diagnostic events")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # emit subcommand
    p_emit = subparsers.add_parser("emit", help="Emit a keychain error event")
    p_emit.add_argument("--run-id", required=True, help="Run ID")
    p_emit.add_argument("--repo", required=True, help="Repository name")
    p_emit.add_argument("--service", required=True, help="Keychain service name")
    p_emit.add_argument("--account", help="Keychain account (optional)")
    p_emit.add_argument("--exit-code", type=int, required=True, help="Exit code from failed operation")
    p_emit.add_argument("--error", required=True, dest="error_message", help="Error message")

    args = parser.parse_args()

    if args.command == "emit":
        try:
            events_log = Path(os.environ.get("CLAUDE_EVENTS_LOG", str(Path.home() / ".claude/logs/events.jsonl")))
            events_log.parent.mkdir(parents=True, exist_ok=True)

            event = emit_keychain_error_event(
                events_log,
                args.run_id,
                args.repo,
                args.service,
                args.account,
                args.exit_code,
                args.error_message,
            )
            print(f"Keychain error event emitted: {event['timestamp']}")
            return 0
        except (OSError, IOError) as e:
            print(f"Failed to emit keychain error event: {e}", file=sys.stderr)
            return 1


if __name__ == "__main__":
    sys.exit(main())
