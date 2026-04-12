#!/usr/bin/env python3
"""
Auto-Claude Database Module

SQLite aggregation layer for auto-claude monitoring.
Parses JSONL logs and maintains summary data for efficient reporting.

Usage:
    # As module
    from auto_claude_db import AutoClaudeDB
    db = AutoClaudeDB()
    db.insert_run(run_data)
    runs = db.get_runs_since(timestamp)

    # As CLI
    auto-claude-db.py insert --run-id 20251222_150007 --log-file path/to/log.jsonl
    auto-claude-db.py query --since "2025-12-22T08:00:00"
    auto-claude-db.py backfill --days 30
"""

import argparse
import json
import re
import sqlite3
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional

# Default paths
DEFAULT_DB_PATH = Path.home() / ".claude" / "logs" / "summary.db"
DEFAULT_LOGS_DIR = Path.home() / ".claude" / "logs"


class AutoClaudeDB:
    """SQLite database for auto-claude run aggregation."""

    SCHEMA = """
    CREATE TABLE IF NOT EXISTS runs (
        run_id TEXT PRIMARY KEY,
        repo TEXT NOT NULL,
        started_at TEXT,
        ended_at TEXT,
        duration_sec INTEGER DEFAULT 0,
        exit_code INTEGER,
        input_tokens INTEGER DEFAULT 0,
        output_tokens INTEGER DEFAULT 0,
        cache_read_tokens INTEGER DEFAULT 0,
        cache_write_tokens INTEGER DEFAULT 0,
        context_window INTEGER DEFAULT 200000,
        context_usage_pct INTEGER DEFAULT 0,
        tasks_completed INTEGER DEFAULT 0,
        tasks_blocked INTEGER DEFAULT 0,
        prs_created INTEGER DEFAULT 0,
        issues_resolved INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS work_units (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        run_id TEXT NOT NULL,
        unit_type TEXT NOT NULL,  -- 'pr', 'issue', 'task', 'fix'
        identifier TEXT,          -- PR number, issue number, task desc
        tokens_used INTEGER DEFAULT 0,
        duration_sec INTEGER DEFAULT 0,
        status TEXT DEFAULT 'completed',  -- 'completed', 'blocked', 'in_progress'
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (run_id) REFERENCES runs(run_id)
    );

    CREATE TABLE IF NOT EXISTS report_checkpoints (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_type TEXT NOT NULL,  -- 'scheduled', 'daily', 'weekly'
        sent_at TEXT NOT NULL,
        runs_included TEXT,  -- JSON array of run_ids
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE INDEX IF NOT EXISTS idx_runs_started_at ON runs(started_at);
    CREATE INDEX IF NOT EXISTS idx_runs_repo ON runs(repo);
    CREATE INDEX IF NOT EXISTS idx_work_units_run_id ON work_units(run_id);
    CREATE INDEX IF NOT EXISTS idx_checkpoints_sent_at ON report_checkpoints(sent_at);
    """

    def __init__(self, db_path: Optional[Path] = None):
        """Initialize database connection."""
        self.db_path = db_path or DEFAULT_DB_PATH
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init_db()

    def _init_db(self):
        """Create tables if they don't exist."""
        with sqlite3.connect(self.db_path) as conn:
            conn.executescript(self.SCHEMA)

    def _connect(self) -> sqlite3.Connection:
        """Get a database connection with row factory."""
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def insert_run(self, run_data: dict) -> bool:
        """Insert or update a run record."""
        with self._connect() as conn:
            conn.execute(
                """
                INSERT OR REPLACE INTO runs (
                    run_id, repo, started_at, ended_at, duration_sec, exit_code,
                    input_tokens, output_tokens, cache_read_tokens, cache_write_tokens,
                    context_window, context_usage_pct, tasks_completed, tasks_blocked,
                    prs_created, issues_resolved
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    run_data.get("run_id"),
                    run_data.get("repo"),
                    run_data.get("started_at"),
                    run_data.get("ended_at"),
                    run_data.get("duration_sec", 0),
                    run_data.get("exit_code"),
                    run_data.get("input_tokens", 0),
                    run_data.get("output_tokens", 0),
                    run_data.get("cache_read_tokens", 0),
                    run_data.get("cache_write_tokens", 0),
                    run_data.get("context_window", 200000),
                    run_data.get("context_usage_pct", 0),
                    run_data.get("tasks_completed", 0),
                    run_data.get("tasks_blocked", 0),
                    run_data.get("prs_created", 0),
                    run_data.get("issues_resolved", 0),
                ),
            )
            conn.commit()
            return True

    def insert_work_unit(self, work_unit: dict) -> bool:
        """Insert a work unit record."""
        with self._connect() as conn:
            conn.execute(
                """
                INSERT INTO work_units (run_id, unit_type, identifier, tokens_used, duration_sec, status)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    work_unit.get("run_id"),
                    work_unit.get("unit_type"),
                    work_unit.get("identifier"),
                    work_unit.get("tokens_used", 0),
                    work_unit.get("duration_sec", 0),
                    work_unit.get("status", "completed"),
                ),
            )
            conn.commit()
            return True

    def get_runs_since(self, since: str, repo: Optional[str] = None) -> list[dict]:
        """Get all runs since a given timestamp."""
        with self._connect() as conn:
            if repo:
                cursor = conn.execute(
                    "SELECT * FROM runs WHERE started_at >= ? AND repo = ? ORDER BY started_at",
                    (since, repo),
                )
            else:
                cursor = conn.execute(
                    "SELECT * FROM runs WHERE started_at >= ? ORDER BY started_at",
                    (since,),
                )
            return [dict(row) for row in cursor.fetchall()]

    def get_last_report_time(self, report_type: str = "scheduled") -> Optional[str]:
        """Get the timestamp of the last report sent."""
        with self._connect() as conn:
            cursor = conn.execute(
                "SELECT sent_at FROM report_checkpoints WHERE report_type = ? ORDER BY sent_at DESC LIMIT 1",
                (report_type,),
            )
            row = cursor.fetchone()
            return row["sent_at"] if row else None

    def record_report_sent(self, report_type: str, run_ids: list[str]) -> bool:
        """Record that a report was sent."""
        with self._connect() as conn:
            conn.execute(
                "INSERT INTO report_checkpoints (report_type, sent_at, runs_included) VALUES (?, ?, ?)",
                (report_type, datetime.now(timezone.utc).isoformat(), json.dumps(run_ids)),
            )
            conn.commit()
            return True

    def get_work_units_for_run(self, run_id: str) -> list[dict]:
        """Get all work units for a specific run."""
        with self._connect() as conn:
            cursor = conn.execute(
                "SELECT * FROM work_units WHERE run_id = ?",
                (run_id,),
            )
            return [dict(row) for row in cursor.fetchall()]

    def get_summary_since(self, since: str) -> dict:
        """Get aggregated summary stats since a timestamp."""
        with self._connect() as conn:
            cursor = conn.execute(
                """
                SELECT
                    COUNT(*) as run_count,
                    SUM(input_tokens) as total_input_tokens,
                    SUM(output_tokens) as total_output_tokens,
                    SUM(cache_read_tokens) as total_cache_read_tokens,
                    SUM(tasks_completed) as total_tasks_completed,
                    SUM(tasks_blocked) as total_tasks_blocked,
                    SUM(prs_created) as total_prs_created,
                    SUM(issues_resolved) as total_issues_resolved,
                    AVG(context_usage_pct) as avg_context_usage,
                    MAX(context_usage_pct) as max_context_usage
                FROM runs
                WHERE started_at >= ?
                """,
                (since,),
            )
            row = cursor.fetchone()
            return dict(row) if row else {}

    def get_efficiency_breakdown(self, since: str) -> list[dict]:
        """Get per-run efficiency breakdown (tokens per work unit)."""
        with self._connect() as conn:
            cursor = conn.execute(
                """
                SELECT
                    run_id,
                    repo,
                    started_at,
                    (input_tokens + output_tokens) as total_tokens,
                    (tasks_completed + prs_created + issues_resolved) as work_units,
                    context_usage_pct,
                    exit_code,
                    CASE
                        WHEN (tasks_completed + prs_created + issues_resolved) > 0
                        THEN (input_tokens + output_tokens) / (tasks_completed + prs_created + issues_resolved)
                        ELSE (input_tokens + output_tokens)
                    END as tokens_per_unit
                FROM runs
                WHERE started_at >= ?
                ORDER BY tokens_per_unit DESC
                """,
                (since,),
            )
            return [dict(row) for row in cursor.fetchall()]

    def get_average_tokens_per_unit(self, days: int = 7) -> float:
        """Get average tokens per work unit over the past N days."""
        since = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()
        with self._connect() as conn:
            cursor = conn.execute(
                """
                SELECT AVG(tokens_per_unit) as avg_tpu FROM (
                    SELECT
                        CASE
                            WHEN (tasks_completed + prs_created + issues_resolved) > 0
                            THEN (input_tokens + output_tokens) / (tasks_completed + prs_created + issues_resolved)
                            ELSE NULL
                        END as tokens_per_unit
                    FROM runs
                    WHERE started_at >= ?
                    AND (tasks_completed + prs_created + issues_resolved) > 0
                )
                """,
                (since,),
            )
            row = cursor.fetchone()
            return row["avg_tpu"] or 50000.0  # Default if no data


