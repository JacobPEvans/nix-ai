#!/usr/bin/env python3
"""
Auto-Claude Digest - Scheduled Report Generator

Sends twice-daily utilization reports to Slack showing:
- Runs since last report
- Token usage vs work completed
- Efficiency breakdown per work unit
- Flags for inefficient runs

Usage:
    auto-claude-digest.py --channel C123456789
    auto-claude-digest.py --channel C123456789 --dry-run
    auto-claude-digest.py --channel C123456789 --since "2025-12-22T08:00:00"
"""

import argparse
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional

# Import from sibling module (same directory when deployed)
try:
    from auto_claude_db import AutoClaudeDB
except ImportError:
    # Handle case where script is run directly
    sys.path.insert(0, str(Path(__file__).parent))
    from auto_claude_db import AutoClaudeDB

from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError


def get_slack_token() -> str:
    """Retrieve Slack bot token via bws_helper."""
    try:
        from bws_helper import get_secret
        return get_secret("SLACK_BOT_TOKEN")
    except ImportError:
        print("Error: bws_helper module not found. Ensure it's in the same directory.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error retrieving Slack token: {e}", file=sys.stderr)
        sys.exit(1)


def format_number(n: Optional[int]) -> str:
    """Format number with commas for readability."""
    if n is None:
        return "0"
    return f"{n:,}"


def get_efficiency_emoji(tokens_per_unit: float, avg_tokens: float) -> str:
    """Get emoji indicator for efficiency."""
    if tokens_per_unit is None or avg_tokens is None or avg_tokens == 0:
        return ""

    ratio = tokens_per_unit / avg_tokens
    if ratio <= 0.75:
        return " :white_check_mark:"  # Very efficient
    elif ratio <= 1.25:
        return " :ballot_box_with_check:"  # Average
    elif ratio <= 2.0:
        return " :warning:"  # Above average
    else:
        return " :rotating_light:"  # Inefficient


def build_report_blocks(
    runs: list[dict],
    summary: dict,
    efficiency: list[dict],
    avg_tokens_per_unit: float,
    report_time: str,
    since_time: str,
) -> tuple[list, str]:
    """Build Slack Block Kit blocks for the report."""
    # Parse since time for display
    try:
        since_dt = datetime.fromisoformat(since_time.replace("Z", "+00:00"))
        since_display = since_dt.strftime("%I:%M %p")
    except (ValueError, TypeError):
        since_display = "last report"

    # Header
    now_display = datetime.now(timezone.utc).strftime("%b %d, %I:%M %p")
    text = f"Auto-Claude Report - {now_display}"

    blocks = [
        {
            "type": "header",
            "text": {"type": "plain_text", "text": f":chart_with_upwards_trend: Auto-Claude Report", "emoji": True},
        },
        {
            "type": "context",
            "elements": [{"type": "mrkdwn", "text": f"*{now_display}* | Since {since_display}"}],
        },
        {"type": "divider"},
    ]

    # Summary stats
    total_tokens = (summary.get("total_input_tokens") or 0) + (summary.get("total_output_tokens") or 0)
    cache_savings = summary.get("total_cache_read_tokens") or 0

    blocks.append({
        "type": "section",
        "text": {
            "type": "mrkdwn",
            "text": (
                f"*Summary*\n"
                f":runner: {summary.get('run_count', 0)} runs completed\n"
                f":page_facing_up: {summary.get('total_prs_created', 0)} PRs created\n"
                f":white_check_mark: {summary.get('total_tasks_completed', 0)} tasks completed\n"
                f":coin: {format_number(total_tokens)} tokens used"
            ),
        },
    })

    if cache_savings > 0:
        blocks.append({
            "type": "context",
            "elements": [{"type": "mrkdwn", "text": f":recycle: Cache read: {format_number(cache_savings)} tokens"}],
        })

    # Efficiency breakdown (show up to 8 runs)
    if efficiency:
        blocks.append({"type": "divider"})
        blocks.append({
            "type": "section",
            "text": {"type": "mrkdwn", "text": "*Efficiency Breakdown*"},
        })

        efficiency_lines = []
        flagged_runs = []

        for run in efficiency[:8]:
            repo = run.get("repo", "unknown")
            total = run.get("total_tokens", 0)
            work = run.get("work_units", 0)
            tpu = run.get("tokens_per_unit", total)

            emoji = get_efficiency_emoji(tpu, avg_tokens_per_unit)

            # Format work description
            if work > 0:
                work_desc = f"{work} unit{'s' if work != 1 else ''}"
            else:
                work_desc = "no output"
                if total > 10000:
                    flagged_runs.append(run)

            efficiency_lines.append(
                f"• `{repo}` | {format_number(total)} tokens | {work_desc}{emoji}"
            )

        blocks.append({
            "type": "section",
            "text": {"type": "mrkdwn", "text": "\n".join(efficiency_lines)},
        })

        # Flag inefficient runs
        if flagged_runs:
            blocks.append({"type": "divider"})
            flag_lines = []
            for run in flagged_runs:
                total = run.get("total_tokens", 0)
                repo = run.get("repo", "unknown")
                run_id = run.get("run_id", "unknown")
                context_pct = run.get("context_usage_pct", 0)

                flag_lines.append(
                    f":warning: *{repo}* (`{run_id}`) used {format_number(total)} tokens with no completed work"
                )
                if context_pct > 80:
                    flag_lines.append(f"   Context usage: {context_pct}%")

            blocks.append({
                "type": "section",
                "text": {"type": "mrkdwn", "text": "\n".join(flag_lines)},
            })

    # No runs case
    if not runs:
        blocks.append({
            "type": "section",
            "text": {"type": "mrkdwn", "text": "_No runs since last report_"},
        })

    # Footer
    blocks.append({
        "type": "context",
        "elements": [
            {"type": "mrkdwn", "text": f"Avg tokens/unit (7d): {format_number(int(avg_tokens_per_unit))}"},
        ],
    })

    return blocks, text


