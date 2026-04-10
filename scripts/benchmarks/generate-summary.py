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
    "coding": "Coding (HumanEval)",
    "reasoning": "Reasoning (GSM8K / HellaSwag / ARC)",
    "knowledge": "Knowledge (MMLU / IFEval)",
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
    for fmt in ("%Y-%m-%dT%H:%M:%SZ", "%Y-%m-%dT%H%M%SZ"):
        try:
            return datetime.strptime(ts, fmt).strftime("%Y-%m-%d %H:%M")
        except ValueError:
            pass
    return ts[:16]


def _skipped_row(date: str, sha: str, ncols: int) -> str:
    # Row already contains 3 cells: date, sha, the "(skipped ...)" label.
    cells = ["—"] * (ncols - 3)
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
            latency = f"{item.get('value', 0):.2f}"
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
            score = f"{item.get('value', 0):.2f}"
            baseline = item.get("tags", {}).get("claude_baseline", "—")
            gap = item.get("tags", {}).get("gap_pct", "—")
            gap_str = f"{gap}%" if gap != "—" else "—"
            lines.append(f"| {date} | {sha} | {category} | {score} | {baseline} | {gap_str} |")

    return "\n".join(lines) + "\n"


def render_throughput_table(runs: list[dict]) -> str:
    """Throughput suite: show tok/s at different output lengths, grouped by model."""
    if not runs:
        return "_No results yet._\n"

    lines = [
        "| Date | SHA | Model | Test | tok/s | Tokens | Elapsed |",
        "|------|-----|-------|------|-------|--------|---------|",
    ]
    for run in runs:
        date = fmt_timestamp(run.get("timestamp", ""))
        sha = run.get("git_sha", "")[:7]
        model = _short_model(run.get("model", ""))
        if run.get("skipped"):
            lines.append(_skipped_row(date, sha, 7))
            continue
        for item in run.get("results", []):
            name = item.get("name", "")
            value = f"{item.get('value', 0):.1f}"
            tags = item.get("tags", {})
            tokens = tags.get("completion_tokens", tags.get("output_tokens", "—"))
            elapsed = tags.get("elapsed_s", "—")
            lines.append(f"| {date} | {sha} | {model} | {name} | {value} | {tokens} | {elapsed} |")

    return "\n".join(lines) + "\n"


def render_ttft_table(runs: list[dict]) -> str:
    """TTFT suite: show cold/warm latency with cache speedup."""
    if not runs:
        return "_No results yet._\n"

    lines = [
        "| Date | SHA | Model | Test | Latency (s) | Type |",
        "|------|-----|-------|------|-------------|------|",
    ]
    for run in runs:
        date = fmt_timestamp(run.get("timestamp", ""))
        sha = run.get("git_sha", "")[:7]
        model = _short_model(run.get("model", ""))
        if run.get("skipped"):
            lines.append(_skipped_row(date, sha, 6))
            continue
        for item in run.get("results", []):
            name = item.get("name", "")
            value = f"{item.get('value', 0):.3f}"
            tags = item.get("tags", {})
            result_type = tags.get("type", tags.get("temperature", "—"))
            lines.append(f"| {date} | {sha} | {model} | {name} | {value} | {result_type} |")

    return "\n".join(lines) + "\n"


def render_accuracy_table(runs: list[dict]) -> str:
    """Accuracy-based suites (coding, reasoning, knowledge, tool-calling, code-accuracy)."""
    if not runs:
        return "_No results yet._\n"

    lines = [
        "| Date | SHA | Model | Task | Score | Metric | Samples |",
        "|------|-----|-------|------|-------|--------|---------|",
    ]
    for run in runs:
        date = fmt_timestamp(run.get("timestamp", ""))
        sha = run.get("git_sha", "")[:7]
        model = _short_model(run.get("model", ""))
        if run.get("skipped"):
            lines.append(_skipped_row(date, sha, 7))
            continue
        for item in run.get("results", []):
            task = item.get("tags", {}).get("task", item.get("name", ""))
            value = item.get("value", 0)
            score = f"{value:.1%}" if value <= 1.0 else f"{value:.2f}"
            metric = item.get("metric", "")
            samples = _get_sample_count(item)
            lines.append(f"| {date} | {sha} | {model} | {task} | {score} | {metric} | {samples} |")

    return "\n".join(lines) + "\n"


def _get_sample_count(item: dict) -> str:
    """Return the best available sample-count field for summary rendering."""
    tags = item.get("tags", {})
    for key in ("num_samples", "samples", "limit"):
        value = tags.get(key)
        if value not in (None, ""):
            return str(value)
    return "—"


