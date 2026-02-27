#!/usr/bin/env python3
"""
Auto-Claude Monitor - Real-time Anomaly Detection

Checks completed runs for anomalies and sends immediate Slack alerts:
- Context exhaustion (>90% of 200k tokens)
- High budget utilization (>50% of token budget per run)
- Stuck/looping behavior (high tokens, no output)
- Repeated failures in same repo

Called after each auto-claude run to detect problems early.

Usage:
    auto-claude-monitor.py --run-id 20251222_150007 --repo nix-config --log-file path/to/log.jsonl --channel C123456789
    auto-claude-monitor.py --run-id 20251222_150007 --repo nix-config --log-file path/to/log.jsonl --channel C123456789 --dry-run
"""

import argparse
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional

# Import from sibling module
try:
    from auto_claude_db import AutoClaudeDB, parse_jsonl_log
except ImportError:
    sys.path.insert(0, str(Path(__file__).parent))
    from auto_claude_db import AutoClaudeDB, parse_jsonl_log

from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError


# Default thresholds (can be overridden via env vars or config)
DEFAULT_CONTEXT_THRESHOLD = 90  # Alert if >90% context used
DEFAULT_BUDGET_THRESHOLD = 50  # Alert if >50% of budget used (implies loop)
DEFAULT_TOKENS_NO_OUTPUT = 50000  # Flag if >50k tokens with no work units
DEFAULT_CONSECUTIVE_FAILURES = 2  # Alert after N consecutive failures


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
    """Format number with commas."""
    if n is None:
        return "0"
    return f"{n:,}"


class AnomalyChecker:
    """Check for anomalies in auto-claude runs."""

    def __init__(
        self,
        db: AutoClaudeDB,
        context_threshold: int = DEFAULT_CONTEXT_THRESHOLD,
        budget_threshold: int = DEFAULT_BUDGET_THRESHOLD,
        tokens_no_output: int = DEFAULT_TOKENS_NO_OUTPUT,
        consecutive_failures: int = DEFAULT_CONSECUTIVE_FAILURES,
    ):
        self.db = db
        self.context_threshold = context_threshold
        self.budget_threshold = budget_threshold
        self.tokens_no_output = tokens_no_output
        self.consecutive_failures = consecutive_failures

    def check_run(self, run_data: dict) -> list[dict]:
        """Check a run for anomalies. Returns list of anomaly dicts."""
        anomalies = []

        # Check context exhaustion
        context_pct = run_data.get("context_usage_pct", 0)
        if context_pct >= self.context_threshold:
            anomalies.append({
                "type": "context_exhaustion",
                "severity": "high" if context_pct >= 95 else "medium",
                "message": f"Context usage at {context_pct}% of 200k token window",
                "value": context_pct,
            })

        # Check high token usage with no output (stuck/loop indicator)
        total_tokens = run_data.get("input_tokens", 0) + run_data.get("output_tokens", 0)
        work_units = (
            run_data.get("tasks_completed", 0)
            + run_data.get("prs_created", 0)
            + run_data.get("issues_resolved", 0)
        )

        if total_tokens >= self.tokens_no_output and work_units == 0:
            anomalies.append({
                "type": "high_tokens_no_output",
                "severity": "high",
                "message": f"Used {format_number(total_tokens)} tokens with no completed work",
                "value": total_tokens,
                "suggestion": "Check for loops or stuck behavior in logs",
            })

        # Check for failed run
        exit_code = run_data.get("exit_code")
        if exit_code is not None and exit_code != 0:
            # Check for consecutive failures
            recent_runs = self._get_recent_runs_for_repo(run_data.get("repo"))
            consecutive = self._count_consecutive_failures(recent_runs)

            if consecutive >= self.consecutive_failures:
                anomalies.append({
                    "type": "consecutive_failures",
                    "severity": "high",
                    "message": f"{consecutive} consecutive failures in {run_data.get('repo')}",
                    "value": consecutive,
                    "suggestion": "Investigate recurring issue",
                })
            else:
                anomalies.append({
                    "type": "run_failed",
                    "severity": "low",
                    "message": f"Run exited with code {exit_code}",
                    "value": exit_code,
                })

        # Check high budget utilization, if a per-run token budget is provided
        token_budget = run_data.get("token_budget")
        if token_budget and token_budget > 0:
            budget_pct = (total_tokens / token_budget) * 100
            if budget_pct >= self.budget_threshold:
                anomalies.append({
                    "type": "high_budget_utilization",
                    "severity": "high" if budget_pct >= 90 else "medium",
                    "message": (
                        f"Used {format_number(total_tokens)} tokens, "
                        f"{budget_pct:.1f}% of the configured token budget "
                        f"({format_number(token_budget)} tokens)"
                    ),
                    "value": budget_pct,
                })

        # Check for efficiency anomaly (tokens per unit way above average)
        if work_units > 0:
            tokens_per_unit = total_tokens / work_units
            avg_tpu = self.db.get_average_tokens_per_unit(days=7)

            if avg_tpu > 0 and tokens_per_unit > avg_tpu * 3:
                anomalies.append({
                    "type": "inefficient_run",
                    "severity": "medium",
                    "message": f"Tokens per unit ({format_number(int(tokens_per_unit))}) is 3x+ above average ({format_number(int(avg_tpu))})",
                    "value": tokens_per_unit,
                })

        return anomalies

    def _get_recent_runs_for_repo(self, repo: str, hours: int = 24) -> list[dict]:
        """Get recent runs for a repo."""
        if not repo:
            return []
        since = (datetime.now(timezone.utc) - timedelta(hours=hours)).isoformat()
        return self.db.get_runs_since(since, repo=repo)

    def _count_consecutive_failures(self, runs: list[dict]) -> int:
        """Count consecutive failures from most recent."""
        count = 0
        # Sort by started_at descending
        sorted_runs = sorted(runs, key=lambda r: r.get("started_at", ""), reverse=True)
        for run in sorted_runs:
            if run.get("exit_code", 0) != 0:
                count += 1
            else:
                break
        return count


