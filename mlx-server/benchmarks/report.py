"""Generate MLX vs Claude Opus 4.6 / Sonnet 4.6 comparison report."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from common import RESULTS_DIR, CLAUDE_BASELINES, get_verdict, get_model


def load_results() -> dict[str, dict]:
    """Load all result JSON files from RESULTS_DIR. Returns {category: data}."""
    loaded = {}
    for path in sorted(RESULTS_DIR.glob("*.json")):
        try:
            data = json.loads(path.read_text())
            category = data.get("category", path.stem)
            loaded[category] = data
        except (json.JSONDecodeError, OSError):
            print(f"  WARNING: Could not load {path}", file=sys.stderr)
    return loaded


def compute_gap(mlx_score: float, baseline_score: float) -> float:
    """Return absolute gap (baseline - MLX). Positive means MLX is behind."""
    return baseline_score - mlx_score


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

    opus_baselines = CLAUDE_BASELINES.get("opus", {})
    sonnet_baselines = CLAUDE_BASELINES.get("sonnet", {})

    categories = []
    all_tests_shortcoming = []
    all_tests_minor_gap = []
    all_tests_strength = []
    composite_mlx = []
    composite_opus = []
    composite_sonnet = []

    for category, data in results.items():
        summary = data.get("summary", {})
        mlx_mean = summary.get("mean_score", 0.0)
        total_runtime += summary.get("total_latency", 0.0)
        if timestamp is None:
            timestamp = data.get("timestamp", "unknown")

        opus_cat = opus_baselines.get(category, {})
        sonnet_cat = sonnet_baselines.get(category, {})
        opus_mean = opus_cat.get("mean_score", 0.0)
        sonnet_mean = sonnet_cat.get("mean_score", 0.0)

        opus_gap = compute_gap(mlx_mean, opus_mean)
        sonnet_gap = compute_gap(mlx_mean, sonnet_mean)
        verdict = get_verdict(mlx_mean, opus_mean)

        categories.append({
            "category": category,
            "mlx_mean": mlx_mean,
            "opus_mean": opus_mean,
            "sonnet_mean": sonnet_mean,
            "opus_gap": opus_gap,
            "sonnet_gap": sonnet_gap,
            "verdict": verdict,
        })
        composite_mlx.append(mlx_mean)
        composite_opus.append(opus_mean)
        composite_sonnet.append(sonnet_mean)

        # Per-test analysis (compared against Opus as primary target)
        opus_per_test = opus_cat.get("per_test", {})
        sonnet_per_test = sonnet_cat.get("per_test", {})
        for test in data.get("tests", []):
            test_name = test.get("name", "unknown")
            test_score = test.get("score", 0.0)
            opus_test = opus_per_test.get(test_name, opus_mean)
            sonnet_test = sonnet_per_test.get(test_name, sonnet_mean)
            test_gap = compute_gap(test_score, opus_test)
            preview = test.get("response_preview", "")[:120]

            entry = {
                "category": category,
                "name": test_name,
                "mlx_score": test_score,
                "opus_score": opus_test,
                "sonnet_score": sonnet_test,
                "gap": test_gap,
                "preview": preview,
            }

            if test_score < 0.5 or test_gap / max(opus_test, 0.001) > 0.25:
                all_tests_shortcoming.append(entry)
            elif test_gap / max(opus_test, 0.001) >= 0.10:
                all_tests_minor_gap.append(entry)
            else:
                all_tests_strength.append(entry)

    mean_mlx = sum(composite_mlx) / max(len(composite_mlx), 1)
    mean_opus = sum(composite_opus) / max(len(composite_opus), 1)
    mean_sonnet = sum(composite_sonnet) / max(len(composite_sonnet), 1)
    overall_verdict = get_verdict(mean_mlx, mean_opus)
    overall_opus_gap = compute_gap(mean_mlx, mean_opus)
    overall_sonnet_gap = compute_gap(mean_mlx, mean_sonnet)

    # Build markdown
    lines = []
    lines.append("# MLX Flagship Model — Capability Benchmark Report")
    lines.append("")
    lines.append(f"**Model:** `{model}`  ")
    lines.append(f"**Timestamp:** {timestamp or 'unknown'}  ")
    lines.append(f"**Total runtime:** {total_runtime / 60:.1f}m  ")
    lines.append("")

    # Summary table — three-way comparison
    lines.append("## Summary")
    lines.append("")
    lines.append("| Category | MLX | Sonnet 4.6 | Opus 4.6 | vs Sonnet | vs Opus | Verdict |")
    lines.append("|----------|-----|------------|----------|-----------|---------|---------|")
    for cat in categories:
        lines.append(
            f"| {cat['category']} "
            f"| {cat['mlx_mean']:.2f} "
            f"| {cat['sonnet_mean']:.2f} "
            f"| {cat['opus_mean']:.2f} "
            f"| {format_gap(cat['sonnet_gap'])} "
            f"| {format_gap(cat['opus_gap'])} "
            f"| {cat['verdict']} |"
        )
    lines.append(
        f"| **OVERALL** "
        f"| **{mean_mlx:.2f}** "
        f"| **{mean_sonnet:.2f}** "
        f"| **{mean_opus:.2f}** "
        f"| **{format_gap(overall_sonnet_gap)}** "
        f"| **{format_gap(overall_opus_gap)}** "
        f"| **{overall_verdict}** |"
    )
    lines.append("")

    # Shortcomings (vs Opus)
    lines.append("## Explicit Shortcomings (vs Opus 4.6)")
    lines.append("")
    if all_tests_shortcoming:
        lines.append("Tests where MLX scored below 0.5 or the gap exceeds 25% of the Opus baseline:")
        lines.append("")
        for t in all_tests_shortcoming:
            gap_pct = t["gap"] / max(t["opus_score"], 0.001) * 100
            sonnet_gap_pct = compute_gap(t["mlx_score"], t["sonnet_score"]) / max(t["sonnet_score"], 0.001) * 100
            lines.append(f"### {t['category']} / {t['name']}")
            lines.append(f"- **MLX:** {t['mlx_score']:.2f} | **Sonnet:** {t['sonnet_score']:.2f} | **Opus:** {t['opus_score']:.2f}")
            lines.append(f"- **vs Opus:** {gap_pct:.1f}% below | **vs Sonnet:** {sonnet_gap_pct:.1f}% below")
            if t["preview"]:
                lines.append(f"- **Response preview:** `{t['preview']}`")
            lines.append("")
    else:
        lines.append("_No shortcomings detected. MLX is within 25% of Opus on all tests._")
        lines.append("")

    # Minor gaps
    lines.append("## Minor Gaps")
    lines.append("")
    if all_tests_minor_gap:
        lines.append("Tests where the gap is 10–25% below Opus baseline:")
        lines.append("")
        for t in all_tests_minor_gap:
            gap_pct = t["gap"] / max(t["opus_score"], 0.001) * 100
            lines.append(
                f"- **{t['category']} / {t['name']}**: "
                f"MLX {t['mlx_score']:.2f} vs Sonnet {t['sonnet_score']:.2f} vs Opus {t['opus_score']:.2f} "
                f"({gap_pct:.1f}% below Opus)"
            )
        lines.append("")
    else:
        lines.append("_No minor gaps detected._")
        lines.append("")

    # Strengths
    lines.append("## Strengths (At Parity with Opus)")
    lines.append("")
    if all_tests_strength:
        lines.append("Tests where MLX is within 10% of Opus baseline:")
        lines.append("")
        for t in all_tests_strength:
            lines.append(
                f"- **{t['category']} / {t['name']}**: "
                f"MLX {t['mlx_score']:.2f} vs Sonnet {t['sonnet_score']:.2f} vs Opus {t['opus_score']:.2f}"
            )
        lines.append("")
    else:
        lines.append("_No tests at parity._")
        lines.append("")

    # Overall composite
    lines.append("## Overall Composite Score")
    lines.append("")
    lines.append("| Metric | MLX | Sonnet 4.6 | Opus 4.6 |")
    lines.append("|--------|-----|------------|----------|")
    lines.append(f"| Composite | {mean_mlx:.3f} | {mean_sonnet:.3f} | {mean_opus:.3f} |")
    lines.append(f"| vs Sonnet gap | {format_gap(overall_sonnet_gap)} | — | — |")
    lines.append(f"| vs Opus gap | {format_gap(overall_opus_gap)} | — | — |")
    lines.append(f"| Verdict | **{overall_verdict}** | | |")
    lines.append("")

    report_text = "\n".join(lines)

    print(report_text)

    report_path = RESULTS_DIR / "report.md"
    report_path.write_text(report_text)
    print(f"\nReport written to {report_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
