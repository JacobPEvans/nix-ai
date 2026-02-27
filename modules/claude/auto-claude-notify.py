#!/usr/bin/env python3
"""
Auto-Claude Slack Notifier

Rich Slack notifications for auto-claude runs using Block Kit formatting.
Supports threading for organized per-run notifications.

Usage:
    auto-claude-notify.py run_started --repo NAME --budget AMOUNT --run-id ID --channel CHANNEL_ID
    auto-claude-notify.py task_started --repo NAME --thread-ts TS --task DESC --agent TYPE
    auto-claude-notify.py task_completed --repo NAME --thread-ts TS --task DESC [--pr PR] [--cost COST] [--duration MIN]
    auto-claude-notify.py task_blocked --repo NAME --thread-ts TS --task DESC --reason REASON
    auto-claude-notify.py run_completed --repo NAME --thread-ts TS --log-file PATH --budget AMOUNT

Secrets:
    All secrets retrieved via bws_helper from ~/.config/bws/.env
    - Slack bot token: BWS_SECRET_SLACK_BOT_TOKEN in config
    - Slack channels: Retrieved from keychain (SLACK_CHANNEL_<REPO>)
"""

import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional

from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError

# Import bws_helper from same directory
sys.path.insert(0, str(Path(__file__).parent))
import bws_helper

# Display limits for Slack messages (prevents overly long messages)
MAX_DISPLAY_ITEMS = 10


def validate_slack_channel_id(channel: str) -> bool:
    """
    Validate Slack channel ID format.

    Valid Slack channel IDs:
    - Public channels: Start with 'C' followed by alphanumeric characters (8+ chars total)
    - Private channels/groups: Start with 'G' followed by alphanumeric characters (8+ chars total)
    - Direct messages: Start with 'D' followed by alphanumeric characters (8+ chars total)
    - User groups: Start with 'S' followed by alphanumeric characters (8+ chars total)

    Args:
        channel: The channel ID to validate

    Returns:
        True if valid, False otherwise
    """
    # Slack channel IDs must start with C, D, G, or S and contain only alphanumeric characters
    # Minimum 8 characters total (1 prefix + 7+ alphanumeric)
    # Supports both uppercase and mixed case IDs
    pattern = r'^[CDGS][A-Za-z0-9]{7,}$'
    return bool(re.match(pattern, channel))


def check_channel_and_handle_error(channel: str) -> Optional[int]:
    """
    Validate Slack channel ID and print error message if invalid.

    Args:
        channel: The channel ID to validate

    Returns:
        1 if invalid (with error message printed), None if valid
    """
    if not validate_slack_channel_id(channel):
        print(f"Error: Invalid Slack channel ID format: {channel}", file=sys.stderr)
        print("Channel ID must start with C, D, G, or S followed by alphanumeric characters", file=sys.stderr)
        return 1
    return None


def escape_slack_markdown(text: str) -> str:
    """Escape special Slack markdown characters to prevent formatting issues."""
    # Escape characters that have special meaning in Slack markdown
    for char in ["*", "_", "`", "~"]:
        text = text.replace(char, f"\\{char}")
    return text


def get_slack_token() -> str:
    """Retrieve Slack bot token from Bitwarden Secrets Manager via bws_helper."""
    try:
        return bws_helper.get_secret("SLACK_BOT_TOKEN")
    except (FileNotFoundError, ValueError, RuntimeError) as e:
        print(f"Error retrieving Slack token: {e}", file=sys.stderr)
        sys.exit(1)