def send_report(
    channel: str,
    runs: list[dict],
    summary: dict,
    efficiency: list[dict],
    avg_tokens_per_unit: float,
    since_time: str,
    dry_run: bool = False,
) -> bool:
    """Send the report to Slack."""
    report_time = datetime.now(timezone.utc).isoformat()

    blocks, text = build_report_blocks(
        runs=runs,
        summary=summary,
        efficiency=efficiency,
        avg_tokens_per_unit=avg_tokens_per_unit,
        report_time=report_time,
        since_time=since_time,
    )

    if dry_run:
        print("=== DRY RUN - Would send to Slack ===")
        print(f"Channel: {channel}")
        print(f"Text: {text}")
        print("Blocks:")
        print(json.dumps(blocks, indent=2))
        return True

    try:
        token = get_slack_token()
        client = WebClient(token=token)
        response = client.chat_postMessage(
            channel=channel,
            blocks=blocks,
            text=text,
        )
        print(f"Report sent: {response['ts']}")
        return True

    except SlackApiError as e:
        print(f"Slack API error: {e.response['error']}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"Error sending report: {e}", file=sys.stderr)
        return False


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description="Auto-Claude Digest - Scheduled Reports")
    parser.add_argument("--channel", required=True, help="Slack channel ID")
    parser.add_argument("--since", help="ISO timestamp to report from (default: last report)")
    parser.add_argument("--dry-run", action="store_true", help="Print report without sending")
    parser.add_argument("--db-path", type=Path, help="Path to SQLite database")

    args = parser.parse_args()

    # Initialize database
    db = AutoClaudeDB(args.db_path) if args.db_path else AutoClaudeDB()

    # Determine report window
    if args.since:
        since_time = args.since
    else:
        last_report = db.get_last_report_time("scheduled")
        if last_report:
            since_time = last_report
        else:
            # Default to 12 hours ago if no previous report
            since_time = (datetime.now(timezone.utc) - timedelta(hours=12)).isoformat()

    # Get data
    runs = db.get_runs_since(since_time)
    summary = db.get_summary_since(since_time)
    efficiency = db.get_efficiency_breakdown(since_time)
    avg_tokens = db.get_average_tokens_per_unit(days=7)

    # Send report
    success = send_report(
        channel=args.channel,
        runs=runs,
        summary=summary,
        efficiency=efficiency,
        avg_tokens_per_unit=avg_tokens,
        since_time=since_time,
        dry_run=args.dry_run,
    )

    if success and not args.dry_run:
        # Record that we sent this report
        run_ids = [r.get("run_id") for r in runs if r.get("run_id")]
        db.record_report_sent("scheduled", run_ids)

    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
