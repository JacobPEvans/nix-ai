"""Benchmark: Instruction Following — MLX vs Claude Opus 4.6."""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from common import timed_completion, score_json_valid, write_results, print_test_result


# ---------------------------------------------------------------------------
# Individual test runners
# ---------------------------------------------------------------------------

def run_lipogram() -> dict:
    """Respond about photosynthesis without using the letter 'e'."""
    messages = [
        {
            "role": "system",
            "content": (
                "You must NEVER use the letter 'e' in your response. "
                "Not a single instance of the letter 'e' anywhere in your response."
            ),
        },
        {
            "role": "user",
            "content": "Explain how photosynthesis works in plants.",
        },
    ]
    response, elapsed, tokens = timed_completion(messages)

    count = response.lower().count("e")
    # 0 occurrences = 1.0; 10+ occurrences = 0.0; linear between
    score = max(0.0, 1.0 - count / 10)

    return {
        "name": "lipogram",
        "score": round(score, 4),
        "tokens": tokens,
        "latency": elapsed,
        "e_count": count,
        "response_preview": response[:300],
    }


def run_persona() -> dict:
    """Respond as a 14th-century knight using archaic English."""
    archaic_words = [
        "forsooth", "prithee", "verily", "hark", "thou",
        "thy", "thee", "whilst", "doth", "methinks", "twas", "hearken",
    ]
    messages = [
        {
            "role": "system",
            "content": (
                "You are a medieval knight from the 14th century. You speak in archaic English. "
                "You have never seen modern technology. Stay in character for ALL responses, "
                "even technical questions. Use words like 'forsooth', 'prithee', 'verily', "
                "'hark', 'thou'."
            ),
        },
        {
            "role": "user",
            "content": "Explain how TCP/IP networking works.",
        },
    ]
    response, elapsed, tokens = timed_completion(messages)

    response_lower = response.lower()
    found_archaic = [w for w in archaic_words if w in response_lower]

    # Need at least 2 archaic words; no modern slang
    modern_slang = ["hey", "awesome", "cool", "yeah", "gonna", "wanna", "btw", "ok", "okay"]
    has_slang = any(s in response_lower for s in modern_slang)

    if len(found_archaic) >= 2 and not has_slang:
        score = 1.0
    elif len(found_archaic) >= 2:
        score = 0.7
    elif len(found_archaic) == 1:
        score = 0.4
    else:
        score = 0.0

    return {
        "name": "persona",
        "score": round(score, 4),
        "tokens": tokens,
        "latency": elapsed,
        "archaic_words_found": found_archaic,
        "modern_slang_detected": has_slang,
        "response_preview": response[:300],
    }


def run_yaml_only() -> dict:
    """Respond only in valid YAML — no prose, no markdown wrapper."""
    messages = [
        {
            "role": "system",
            "content": (
                "Respond ONLY in valid YAML format. No prose, no markdown, no explanation "
                "before or after the YAML. Your entire response must be parseable as YAML."
            ),
        },
        {
            "role": "user",
            "content": "List the three largest countries by area with their populations.",
        },
    ]
    response, elapsed, tokens = timed_completion(messages)

    # Reject responses that open with prose
    prose_openers = ["here is", "here are", "sure", "certainly", "of course", "below"]
    starts_with_prose = any(response.lower().strip().startswith(p) for p in prose_openers)

    try:
        import yaml
        yaml.safe_load(response)
        parse_ok = True
    except Exception:
        # Fallback: try to detect basic YAML structure heuristically
        lines = [ln for ln in response.strip().splitlines() if ln.strip()]
        yaml_like = sum(1 for ln in lines if ":" in ln or ln.strip().startswith("-"))
        parse_ok = yaml_like >= max(1, len(lines) * 0.5)

    if parse_ok and not starts_with_prose:
        score = 1.0
    elif parse_ok:
        score = 0.5
    else:
        score = 0.0

    return {
        "name": "yaml_only",
        "score": round(score, 4),
        "tokens": tokens,
        "latency": elapsed,
        "parse_ok": parse_ok,
        "starts_with_prose": starts_with_prose,
        "response_preview": response[:300],
    }