def _short_model(model: str) -> str:
    """Shorten model ID for table display (e.g. mlx-community/Qwen3.5-27B-4bit -> Qwen3.5-27B-4bit)."""
    return model.split("/")[-1] if "/" in model else model


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
    accuracy_suites = {"coding", "reasoning", "knowledge", "tool-calling", "code-accuracy"}
    if suite == "framework-eval":
        body = render_framework_table(runs)
    elif suite == "capability-comparison":
        body = render_capability_table(runs)
    elif suite == "throughput":
        body = render_throughput_table(runs)
    elif suite == "ttft":
        body = render_ttft_table(runs)
    elif suite in accuracy_suites:
        body = render_accuracy_table(runs)
    else:
        body = render_generic_table(runs)
    return heading + body


def _summarize_run(suite: str, run: dict) -> str:
    """Produce a single cell for the model-comparison matrix from one run."""
    if run.get("skipped"):
        return "—"
    results = run.get("results", [])
    errors = run.get("errors", [])
    if not results and not errors:
        return "—"

    if suite == "throughput":
        # Peak sustained tok/s across the sweep is the headline number.
        tok_s = [r.get("value", 0) for r in results if r.get("unit") == "tok/s"]
        return f"{max(tok_s):.1f} tok/s" if tok_s else "—"

    if suite == "ttft":
        # Cold latency is the user-facing metric; warm/cache-speedup are diagnostics.
        for r in results:
            if r.get("name") == "cold-avg" or r.get("tags", {}).get("type") == "cold":
                return f"{r.get('value', 0):.2f}s"
        return "—"

    if suite in {"tool-calling", "code-accuracy", "coding", "reasoning", "knowledge"}:
        # Accuracy suites: average success, but flag partial runs caused by errors.
        # Accept any accuracy-style unit (bool, ratio, percent, or unspecified).
        acc_results = [
            r for r in results if r.get("unit") in ("bool", "ratio", "percent", "")
        ]
        if not acc_results:
            return "—"
        values = [r.get("value", 0) for r in acc_results]
        avg = sum(values) / len(values)
        total_attempts = len(values) + len(errors)
        if errors and total_attempts > len(values):
            # Re-base on attempts so partial runs are never flattered by errors.
            avg = sum(values) / total_attempts
            return f"{avg:.0%} ({sum(values):.0f}/{total_attempts})"
        return f"{avg:.0%}"

    if suite == "capability-comparison":
        values = [r.get("value", 0) for r in results]
        if not values:
            return "—"
        return f"{sum(values) / len(values):.2f}"

    # Framework / generic fallback.
    values = [r.get("value", 0) for r in results]
    if not values:
        return "—"
    return f"{sum(values) / len(values):.2f}"


def render_model_comparison(grouped: dict[str, list[dict]]) -> str:
    """Build a cross-model comparison matrix from the most recent run of each suite per model."""
    matrix: dict[str, dict[str, str]] = {}  # model -> {suite: score_str}
    suites_seen: list[str] = []

    for suite, runs in grouped.items():
        if suite not in suites_seen:
            suites_seen.append(suite)
        for run in runs:
            model = _short_model(run.get("model", "unknown"))
            if model not in matrix:
                matrix[model] = {}
            if suite in matrix[model]:
                continue  # already have the latest for this model+suite
            matrix[model][suite] = _summarize_run(suite, run)

    models = sorted(matrix.keys())
    if len(models) < 2:
        return ""

    header = "| Model | " + " | ".join(SUITE_LABELS.get(s, s) for s in suites_seen) + " |"
    sep = "|-------|" + "|".join("-" * (len(SUITE_LABELS.get(s, s)) + 2) for s in suites_seen) + "|"
    rows = []
    for model in models:
        cells = [matrix[model].get(s, "—") for s in suites_seen]
        rows.append(f"| {model} | " + " | ".join(cells) + " |")

    return "### Model Comparison Matrix\n\n" + "\n".join([header, sep, *rows]) + "\n"


def generate_table(grouped: dict[str, list[dict]]) -> str:
    parts = [
        "<!-- Auto-generated by scripts/benchmarks/generate-summary.py — do not edit manually -->\n\n",
    ]
    suite_order = [
        "throughput", "ttft", "tool-calling", "code-accuracy",
        "coding", "reasoning", "knowledge",
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

    # Multi-model comparison matrix (only when 2+ models have results)
    comparison = render_model_comparison(grouped)
    if comparison:
        parts.append(comparison)
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
