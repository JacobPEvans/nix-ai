"""Benchmark: Code Review & Bug Detection — MLX vs Claude Opus 4.6."""
import sys
from pathlib import Path

# Add parent to path for common imports
sys.path.insert(0, str(Path(__file__).parent))
from common import timed_completion, score_contains_all, write_results, print_test_result

FIXTURES_DIR = Path(__file__).parent / "fixtures" / "buggy_code"

SYSTEM_PROMPT = (
    "You are an expert code reviewer. Analyze the following code for bugs, "
    "security vulnerabilities, race conditions, memory leaks, and other issues. "
    "For each bug found, specify: (1) the exact line or variable involved, "
    "(2) the type of bug, (3) why it's a problem, (4) how to fix it. "
    "If the code is correct, say 'No bugs found.'"
)

# Bug keyword groups: each bug is a list of keyword groups.
# A bug is detected if ANY group fully matches (all keywords in that group present).
FIXTURES = [
    {
        "file": "auth_bypass.py",
        "planted_bugs": [
            # Bug 1: Timing attack
            [["timing"], ["compare_digest"], ["constant.time"]],
            # Bug 2: Missing rate limiting
            [["rate limit"], ["brute force"], ["throttl"]],
            # Bug 3: Session fixation
            [["session fixation"], ["regenerat"], ["new session"]],
        ],
        "false_positive_test": False,
    },
    {
        "file": "race_condition.py",
        "planted_bugs": [
            # Bug 1: TOCTOU
            [["toctou"], ["time of check"], ["race", "exists"]],
            # Bug 2: Unprotected shared counter
            [["lock"], ["mutex"], ["thread.safe"], ["atomic"]],
        ],
        "false_positive_test": False,
    },
    {
        "file": "memory_leak.py",
        "planted_bugs": [
            # Bug 1: Unclosed file handle
            [["file", "close"], ["file", "context manager"], ["file", "with"]],
            # Bug 2: Growing cache without eviction
            [["unbounded"], ["evict"], ["cache.grow"], ["memory.leak"]],
        ],
        "false_positive_test": False,
    },
    {
        "file": "subtle_off_by_one.py",
        "planted_bugs": [
            # Bug 1: Pagination fence-post
            [["page", "1-index"], ["page", "off.by"], ["page", "page-1"], ["page", "page - 1"]],
            # Bug 2: Binary search boundary
            [["len", "-1"], ["len", "minus.1"], ["len", "high.*len.*-.*1"]],
            # Bug 3: Sliding window range
            [["len(arr)", "not.*-.*1"], ["range.*len(arr)"], ["miss.*last"]],
        ],
        "false_positive_test": False,
    },
    {
        "file": "type_coercion.js",
        "planted_bugs": [
            # Bug 1: Loose equality
            [["==="], ["strict.equal"], ["loose.equal"]],
            # Bug 2: parseInt without radix
            [["radix"], ["parseint.*10"], ["base.10"]],
            # Bug 3: Falsy zero
            [["falsy"], ["zero"], ["0.*false"], ["!quantity.*0"]],
        ],
        "false_positive_test": False,
    },
    {
        "file": "clean_code.py",
        "planted_bugs": [],
        "false_positive_test": True,
    },
]

# Phrases that indicate the model correctly found no bugs
NO_BUG_PHRASES = [
    "no bugs",
    "no issues",
    "looks correct",
    "correctly implemented",
    "no bugs found",
    "no significant bugs",
    "no errors",
    "well.implemented",
    "clean code",
]


def bug_detected(response: str, keyword_groups: list[list[str]]) -> bool:
    """Check if any keyword group matches (OR between groups, AND within a group).

    Each element of keyword_groups is a list of keywords that must ALL be present
    for that group to match. If ANY group matches, the bug is considered detected.
    """
    text = response.lower().replace("-", ".").replace("_", ".")
    for group in keyword_groups:
        if all(kw.lower() in text for kw in group):
            return True
    return False