def build_alert_blocks(
    run_id: str,
    repo: str,
    anomalies: list[dict],
    run_data: dict,
) -> tuple[list, str]:
    """Build Slack Block Kit blocks for anomaly alert."""
    # Determine overall severity
    severities = [a.get("severity", "low") for a in anomalies]
    if "high" in severities:
        header_emoji = ":rotating_light:"
        header_text = "Anomaly Detected"
    elif "medium" in severities:
        header_emoji = ":warning:"
        header_text = "Warning"
    else:
        header_emoji = ":information_source:"
        header_text = "Notice"

    text = f"Auto-Claude Alert: {repo} @ {run_id}"

    blocks = [
        {
            "type": "header",
            "text": {"type": "plain_text", "text": f"{header_emoji} {header_text}", "emoji": True},
        },
        {
            "type": "section",
            "fields": [
                {"type": "mrkdwn", "text": f"*Repository*\n{repo}"},
                {"type": "mrkdwn", "text": f"*Run ID*\n`{run_id}`"},
            ],
        },
        {"type": "divider"},
    ]

    # Add anomaly details
    for anomaly in anomalies:
        severity_emoji = {
            "high": ":red_circle:",
            "medium": ":large_orange_circle:",
            "low": ":large_yellow_circle:",
        }.get(anomaly.get("severity", "low"), ":white_circle:")

        anomaly_text = f"{severity_emoji} *{anomaly.get('type', 'unknown').replace('_', ' ').title()}*\n{anomaly.get('message', '')}"

        if anomaly.get("suggestion"):
            anomaly_text += f"\n_Suggestion: {anomaly['suggestion']}_"

        blocks.append({
            "type": "section",
            "text": {"type": "mrkdwn", "text": anomaly_text},
        })

    # Add run stats context
    total_tokens = run_data.get("input_tokens", 0) + run_data.get("output_tokens", 0)
    work_units = (
        run_data.get("tasks_completed", 0)
        + run_data.get("prs_created", 0)
        + run_data.get("issues_resolved", 0)
    )

    blocks.append({
        "type": "context",
        "elements": [
            {
                "type": "mrkdwn",
                "text": f"Tokens: {format_number(total_tokens)} | Work units: {work_units} | Duration: {run_data.get('duration_sec', 0) // 60}min",
            },
        ],
    })

    return blocks, text


def send_alert(
    channel: str,
    run_id: str,
    repo: str,
    anomalies: list[dict],
    run_data: dict,
    dry_run: bool = False,
) -> bool:
    """Send anomaly alert to Slack."""
    blocks, text = build_alert_blocks(run_id, repo, anomalies, run_data)

    if dry_run:
        print("=== DRY RUN - Would send alert to Slack ===")
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
        print(f"Alert sent: {response['ts']}")
        return True

    except SlackApiError as e:
        print(f"Slack API error: {e.response['error']}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"Error sending alert: {e}", file=sys.stderr)
        return False


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(description="Auto-Claude Monitor - Anomaly Detection")
    parser.add_argument("--run-id", required=True, help="Run ID to check")
    parser.add_argument("--repo", required=True, help="Repository name")
    parser.add_argument("--log-file", type=Path, required=True, help="Path to JSONL log file")
    parser.add_argument("--channel", required=True, help="Slack channel ID for alerts")
    parser.add_argument("--dry-run", action="store_true", help="Print alert without sending")
    parser.add_argument("--db-path", type=Path, help="Path to SQLite database")

    # Threshold overrides
    parser.add_argument("--context-threshold", type=int, default=DEFAULT_CONTEXT_THRESHOLD)
    parser.add_argument("--budget-threshold", type=int, default=DEFAULT_BUDGET_THRESHOLD)
    parser.add_argument("--tokens-no-output", type=int, default=DEFAULT_TOKENS_NO_OUTPUT)
    parser.add_argument("--consecutive-failures", type=int, default=DEFAULT_CONSECUTIVE_FAILURES)

    args = parser.parse_args()

    # Initialize database
    db = AutoClaudeDB(args.db_path) if args.db_path else AutoClaudeDB()

    # Parse log file
    run_data = parse_jsonl_log(args.log_file)
    run_data["run_id"] = args.run_id
    run_data["repo"] = args.repo

    # Store run in database for historical tracking
    db.insert_run(run_data)
    for wu in run_data.get("work_units", []):
        wu["run_id"] = args.run_id
        db.insert_work_unit(wu)

    # Check for anomalies
    checker = AnomalyChecker(
        db=db,
        context_threshold=args.context_threshold,
        budget_threshold=args.budget_threshold,
        tokens_no_output=args.tokens_no_output,
        consecutive_failures=args.consecutive_failures,
    )

    anomalies = checker.check_run(run_data)

    if not anomalies:
        print(f"No anomalies detected for run {args.run_id}")
        return 0

    # Filter to only high/medium severity for alerts
    alertable = [a for a in anomalies if a.get("severity") in ("high", "medium")]

    if not alertable:
        print(f"Low-severity anomalies only, not alerting: {anomalies}")
        return 0

    # Send alert
    success = send_alert(
        channel=args.channel,
        run_id=args.run_id,
        repo=args.repo,
        anomalies=alertable,
        run_data=run_data,
        dry_run=args.dry_run,
    )

    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
