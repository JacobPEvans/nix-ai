#!/usr/bin/env python3
# /// script
# dependencies = []
# ///
"""Regenerate the auto-generated summary table in docs/mlx-benchmarks.md.

Reads all JSON result files from data/benchmarks/, groups by suite, formats
markdown tables (last 5 runs per suite), and replaces the content between
BENCHMARK-TABLE-START and BENCHMARK-TABLE-END sentinels in the docs file.

Usage:
  uv run scripts/benchmarks/generate-summary.py
  uv run scripts/benchmarks/generate-summary.py --limit 10
"""

import argparse
import json
from datetime import datetime
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
BENCHMARKS_DIR = REPO_ROOT / "data" / "benchmarks"
DOCS_PATH = REPO_ROOT / "docs" / "mlx-benchmarks.md"

SENTINEL_START = "<!-- BENCHMARK-TABLE-START -->"
SENTINEL_END = "<!-- BENCHMARK-TABLE-END -->"

SUITE_LABELS = {
    "throughput": "Throughput",
    "ttft": "TTFT",
    "tool-calling": "Tool Calling",
    "code-accuracy": "Code Accuracy",
    "framework-eval": "Framework Benchmark",
    "capability-comparison": "Capability Comparison (vs Claude Opus 4.6)",
}


def load_results(limit: int) -> dict[str, list[dict]]:
    """Load and group result files by suite, sorted newest-first, capped at limit."""
    all_files = sorted(
        BENCHMARKS_DIR.glob("*.json"),
        key=lambda p: p.name,
        reverse=True,
    )
    grouped: dict[str, list[dict]] = {}
    for path in all_files:
        if path.name in {"schema.json"}:
            continue
        try:
            data = json.loads(path.read_text())
        except (json.JSONDecodeError, OSError):
            continue
        suite = data.get("suite", "unknown")
        grouped.setdefault(suite, [])
        if len(grouped[suite]) < limit:
            grouped[suite].append(data)
    return grouped


def fmt_timestamp(ts: str) -> str:
    try:
        dt = datetime.strptime(ts, "%Y-%m-%dT%H%M%SZ")
        return dt.strftime("%Y-%m-%d %H:%M")
    except ValueError:
        return ts[:16]


def _skipped_row(date: str, sha: str, ncols: int) -> str:
    cells = ["—"] * (ncols - 2)
    return f"| {date} | {sha} | _(skipped — no MLX hardware)_ | " + " | ".join(cells) + " |"


def render_framework_table(runs: list[dict]) -> str:
    if not runs:
        return "_No results yet._\n"

    lines = [
        "| Date | SHA | Framework | Latency (s) | Tokens | Steps |",
        "|------|-----|-----------|-------------|--------|-------|",
    ]
    for run in runs:
        date = fmt_timestamp(run.get("timestamp", ""))
        sha = run.get("git_sha", "")[:7]
        if run.get("skipped"):
            lines.append(_skipped_row(date, sha, 6))
            continue
        for item in run.get("results", []):
            fw = item.get("tags", {}).get("framework", item.get("name", ""))
            latency = f"{item['value']:.2f}"
            tokens = item.get("tags", {}).get("tokens", "—")
            steps = item.get("tags", {}).get("steps", "—")
            lines.append(f"| {date} | {sha} | {fw} | {latency} | {tokens} | {steps} |")

    return "\n".join(lines) + "\n"


def render_capability_table(runs: list[dict]) -> str:
    if not runs:
        return "_No results yet._\n"

    lines = [
        "| Date | SHA | Category | Score | Claude Baseline | Gap |",
        "|------|-----|----------|-------|-----------------|-----|",
    ]
    for run in runs:
        date = fmt_timestamp(run.get("timestamp", ""))
        sha = run.get("git_sha", "")[:7]
        if run.get("skipped"):
            lines.append(_skipped_row(date, sha, 6))
            continue
        for item in run.get("results", []):
            category = item.get("name", "")
            score = f"{item['value']:.2f}"
            baseline = item.get("tags", {}).get("claude_baseline", "—")
            gap = item.get("tags", {}).get("gap_pct", "—")
            gap_str = f"{gap}%" if gap != "—" else "—"
            lines.append(f"| {date} | {sha} | {category} | {score} | {baseline} | {gap_str} |")

    return "\n".join(lines) + "\n"


def render_generic_table(runs: list[dict]) -> str:
    if not runs:
        return "_No results yet._\n"

    lines = [
        "| Date | SHA | Test | Metric | Value | Unit |",
        "|------|-----|------|--------|-------|------|",
    ]
    for run in runs:
        date = fmt_timestamp(run.get("timestamp", ""))
        sha = run.get("git_sha", "")[:7]
        if run.get("skipped"):
            lines.append(_skipped_row(date, sha, 6))
            continue
        for item in run.get("results", []):
            name = item.get("name", "")
            metric = item.get("metric", "")
            value = item.get("value", 0)
            unit = item.get("unit", "")
            lines.append(f"| {date} | {sha} | {name} | {metric} | {value} | {unit} |")

    return "\n".join(lines) + "\n"


def render_suite(suite: str, runs: list[dict]) -> str:
    label = SUITE_LABELS.get(suite, suite)
    heading = f"### {label}\n\n"
    if suite == "framework-eval":
        body = render_framework_table(runs)
    elif suite == "capability-comparison":
        body = render_capability_table(runs)
    else:
        body = render_generic_table(runs)
    return heading + body


def generate_table(grouped: dict[str, list[dict]]) -> str:
    parts = [
        "<!-- Auto-generated by scripts/benchmarks/generate-summary.py — do not edit manually -->\n\n",
    ]
    suite_order = [
        "throughput", "ttft", "tool-calling", "code-accuracy",
        "framework-eval", "capability-comparison",
    ]
    rendered_suites: set[str] = set()

    for suite in suite_order:
        if suite in grouped:
            parts.append(render_suite(suite, grouped[suite]))
            parts.append("\n")
            rendered_suites.add(suite)

    for suite, runs in grouped.items():
        if suite not in rendered_suites:
            parts.append(render_suite(suite, runs))
            parts.append("\n")

    return "".join(parts).rstrip("\n")


def update_docs(table: str) -> None:
    content = DOCS_PATH.read_text()

    start_idx = content.find(SENTINEL_START)
    if start_idx == -1:
        raise ValueError(f"Sentinel '{SENTINEL_START}' not found in {DOCS_PATH}")
    end_idx = content.find(SENTINEL_END, start_idx)
    if end_idx == -1:
        raise ValueError(f"Sentinel '{SENTINEL_END}' not found in {DOCS_PATH}")

    before = content[: start_idx + len(SENTINEL_START)]
    after = content[end_idx:]
    DOCS_PATH.write_text(before + "\n\n" + table + "\n\n" + after)
    print(f"Updated {DOCS_PATH}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Regenerate benchmark summary in docs")
    parser.add_argument("--limit", type=int, default=5, help="Max runs per suite (default: 5)")
    args = parser.parse_args()

    grouped = load_results(args.limit)
    if not grouped:
        print("No result files found in data/benchmarks/ — nothing to do")
        return

    table = generate_table(grouped)
    update_docs(table)


if __name__ == "__main__":
    main()