def parse_jsonl_log(log_path: Path) -> dict:
    """Parse a JSONL log file and extract run data."""
    run_data = {
        "input_tokens": 0,
        "output_tokens": 0,
        "cache_read_tokens": 0,
        "cache_write_tokens": 0,
        "tasks_completed": 0,
        "tasks_blocked": 0,
        "prs_created": 0,
        "issues_resolved": 0,
        "context_usage_pct": 0,
        "started_at": None,
        "ended_at": None,
        "exit_code": None,
        "work_units": [],
    }

    if not log_path.exists():
        return run_data

    with open(log_path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            try:
                data = json.loads(line)
            except json.JSONDecodeError:
                continue

            # Track timestamps
            if "timestamp" in data:
                ts = data["timestamp"]
                if run_data["started_at"] is None:
                    run_data["started_at"] = ts
                run_data["ended_at"] = ts

            # Extract token usage from assistant messages
            if data.get("type") == "message" and data.get("message", {}).get("role") == "assistant":
                usage = data.get("message", {}).get("usage", {})
                run_data["input_tokens"] += usage.get("input_tokens", 0)
                run_data["output_tokens"] += usage.get("output_tokens", 0)
                run_data["cache_read_tokens"] += usage.get("cache_read_input_tokens", 0)
                run_data["cache_write_tokens"] += usage.get("cache_creation_input_tokens", 0)

            # Extract events from events.jsonl format
            event = data.get("event")
            if event == "run_started":
                run_data["run_id"] = data.get("run_id")
                run_data["repo"] = data.get("repo")
                run_data["started_at"] = data.get("timestamp")

            elif event == "run_completed":
                run_data["exit_code"] = data.get("exit_code")
                run_data["ended_at"] = data.get("timestamp")
                run_data["duration_sec"] = data.get("duration_sec", 0)

            elif event == "context_checkpoint":
                run_data["context_usage_pct"] = max(
                    run_data["context_usage_pct"],
                    data.get("usage_pct", 0)
                )

            elif event == "task_completed":
                run_data["tasks_completed"] += 1
                pr = data.get("pr")
                if pr:
                    run_data["prs_created"] += 1
                    run_data["work_units"].append({
                        "unit_type": "pr",
                        "identifier": pr,
                        "status": "completed",
                    })
                else:
                    run_data["work_units"].append({
                        "unit_type": "task",
                        "identifier": data.get("task", "unknown"),
                        "status": "completed",
                    })

            elif event == "task_blocked":
                run_data["tasks_blocked"] += 1
                run_data["work_units"].append({
                    "unit_type": "task",
                    "identifier": data.get("task", "unknown"),
                    "status": "blocked",
                })

    # Calculate duration if not set
    if run_data["started_at"] and run_data["ended_at"] and not run_data.get("duration_sec"):
        def _parse_timestamp(ts: str) -> datetime:
            """Parse ISO 8601 timestamp, handling 'Z' suffix and naive datetimes as UTC."""
            if ts is None:
                raise TypeError("Timestamp is None")
            # Normalize trailing 'Z' (UTC) without affecting other offsets
            if ts.endswith("Z"):
                ts = ts[:-1] + "+00:00"
            dt = datetime.fromisoformat(ts)
            # If no timezone info is present, assume UTC for consistency
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            return dt

        try:
            start = _parse_timestamp(run_data["started_at"])
            end = _parse_timestamp(run_data["ended_at"])
            run_data["duration_sec"] = int((end - start).total_seconds())
        except (ValueError, TypeError):
            # If timestamps are malformed, skip duration calculation and keep other stats
            pass

    return run_data


def extract_run_id_from_filename(filename: str) -> Optional[tuple[str, str]]:
    """Extract repo name and run_id from filename like 'repo_20251222_150007.jsonl'."""
    match = re.match(r"^(.+)_(\d{8}_\d{6})\.jsonl$", filename)
    if match:
        return match.group(1), match.group(2)
    return None


def backfill_from_logs(db: AutoClaudeDB, logs_dir: Path, days: int = 30) -> int:
    """Backfill database from existing JSONL logs."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    count = 0

    for log_file in logs_dir.glob("*_*.jsonl"):
        # Skip events.jsonl
        if log_file.name == "events.jsonl":
            continue

        # Check file modification time
        mtime = datetime.fromtimestamp(log_file.stat().st_mtime, tz=timezone.utc)
        if mtime < cutoff:
            continue

        # Extract repo and run_id from filename
        parsed = extract_run_id_from_filename(log_file.name)
        if not parsed:
            continue

        repo, run_id = parsed

        # Parse log file
        run_data = parse_jsonl_log(log_file)
        run_data["run_id"] = run_id
        run_data["repo"] = repo

        # Insert run
        if db.insert_run(run_data):
            count += 1

            # Insert work units
            for wu in run_data.get("work_units", []):
                wu["run_id"] = run_id
                db.insert_work_unit(wu)

    return count


def main():
    """CLI interface for auto-claude-db."""
    parser = argparse.ArgumentParser(description="Auto-Claude Database Module")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Insert command
    p_insert = subparsers.add_parser("insert", help="Insert run from log file")
    p_insert.add_argument("--run-id", required=True, help="Run ID")
    p_insert.add_argument("--repo", required=True, help="Repository name")
    p_insert.add_argument("--log-file", type=Path, required=True, help="Path to JSONL log")

    # Query command
    p_query = subparsers.add_parser("query", help="Query runs since timestamp")
    p_query.add_argument("--since", required=True, help="ISO timestamp")
    p_query.add_argument("--repo", help="Filter by repository")
    p_query.add_argument("--format", choices=["json", "table"], default="json")

    # Summary command
    p_summary = subparsers.add_parser("summary", help="Get summary stats")
    p_summary.add_argument("--since", required=True, help="ISO timestamp")

    # Efficiency command
    p_efficiency = subparsers.add_parser("efficiency", help="Get efficiency breakdown")
    p_efficiency.add_argument("--since", required=True, help="ISO timestamp")

    # Backfill command
    p_backfill = subparsers.add_parser("backfill", help="Backfill from existing logs")
    p_backfill.add_argument("--days", type=int, default=30, help="Days to backfill")
    p_backfill.add_argument("--logs-dir", type=Path, default=DEFAULT_LOGS_DIR)

    args = parser.parse_args()
    db = AutoClaudeDB()

    if args.command == "insert":
        run_data = parse_jsonl_log(args.log_file)
        run_data["run_id"] = args.run_id
        run_data["repo"] = args.repo
        if db.insert_run(run_data):
            print(f"Inserted run {args.run_id}")
            for wu in run_data.get("work_units", []):
                wu["run_id"] = args.run_id
                db.insert_work_unit(wu)
        else:
            print("Failed to insert run", file=sys.stderr)
            return 1

    elif args.command == "query":
        runs = db.get_runs_since(args.since, args.repo)
        if args.format == "json":
            print(json.dumps(runs, indent=2))
        else:
            for run in runs:
                print(f"{run['run_id']} | {run['repo']} | {run['input_tokens'] + run['output_tokens']} tokens")

    elif args.command == "summary":
        summary = db.get_summary_since(args.since)
        print(json.dumps(summary, indent=2))

    elif args.command == "efficiency":
        breakdown = db.get_efficiency_breakdown(args.since)
        print(json.dumps(breakdown, indent=2))

    elif args.command == "backfill":
        count = backfill_from_logs(db, args.logs_dir, args.days)
        print(f"Backfilled {count} runs")

    return 0


if __name__ == "__main__":
    sys.exit(main())