def post_message(token: str, channel: str, blocks: list, text: str, thread_ts: Optional[str] = None) -> Optional[str]:
    """Post a message to Slack and return the message ts."""
    try:
        client = WebClient(token=token)

        kwargs = {
            "channel": channel,
            "blocks": blocks,
            "text": text,  # Fallback for notifications
        }
        if thread_ts:
            kwargs["thread_ts"] = thread_ts

        response = client.chat_postMessage(**kwargs)
        return response["ts"]

    except SlackApiError as e:
        print(f"Slack API error: {e.response['error']}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"Error posting to Slack: {e}", file=sys.stderr)
        return None


def update_message(token: str, channel: str, ts: str, blocks: list, text: str) -> bool:
    """Update an existing Slack message."""
    try:
        client = WebClient(token=token)
        client.chat_update(channel=channel, ts=ts, blocks=blocks, text=text)
        return True

    except SlackApiError as e:
        print(f"Slack API error: {e.response['error']}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"Error updating Slack message: {e}", file=sys.stderr)
        return False


# =============================================================================
# Block Kit Templates
# =============================================================================


def blocks_run_started(repo: str, budget: float, run_id: str) -> tuple[list, str]:
    """Block Kit for run started notification."""
    now = datetime.now().strftime("%b %d, %I:%M %p")
    safe_repo = escape_slack_markdown(repo)
    safe_run_id = escape_slack_markdown(run_id)
    text = f"Auto-Claude run started: {safe_repo}"

    blocks = [
        {
            "type": "header",
            "text": {"type": "plain_text", "text": "🤖 Auto-Claude Run Started", "emoji": True},
        },
        {
            "type": "section",
            "fields": [
                {"type": "mrkdwn", "text": f"*Repository*\n{safe_repo}"},
                {"type": "mrkdwn", "text": f"*Budget*\n${budget:.2f}"},
                {"type": "mrkdwn", "text": f"*Started*\n{now}"},
                {"type": "mrkdwn", "text": f"*Run ID*\n`{safe_run_id}`"},
            ],
        },
        {"type": "divider"},
        {
            "type": "context",
            "elements": [{"type": "mrkdwn", "text": "Task updates will appear in this thread..."}],
        },
    ]

    return blocks, text


def blocks_task_started(task: str, agent: str) -> tuple[list, str]:
    """Block Kit for task started notification."""
    safe_task = escape_slack_markdown(task)
    safe_agent = escape_slack_markdown(agent)
    text = f"Task started: {safe_task}"

    blocks = [
        {
            "type": "section",
            "text": {"type": "mrkdwn", "text": f"🔧 *Dispatched*: {safe_agent}"},
        },
        {
            "type": "section",
            "text": {"type": "mrkdwn", "text": f"```{safe_task}```"},
        },
    ]

    return blocks, text


def blocks_task_completed(task: str, pr: Optional[str], cost: Optional[float], duration: Optional[int]) -> tuple[list, str]:
    """Block Kit for task completed notification."""
    safe_task = escape_slack_markdown(task)
    text = f"Task completed: {safe_task}"

    fields = []
    if pr:
        safe_pr = escape_slack_markdown(pr)
        fields.append({"type": "mrkdwn", "text": f"*PR Created*\n{safe_pr}"})
    if cost is not None:
        fields.append({"type": "mrkdwn", "text": f"*Cost*\n${cost:.2f}"})
    if duration is not None:
        fields.append({"type": "mrkdwn", "text": f"*Duration*\n{duration} min"})

    blocks = [
        {
            "type": "section",
            "text": {"type": "mrkdwn", "text": f"✅ *Completed*: {safe_task}"},
        },
    ]

    if fields:
        blocks.append({"type": "section", "fields": fields})

    return blocks, text


def blocks_task_blocked(task: str, reason: str) -> tuple[list, str]:
    """Block Kit for task blocked notification."""
    safe_task = escape_slack_markdown(task)
    safe_reason = escape_slack_markdown(reason)
    text = f"Task blocked: {safe_task}"

    blocks = [
        {
            "type": "section",
            "text": {"type": "mrkdwn", "text": f"⚠️ *Blocked*: {safe_task}"},
        },
        {
            "type": "section",
            "text": {"type": "mrkdwn", "text": f"_Reason: {safe_reason}_"},
        },
    ]

    return blocks, text


def blocks_run_completed(
    repo: str,
    duration_minutes: int,
    cost: float,
    budget: float,
    completed: list[str],
    blocked: list[dict],
    prs: list[str],
) -> tuple[list, str]:
    """Block Kit for run completed notification."""
    pct = (cost / budget * 100) if budget > 0 else 0
    text = f"Auto-Claude run completed: {repo}"

    blocks = [
        {
            "type": "header",
            "text": {"type": "plain_text", "text": "📊 Auto-Claude Run Complete", "emoji": True},
        },
        {
            "type": "section",
            "fields": [
                {"type": "mrkdwn", "text": f"*Duration*\n{duration_minutes} minutes"},
                {"type": "mrkdwn", "text": f"*Cost*\n${cost:.2f} / ${budget:.2f} ({pct:.0f}%)"},
                {"type": "mrkdwn", "text": f"*Tasks*\n{len(completed)} completed, {len(blocked)} blocked"},
            ],
        },
        {"type": "divider"},
    ]

    # Completed tasks
    if completed:
        completed_text = "\n".join(f"• {t}" for t in completed[:MAX_DISPLAY_ITEMS])
        if len(completed) > MAX_DISPLAY_ITEMS:
            completed_text += f"\n_...and {len(completed) - MAX_DISPLAY_ITEMS} more_"
        blocks.append(
            {
                "type": "section",
                "text": {"type": "mrkdwn", "text": f"*✅ Completed*\n{completed_text}"},
            }
        )

    # PRs created
    if prs:
        prs_text = "\n".join(f"• {pr}" for pr in prs[:MAX_DISPLAY_ITEMS])
        blocks.append(
            {
                "type": "section",
                "text": {"type": "mrkdwn", "text": f"*📝 PRs Created*\n{prs_text}"},
            }
        )

    # Blocked tasks
    if blocked:
        blocked_text = "\n".join(f"• {b.get('task', 'Unknown')}: _{b.get('reason', 'No reason')}_" for b in blocked[:MAX_DISPLAY_ITEMS])
        if len(blocked) > MAX_DISPLAY_ITEMS:
            blocked_text += f"\n_...and {len(blocked) - MAX_DISPLAY_ITEMS} more_"
        blocks.append(
            {
                "type": "section",
                "text": {"type": "mrkdwn", "text": f"*⚠️ Blocked*\n{blocked_text}"},
            }
        )

    return blocks, text


def parse_log_file(log_path: str) -> dict:
    """Parse JSONL log file for task events and summary data."""
    completed = []
    blocked = []
    prs = []
    total_cost = 0.0
    start_time = None
    end_time = None

    try:
        with open(log_path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    data = json.loads(line)

                    # Track timestamps for duration
                    if "timestamp" in data:
                        ts = data["timestamp"]
                        if start_time is None:
                            start_time = ts
                        end_time = ts

                    event = data.get("event")
                    if event == "task_completed":
                        completed.append(data.get("task", "Unknown task"))
                        if data.get("pr"):
                            prs.append(data["pr"])
                        if data.get("cost"):
                            total_cost += float(data["cost"])

                    elif event == "task_blocked":
                        blocked.append(
                            {
                                "task": data.get("task", "Unknown"),
                                "reason": data.get("reason", "No reason given"),
                            }
                        )

                except json.JSONDecodeError:
                    continue

    except FileNotFoundError:
        print(f"Warning: Log file not found: {log_path}", file=sys.stderr)

    # Calculate duration
    duration_minutes = 0
    if start_time and end_time:
        try:
            start = datetime.fromisoformat(start_time.replace("Z", "+00:00"))
            end = datetime.fromisoformat(end_time.replace("Z", "+00:00"))
            duration_minutes = int(abs((end - start).total_seconds()) / 60)
        except (ValueError, TypeError):
            # If timestamps are malformed or missing, leave duration as 0.
            pass

    return {
        "completed": completed,
        "blocked": blocked,
        "prs": prs,
        "total_cost": total_cost,
        "duration_minutes": duration_minutes,
    }


# =============================================================================
# CLI Commands
# =============================================================================


def cmd_run_started(args):
    """Handle run_started event."""
    error = check_channel_and_handle_error(args.channel)
    if error is not None:
        return error

    token = get_slack_token()
    blocks, text = blocks_run_started(args.repo, args.budget, args.run_id)
    ts = post_message(token, args.channel, blocks, text)
    if ts:
        print(ts)  # Output ts for shell script to capture
        return 0
    return 1


def cmd_task_started(args):
    """Handle task_started event."""
    error = check_channel_and_handle_error(args.channel)
    if error is not None:
        return error

    token = get_slack_token()
    blocks, text = blocks_task_started(args.task, args.agent)
    result = post_message(token, args.channel, blocks, text, thread_ts=args.thread_ts)
    return 0 if result else 1


def cmd_task_completed(args):
    """Handle task_completed event."""
    error = check_channel_and_handle_error(args.channel)
    if error is not None:
        return error

    token = get_slack_token()
    blocks, text = blocks_task_completed(args.task, args.pr, args.cost, args.duration)
    result = post_message(token, args.channel, blocks, text, thread_ts=args.thread_ts)
    return 0 if result else 1


def cmd_task_blocked(args):
    """Handle task_blocked event."""
    error = check_channel_and_handle_error(args.channel)
    if error is not None:
        return error

    token = get_slack_token()
    blocks, text = blocks_task_blocked(args.task, args.reason)
    result = post_message(token, args.channel, blocks, text, thread_ts=args.thread_ts)
    return 0 if result else 1


def cmd_run_completed(args):
    """Handle run_completed event."""
    error = check_channel_and_handle_error(args.channel)
    if error is not None:
        return error

    token = get_slack_token()

    # Parse log file for summary data
    log_data = parse_log_file(args.log_file) if args.log_file else {}

    blocks, text = blocks_run_completed(
        repo=args.repo,
        duration_minutes=log_data.get("duration_minutes", 0),
        cost=log_data.get("total_cost", 0.0),
        budget=args.budget,
        completed=log_data.get("completed", []),
        blocked=log_data.get("blocked", []),
        prs=log_data.get("prs", []),
    )

    # Post summary as thread reply
    post_message(token, args.channel, blocks, text, thread_ts=args.thread_ts)

    # Update parent message with completion status
    parent_blocks, parent_text = blocks_run_started(args.repo, args.budget, args.run_id or "unknown")
    # Modify header to show completed
    parent_blocks[0]["text"]["text"] = "✅ Auto-Claude Run Completed"
    update_message(token, args.channel, args.thread_ts, parent_blocks, parent_text)

    return 0


def blocks_run_skipped(repo: str, reason: str) -> tuple[list, str]:
    """Create blocks for run skipped notification."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    blocks = [
        {
            "type": "header",
            "text": {"type": "plain_text", "text": "⏭️ Auto-Claude Run Skipped", "emoji": True},
        },
        {
            "type": "section",
            "fields": [
                {"type": "mrkdwn", "text": f"*Repository:*\n{escape_slack_markdown(repo)}"},
                {"type": "mrkdwn", "text": f"*Time:*\n{timestamp}"},
            ],
        },
        {
            "type": "section",
            "text": {"type": "mrkdwn", "text": f"*Reason:*\n{escape_slack_markdown(reason)}"},
        },
    ]
    return blocks, f"Auto-Claude run skipped for {repo}: {reason}"


def blocks_session_summary(
    findings: list[str],
    recommendations: list[str],
    mode: str,
    stats: Optional[dict] = None,
) -> tuple[list, str]:
    """Block Kit for session summary - goes to Slack thread, NOT GitHub.

    This is for meta-information about auto-claude runs that should NOT
    be created as GitHub issues. Examples:
    - "Orchestrator Session Summary"
    - "Consolidated findings from analysis"
    - Mode transition notifications
    """
    text = "Session Summary"

    blocks = [
        {
            "type": "header",
            "text": {"type": "plain_text", "text": "📋 Session Summary", "emoji": True},
        },
    ]

    # Add mode info if provided
    if mode:
        mode_emoji = {
            "NORMAL": "🟢",
            "CONSOLIDATION": "🟡",
            "PR_CREATION": "🟠",
            "PR_FOCUS": "🔴",
            "PAUSED": "⛔",
        }.get(mode, "⚪")
        blocks.append({
            "type": "section",
            "text": {"type": "mrkdwn", "text": f"*Mode:* {mode_emoji} {escape_slack_markdown(mode)}"},
        })

    # Add stats if provided
    if stats:
        stat_fields = []
        if "total_issues" in stats:
            stat_fields.append({"type": "mrkdwn", "text": f"*Issues:* {stats['total_issues']}"})
        if "ai_created" in stats:
            stat_fields.append({"type": "mrkdwn", "text": f"*AI-Created:* {stats['ai_created']}"})
        if "pr_count" in stats:
            stat_fields.append({"type": "mrkdwn", "text": f"*Open PRs:* {stats['pr_count']}"})
        if "ratio" in stats:
            stat_fields.append({"type": "mrkdwn", "text": f"*Ratio:* {stats['ratio']}:1"})
        if stat_fields:
            blocks.append({"type": "section", "fields": stat_fields})

    # Add findings
    if findings:
        findings_text = "\n".join(f"• {escape_slack_markdown(f)}" for f in findings[:MAX_DISPLAY_ITEMS])
        if len(findings) > MAX_DISPLAY_ITEMS:
            findings_text += f"\n_...and {len(findings) - MAX_DISPLAY_ITEMS} more_"
        blocks.append({
            "type": "section",
            "text": {"type": "mrkdwn", "text": f"*Findings:*\n{findings_text}"},
        })

    # Add recommendations
    if recommendations:
        rec_text = "\n".join(f"• {escape_slack_markdown(r)}" for r in recommendations[:MAX_DISPLAY_ITEMS])
        if len(recommendations) > MAX_DISPLAY_ITEMS:
            rec_text += f"\n_...and {len(recommendations) - MAX_DISPLAY_ITEMS} more_"
        blocks.append({
            "type": "section",
            "text": {"type": "mrkdwn", "text": f"*Recommendations:*\n{rec_text}"},
        })

    blocks.append({"type": "divider"})
    blocks.append({
        "type": "context",
        "elements": [{"type": "mrkdwn", "text": "_This summary is for Slack only - not a GitHub issue._"}],
    })

    return blocks, text


def blocks_user_input_needed(session: str, question: str) -> tuple[list, str]:
    """Block Kit for user input needed notification."""
    safe_session = escape_slack_markdown(session)
    safe_question = escape_slack_markdown(question)
    text = f"Claude needs input: {safe_question}"

    blocks = [
        {
            "type": "header",
            "text": {"type": "plain_text", "text": "🤔 Claude needs your input", "emoji": True},
        },
        {
            "type": "section",
            "fields": [
                {"type": "mrkdwn", "text": f"*Session*\n{safe_session}"},
                {"type": "mrkdwn", "text": f"*Time*\n{datetime.now().strftime('%I:%M %p')}"},
            ],
        },
        {
            "type": "section",
            "text": {"type": "mrkdwn", "text": f"*Question:*\n{safe_question}"},
        },
        {
            "type": "context",
            "elements": [{"type": "mrkdwn", "text": "Return to your terminal to respond"}],
        },
    ]

    return blocks, text


def blocks_cross_issue_update(
    issues: list[str],
    prs: list[str],
    action: str,
    details: Optional[str] = None,
) -> tuple[list, str]:
    """Block Kit for cross-issue/PR updates - goes to Slack thread, NOT GitHub.

    Use this for updates that span multiple issues or PRs. Examples:
    - "Linked issues #1, #2, #3 as related"
    - "Closed 5 issues resolved by merged PRs"
    - "Consolidated 3 duplicate issues into #45"
    """
    text = f"Cross-Issue Update: {action}"

    action_emoji = {
        "linked": "🔗",
        "closed": "✅",
        "consolidated": "📦",
        "deduplicated": "🔄",
        "labeled": "🏷️",
    }.get(action.lower(), "📝")

    blocks = [
        {
            "type": "section",
            "text": {"type": "mrkdwn", "text": f"{action_emoji} *{escape_slack_markdown(action)}*"},
        },
    ]

    # Add issues if provided
    if issues:
        issues_text = ", ".join(f"#{escape_slack_markdown(str(i))}" for i in issues[:MAX_DISPLAY_ITEMS])
        if len(issues) > MAX_DISPLAY_ITEMS:
            issues_text += f" _...and {len(issues) - MAX_DISPLAY_ITEMS} more_"
        blocks.append({
            "type": "section",
            "text": {"type": "mrkdwn", "text": f"*Issues:* {issues_text}"},
        })

    # Add PRs if provided
    if prs:
        prs_text = ", ".join(f"#{escape_slack_markdown(str(p))}" for p in prs[:MAX_DISPLAY_ITEMS])
        if len(prs) > MAX_DISPLAY_ITEMS:
            prs_text += f" _...and {len(prs) - MAX_DISPLAY_ITEMS} more_"
        blocks.append({
            "type": "section",
            "text": {"type": "mrkdwn", "text": f"*PRs:* {prs_text}"},
        })

    # Add details if provided
    if details:
        blocks.append({
            "type": "section",
            "text": {"type": "mrkdwn", "text": f"_{escape_slack_markdown(details)}_"},
        })

    return blocks, text


def cmd_run_skipped(args):
    """Handle run_skipped event."""
    error = check_channel_and_handle_error(args.channel)
    if error is not None:
        return error

    token = get_slack_token()
    blocks, text = blocks_run_skipped(args.repo, args.reason)
    result = post_message(token, args.channel, blocks, text)
    return 0 if result else 1


def cmd_session_summary(args):
    """Handle session_summary event - posts to Slack thread, NOT GitHub."""
    error = check_channel_and_handle_error(args.channel)
    if error is not None:
        return error

    token = get_slack_token()
    findings = [f.strip() for f in args.findings.split("|")] if args.findings else []
    recommendations = [r.strip() for r in args.recommendations.split("|")] if args.recommendations else []
    stats = {}
    if args.total_issues is not None:
        stats["total_issues"] = args.total_issues
    if args.ai_created is not None:
        stats["ai_created"] = args.ai_created
    if args.pr_count is not None:
        stats["pr_count"] = args.pr_count
    if args.ratio is not None:
        stats["ratio"] = args.ratio

    blocks, text = blocks_session_summary(findings, recommendations, args.mode, stats if stats else None)
    result = post_message(token, args.channel, blocks, text, thread_ts=args.thread_ts)
    return 0 if result else 1


def cmd_user_input_needed(args):
    """Handle user_input_needed event - sends push notification."""
    error = check_channel_and_handle_error(args.channel)
    if error is not None:
        return error

    token = get_slack_token()
    blocks, text = blocks_user_input_needed(args.session, args.question)
    result = post_message(token, args.channel, blocks, text)
    return 0 if result else 1


def cmd_cross_issue_update(args):
    """Handle cross_issue_update event - posts to Slack thread, NOT GitHub."""
    error = check_channel_and_handle_error(args.channel)
    if error is not None:
        return error

    token = get_slack_token()
    issues = args.issues.split(",") if args.issues else []
    prs = args.prs.split(",") if args.prs else []
    blocks, text = blocks_cross_issue_update(issues, prs, args.action, args.details)
    result = post_message(token, args.channel, blocks, text, thread_ts=args.thread_ts)
    return 0 if result else 1


def main():
    parser = argparse.ArgumentParser(description="Auto-Claude Slack Notifier")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # run_started
    p_start = subparsers.add_parser("run_started", help="Notify run started")
    p_start.add_argument("--repo", required=True, help="Repository name")
    p_start.add_argument("--budget", type=float, required=True, help="Budget in USD")
    p_start.add_argument("--run-id", required=True, help="Run ID")
    p_start.add_argument("--channel", required=True, help="Slack channel ID")
    p_start.set_defaults(func=cmd_run_started)

    # task_started
    p_task_start = subparsers.add_parser("task_started", help="Notify task started")
    p_task_start.add_argument("--repo", required=True)
    p_task_start.add_argument("--channel", required=True)
    p_task_start.add_argument("--thread-ts", required=True, help="Parent message ts")
    p_task_start.add_argument("--task", required=True, help="Task description")
    p_task_start.add_argument("--agent", required=True, help="Agent type")
    p_task_start.set_defaults(func=cmd_task_started)

    # task_completed
    p_task_done = subparsers.add_parser("task_completed", help="Notify task completed")
    p_task_done.add_argument("--repo", required=True)
    p_task_done.add_argument("--channel", required=True)
    p_task_done.add_argument("--thread-ts", required=True)
    p_task_done.add_argument("--task", required=True)
    p_task_done.add_argument("--pr", help="PR number/link if created")
    p_task_done.add_argument("--cost", type=float, help="Cost in USD")
    p_task_done.add_argument("--duration", type=int, help="Duration in minutes")
    p_task_done.set_defaults(func=cmd_task_completed)

    # task_blocked
    p_blocked = subparsers.add_parser("task_blocked", help="Notify task blocked")
    p_blocked.add_argument("--repo", required=True)
    p_blocked.add_argument("--channel", required=True)
    p_blocked.add_argument("--thread-ts", required=True)
    p_blocked.add_argument("--task", required=True)
    p_blocked.add_argument("--reason", required=True, help="Block reason")
    p_blocked.set_defaults(func=cmd_task_blocked)

    # run_completed
    p_complete = subparsers.add_parser("run_completed", help="Notify run completed")
    p_complete.add_argument("--repo", required=True)
    p_complete.add_argument("--channel", required=True)
    p_complete.add_argument("--thread-ts", required=True)
    p_complete.add_argument("--budget", type=float, required=True)
    p_complete.add_argument("--run-id", help="Run ID for parent update")
    p_complete.add_argument("--log-file", help="Path to JSONL log file")
    p_complete.set_defaults(func=cmd_run_completed)

    # run_skipped
    p_skipped = subparsers.add_parser("run_skipped", help="Notify run skipped")
    p_skipped.add_argument("--repo", required=True, help="Repository name")
    p_skipped.add_argument("--reason", required=True, help="Skip reason")
    p_skipped.add_argument("--channel", required=True, help="Slack channel ID")
    p_skipped.set_defaults(func=cmd_run_skipped)

    # session_summary - goes to Slack thread, NOT GitHub
    p_summary = subparsers.add_parser("session_summary", help="Post session summary to Slack (not GitHub)")
    p_summary.add_argument("--repo", required=True)
    p_summary.add_argument("--channel", required=True)
    p_summary.add_argument("--thread-ts", required=True)
    p_summary.add_argument("--mode", required=True, help="Current mode (NORMAL, CONSOLIDATION, etc.)")
    p_summary.add_argument("--findings", help="Pipe-separated list of findings")
    p_summary.add_argument("--recommendations", help="Pipe-separated list of recommendations")
    p_summary.add_argument("--total-issues", type=int, help="Total open issues")
    p_summary.add_argument("--ai-created", type=int, help="AI-created issues count")
    p_summary.add_argument("--pr-count", type=int, help="Open PR count")
    p_summary.add_argument("--ratio", type=float, help="Issue:PR ratio")
    p_summary.set_defaults(func=cmd_session_summary)

    # user_input_needed - push notification for AskUserQuestion
    p_input = subparsers.add_parser("user_input_needed", help="Notify when Claude needs user input")
    p_input.add_argument("--session", required=True, help="Session context (repo @ branch)")
    p_input.add_argument("--question", required=True, help="Question text from AskUserQuestion")
    p_input.add_argument("--channel", required=True, help="Slack channel ID")
    p_input.set_defaults(func=cmd_user_input_needed)

    # cross_issue_update - goes to Slack thread, NOT GitHub
    p_cross = subparsers.add_parser("cross_issue_update", help="Post cross-issue update to Slack (not GitHub)")
    p_cross.add_argument("--repo", required=True)
    p_cross.add_argument("--channel", required=True)
    p_cross.add_argument("--thread-ts", required=True)
    p_cross.add_argument("--action", required=True, help="Action taken (linked, closed, consolidated, etc.)")
    p_cross.add_argument("--issues", help="Comma-separated issue numbers")
    p_cross.add_argument("--prs", help="Comma-separated PR numbers")
    p_cross.add_argument("--details", help="Additional details")
    p_cross.set_defaults(func=cmd_cross_issue_update)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