def run_word_count() -> dict:
    """Respond with exactly 50 words."""
    messages = [
        {
            "role": "system",
            "content": (
                "Your response must contain EXACTLY 50 words. "
                "Not 49, not 51 — exactly 50 words. Count carefully."
            ),
        },
        {
            "role": "user",
            "content": "Describe the importance of testing in software development.",
        },
    ]
    response, elapsed, tokens = timed_completion(messages)

    word_count = len(response.split())
    delta = abs(word_count - 50)

    if delta == 0:
        score = 1.0
    elif delta <= 2:
        score = 0.5
    else:
        score = 0.0

    return {
        "name": "word_count",
        "score": round(score, 4),
        "tokens": tokens,
        "latency": elapsed,
        "word_count": word_count,
        "delta_from_50": delta,
        "response_preview": response[:300],
    }


def run_numbered_steps() -> dict:
    """Every line must start with a digit followed by a period."""
    messages = [
        {
            "role": "system",
            "content": (
                "Respond ONLY with numbered steps. Every line must start with a number "
                "followed by a period. No introduction, no conclusion, no commentary, "
                "no blank lines between steps."
            ),
        },
        {
            "role": "user",
            "content": "How do you set up a Python virtual environment and install packages?",
        },
    ]
    response, elapsed, tokens = timed_completion(messages)

    lines = [ln for ln in response.splitlines() if ln.strip()]
    if not lines:
        score = 0.0
        compliant_fraction = 0.0
    else:
        numbered = re.compile(r"^\d+\.")
        compliant = [ln for ln in lines if numbered.match(ln.strip())]
        compliant_fraction = len(compliant) / len(lines)

        # Deduct if first line doesn't start with "1."
        first_ok = lines[0].strip().startswith("1.")
        score = compliant_fraction if first_ok else compliant_fraction * 0.75

    return {
        "name": "numbered_steps",
        "score": round(min(score, 1.0), 4),
        "tokens": tokens,
        "latency": elapsed,
        "total_lines": len(lines) if lines else 0,
        "compliant_fraction": round(compliant_fraction, 4) if lines else 0.0,
        "response_preview": response[:300],
    }


def run_multi_constraint() -> dict:
    """JSON array of exactly 3 objects, each with only 'name' (str) and 'score' (int 1-10)."""
    messages = [
        {
            "role": "system",
            "content": (
                "Respond in valid JSON. The JSON must be an array of exactly 3 objects. "
                "Each object must have exactly two fields: 'name' (a string) and 'score' "
                "(an integer between 1 and 10 inclusive). No additional fields, no nested "
                "objects, no comments."
            ),
        },
        {
            "role": "user",
            "content": "Rate three programming languages for beginners.",
        },
    ]
    response, elapsed, tokens = timed_completion(messages)

    parse_score, obj = score_json_valid(response)
    constraints_met = 0
    total_constraints = 5  # array, length==3, each has 2 keys, name is str, score is int 1-10

    if obj is not None and isinstance(obj, list):
        constraints_met += 1  # is array
        if len(obj) == 3:
            constraints_met += 1  # length == 3
        per_item_ok = 0
        for item in obj:
            if not isinstance(item, dict):
                continue
            if set(item.keys()) == {"name", "score"}:
                per_item_ok += 1
            elif "name" in item and "score" in item:
                # extra keys present — partial credit not awarded per constraint
                pass
        if per_item_ok == len(obj) and len(obj) > 0:
            constraints_met += 1  # each object has exactly 2 keys
        name_ok = all(isinstance(item.get("name"), str) for item in obj if isinstance(item, dict))
        if name_ok and obj:
            constraints_met += 1  # name is string
        score_ok = all(
            isinstance(item.get("score"), int) and 1 <= item.get("score", 0) <= 10
            for item in obj
            if isinstance(item, dict)
        )
        if score_ok and obj:
            constraints_met += 1  # score is int 1-10

    score = parse_score * (constraints_met / total_constraints)

    return {
        "name": "multi_constraint",
        "score": round(min(score, 1.0), 4),
        "tokens": tokens,
        "latency": elapsed,
        "constraints_met": constraints_met,
        "total_constraints": total_constraints,
        "parse_score": parse_score,
        "response_preview": response[:300],
    }


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    print("=== Instruction Following Benchmark ===")
    results = []

    runners = [
        run_lipogram,
        run_persona,
        run_yaml_only,
        run_word_count,
        run_numbered_steps,
        run_multi_constraint,
    ]

    for runner in runners:
        result = runner()
        results.append(result)
        print_test_result(result["name"], result["score"], result["latency"], result["tokens"])

    write_results("instruction_following", results)

    mean = sum(r["score"] for r in results) / len(results)
    print(f"\nMean score: {mean:.3f}")


if __name__ == "__main__":
    main()
