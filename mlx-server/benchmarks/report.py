"""Generate MLX vs Claude Opus 4.6 comparison report."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from common import RESULTS_DIR, CLAUDE_BASELINES, get_verdict, get_model


def load_results() -> dict[str, dict]:
    """Load all result JSON files from RESULTS_DIR. Returns {category: data}."""
    loaded = {}
    for path in sorted(RESULTS_DIR.glob("*.json")):
        if path.name == "report.md":
            continue
        try:
            data = json.loads(path.read_text())
            category = data.get("category", path.stem)
            loaded[category] = data
        except (json.JSONDecodeError, OSError):
            print(f"  WARNING: Could not load {path}", file=sys.stderr)
    return loaded


def compute_gap(mlx_score: float, claude_score: float) -> float:
    """Return absolute gap (Claude - MLX). Positive means MLX is behind."""
    return claude_score - mlx_score


def format_gap(gap: float) -> str:
    if gap > 0:
        return f"-{gap * 100:.1f}%"
    elif gap < 0:
        return f"+{abs(gap) * 100:.1f}%"
    return "0.0%"


def main() -> None:
    results = load_results()
    if not results:
        print("No result files found in", RESULTS_DIR)
        sys.exit(1)

    model = get_model()
    timestamp = None
    total_runtime = 0.0

    # Gather per-category data
    categories = []
    all_tests_shortcoming = []
    all_tests_minor_gap = []
    all_tests_strength = []
    composite_scores_mlx = []
    composite_scores_claude = []

    for category, data in results.items():
        summary = data.get("summary", {})
        mlx_mean = summary.get("mean_score", 0.0)
        total_runtime += summary.get("total_latency", 0.0)
        if timestamp is None:
            timestamp = data.get("timestamp", "unknown")

        claude_baseline = CLAUDE_BASELINES.get(category, {})
        claude_mean = claude_baseline.get("mean_score", 0.0)
        gap = compute_gap(mlx_mean, claude_mean)
        verdict = get_verdict(mlx_mean, claude_mean)

        categories.append({
            "category": category,
            "mlx_mean": mlx_mean,
            "claude_mean": claude_mean,
            "gap": gap,
            "verdict": verdict,
        })
        composite_scores_mlx.append(mlx_mean)
        composite_scores_claude.append(claude_mean)

        # Per-test analysis
        claude_per_test = claude_baseline.get("per_test", {})
        for test in data.get("tests", []):
            test_name = test.get("name", "unknown")
            test_score = test.get("score", 0.0)
            claude_test_score = claude_per_test.get(test_name, claude_mean)
            test_gap = compute_gap(test_score, claude_test_score)
            test_verdict = get_verdict(test_score, claude_test_score)
            preview = test.get("response_preview", "")[:120]

            entry = {
                "category": category,
                "name": test_name,
                "mlx_score": test_score,
                "claude_score": claude_test_score,
                "gap": test_gap,
                "preview": preview,
            }

            if test_score < 0.5 or test_gap / max(claude_test_score, 0.001) > 0.25:
                all_tests_shortcoming.append(entry)
            elif test_gap / max(claude_test_score, 0.001) >= 0.10:
                all_tests_minor_gap.append(entry)
            else:
                all_tests_strength.append(entry)

    composite_mlx = sum(composite_scores_mlx) / max(len(composite_scores_mlx), 1)
    composite_claude = sum(composite_scores_claude) / max(len(composite_scores_claude), 1)
    overall_verdict = get_verdict(composite_mlx, composite_claude)

    # Build markdown
    lines = []
    lines.append("# MLX vs Claude Opus 4.6 — Benchmark Report")
    lines.append("")
    lines.append(f"**Model:** `{model}`  ")
    lines.append(f"**Timestamp:** {timestamp or 'unknown'}  ")
    lines.append(f"**Total runtime:** {total_runtime / 60:.1f}m  ")
    lines.append("")

    # Summary table
    lines.append("## Summary")
    lines.append("")
    lines.append("| Category | MLX Score | Claude Baseline | Gap | Verdict |")
    lines.append("|----------|-----------|-----------------|-----|---------|")
    for cat in categories:
        gap_str = format_gap(cat["gap"])
        lines.append(
            f"| {cat['category']} "
            f"| {cat['mlx_mean']:.2f} "
            f"| {cat['claude_mean']:.2f} "
            f"| {gap_str} "
            f"| {cat['verdict']} |"
        )
    overall_gap = compute_gap(composite_mlx, composite_claude)
    lines.append(f"| **OVERALL** | **{composite_mlx:.2f}** | **{composite_claude:.2f}** | **{format_gap(overall_gap)}** | **{overall_verdict}** |")
    lines.append("")

    # Shortcomings
    lines.append("## Explicit Shortcomings")
    lines.append("")
    if all_tests_shortcoming:
        lines.append("Tests where MLX scored below 0.5 or the gap exceeds 25% of the Claude baseline:")
        lines.append("")
        for t in all_tests_shortcoming:
            gap_pct = t["gap"] / max(t["claude_score"], 0.001) * 100
            lines.append(f"### {t['category']} / {t['name']}")
            lines.append(f"- **MLX score:** {t['mlx_score']:.2f}")
            lines.append(f"- **Claude baseline:** {t['claude_score']:.2f}")
            lines.append(f"- **Gap:** {gap_pct:.1f}% below Claude")
            if t["preview"]:
                lines.append(f"- **Response preview:** `{t['preview']}`")
            lines.append("")
    else:
        lines.append("_No shortcomings detected. MLX is within 25% of Claude on all tests._")
        lines.append("")

    # Minor gaps
    lines.append("## Minor Gaps")
    lines.append("")
    if all_tests_minor_gap:
        lines.append("Tests where the gap is 10–25% below Claude baseline:")
        lines.append("")
        for t in all_tests_minor_gap:
            gap_pct = t["gap"] / max(t["claude_score"], 0.001) * 100
            lines.append(f"- **{t['category']} / {t['name']}**: MLX {t['mlx_score']:.2f} vs Claude {t['claude_score']:.2f} ({gap_pct:.1f}% gap)")
        lines.append("")
    else:
        lines.append("_No minor gaps detected._")
        lines.append("")

    # Strengths
    lines.append("## Strengths (At Parity)")
    lines.append("")
    if all_tests_strength:
        lines.append("Tests where MLX is within 10% of Claude baseline:")
        lines.append("")
        for t in all_tests_strength:
            lines.append(f"- **{t['category']} / {t['name']}**: MLX {t['mlx_score']:.2f} vs Claude {t['claude_score']:.2f}")
        lines.append("")
    else:
        lines.append("_No tests at parity._")
        lines.append("")

    # Overall composite
    lines.append("## Overall Composite Score")
    lines.append("")
    lines.append("| Metric | Value |")
    lines.append("|--------|-------|")
    lines.append(f"| MLX composite | {composite_mlx:.3f} |")
    lines.append(f"| Claude composite | {composite_claude:.3f} |")
    lines.append(f"| Overall gap | {format_gap(overall_gap)} |")
    lines.append(f"| Verdict | **{overall_verdict}** |")
    lines.append("")

    report_text = "\n".join(lines)

    # Print to stdout
    print(report_text)

    # Write to file
    report_path = RESULTS_DIR / "report.md"
    report_path.write_text(report_text)
    print(f"\nReport written to {report_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