def score_file_review(response: str, fixture: dict) -> dict:
    """Score a model's code review response for a given fixture.

    Returns a dict with:
      - true_positives: number of planted bugs correctly identified
      - false_positives: number of spurious bugs reported on clean code
      - total_planted: total number of planted bugs
      - precision: TP / (TP + FP), or 1.0 if no bugs reported
      - recall: TP / total_planted, or N/A for false-positive-only test
      - f1: harmonic mean of precision and recall
      - is_false_positive_test: whether this was the clean code fixture
    """
    planted_bugs = fixture["planted_bugs"]
    is_fp_test = fixture["false_positive_test"]

    if is_fp_test:
        # Clean code: check whether the model (incorrectly) reports bugs
        text = response.lower().replace("-", ".").replace("_", ".")
        claimed_no_bugs = any(phrase in text for phrase in NO_BUG_PHRASES)
        # Heuristic: if the response is short and contains a no-bug phrase, it's correct
        false_positive = not claimed_no_bugs
        return {
            "true_positives": 0,
            "false_positives": 1 if false_positive else 0,
            "total_planted": 0,
            "precision": 0.0 if false_positive else 1.0,
            "recall": None,
            "f1": 0.0 if false_positive else 1.0,
            "is_false_positive_test": True,
        }

    true_positives = sum(
        1 for bug_kw_groups in planted_bugs if bug_detected(response, bug_kw_groups)
    )
    total_planted = len(planted_bugs)

    # For buggy files we don't have a reliable way to count false positives from
    # keyword matching alone, so we report precision based only on TP vs planted.
    # A more sophisticated harness could use an LLM judge for FP counting.
    false_positives = 0
    precision = true_positives / (true_positives + false_positives) if (true_positives + false_positives) > 0 else 0.0
    recall = true_positives / total_planted if total_planted > 0 else 0.0
    f1 = (2 * precision * recall / (precision + recall)) if (precision + recall) > 0 else 0.0

    return {
        "true_positives": true_positives,
        "false_positives": false_positives,
        "total_planted": total_planted,
        "precision": precision,
        "recall": recall,
        "f1": f1,
        "is_false_positive_test": False,
    }


def run_review(fixture: dict) -> dict:
    """Run a single code review benchmark against the configured model."""
    filepath = FIXTURES_DIR / fixture["file"]
    code = filepath.read_text()
    language = "python" if fixture["file"].endswith(".py") else "javascript"
    user_message = f"Review this {language} code:\n\n```{language}\n{code}\n```"

    try:
        response, elapsed, tokens = timed_completion([
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_message},
        ])
    except Exception:
        response, elapsed, tokens = "", 0.0, 0

    scores = score_file_review(response, fixture)
    result = {
        "name": fixture["file"].replace(".py", "").replace(".js", ""),
        "fixture": fixture["file"],
        "score": scores["f1"],
        "latency": round(elapsed, 2),
        "tokens": tokens,
        **scores,
        "response_preview": response[:300],
    }
    return result, response


def main():
    all_results = []
    total_tp = 0
    total_planted = 0
    fp_test_passed = None

    print("=" * 70)
    print("Code Review & Bug Detection Benchmark")
    print("=" * 70)

    for fixture in FIXTURES:
        print(f"\n--- {fixture['file']} ---")
        result, full_response = run_review(fixture)
        all_results.append(result)

        if result["is_false_positive_test"]:
            status = "PASS" if result["false_positives"] == 0 else "FAIL"
            fp_test_passed = result["false_positives"] == 0
            print(f"  False-positive test: {status}")
            print(f"  F1: {result['f1']:.2f} | Elapsed: {result['elapsed_s']}s")
        else:
            total_tp += result["true_positives"]
            total_planted += result["total_planted"]
            print(
                f"  Bugs found: {result['true_positives']}/{result['total_planted']} "
                f"| Recall: {result['recall']:.2f} | F1: {result['f1']:.2f} "
                f"| Elapsed: {result['elapsed_s']}s"
            )

        print_test_result(result["name"], result["score"], result["latency"], result["tokens"])

    # Aggregate summary
    overall_recall = total_tp / total_planted if total_planted > 0 else 0.0
    print("\n" + "=" * 70)
    print("Summary")
    print("=" * 70)
    print(f"  Overall bug recall: {total_tp}/{total_planted} ({overall_recall:.1%})")
    print(f"  False-positive test: {'PASS' if fp_test_passed else 'FAIL'}")

    write_results("code_review", all_results)

    mean_score = sum(r["score"] for r in all_results) / max(len(all_results), 1)
    print(f"\n  Category summary: mean F1 = {mean_score:.2f}")


if __name__ == "__main__":
    main()
