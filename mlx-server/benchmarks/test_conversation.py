"""Benchmark: Multi-turn Conversation Coherence — MLX vs Claude Opus 4.6."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from common import get_client, get_model, score_exact, score_contains_all, write_results, print_test_result
import time


def multi_turn(system_prompt, turns, final_question, max_tokens=512):
    """Run a multi-turn conversation. turns is list of (user_msg, None) pairs.
    Returns (final_response, elapsed, total_tokens)."""
    client = get_client()
    messages = [{"role": "system", "content": system_prompt}]
    total_tokens = 0
    start = time.time()

    for user_msg, _ in turns:
        messages.append({"role": "user", "content": user_msg})
        response = client.chat.completions.create(
            model=get_model(), messages=messages, max_tokens=256, temperature=0
        )
        assistant_msg = response.choices[0].message.content or ""
        messages.append({"role": "assistant", "content": assistant_msg})
        total_tokens += response.usage.completion_tokens if response.usage else 0

    # Final question
    messages.append({"role": "user", "content": final_question})
    response = client.chat.completions.create(
        model=get_model(), messages=messages, max_tokens=max_tokens, temperature=0
    )
    final = response.choices[0].message.content or ""
    total_tokens += response.usage.completion_tokens if response.usage else 0
    elapsed = time.time() - start
    return final, elapsed, total_tokens


# ---------------------------------------------------------------------------
# Test 1: pronoun_resolution
# ---------------------------------------------------------------------------
def test_pronoun_resolution() -> dict:
    name = "pronoun_resolution"
    system = "You are a helpful assistant. Pay careful attention to who is being discussed."
    turns = [
        ("I'd like to tell you about three people. Alice is a software engineer who loves hiking.", None),
        ("Bob is a chef who recently moved to Portland.", None),
        ("Carol is a teacher. She and Alice went to college together.", None),
        ("Alice just got promoted to senior engineer at her company.", None),
        ("Carol mentioned she's planning a surprise party for her old college friend.", None),
    ]
    final_question = "Who is Carol planning the surprise party for, and what is that person's current job title?"
    try:
        response, elapsed, tokens = multi_turn(system, turns, final_question)
        score = score_contains_all(["alice", "senior engineer"], response)
    except Exception:
        response, elapsed, tokens, score = "", 0.0, 0, 0.0
    print_test_result(name, score, elapsed, tokens)
    return {"name": name, "score": score, "latency": elapsed, "tokens": tokens, "response_preview": response[:300]}


# ---------------------------------------------------------------------------
# Test 2: running_counter
# ---------------------------------------------------------------------------
def test_running_counter() -> dict:
    name = "running_counter"
    system = "You are a calculator assistant. Keep a running total. After each operation, state the current total clearly."
    turns = [
        ("Start with 0", None),
        ("Add 7", None),
        ("Multiply by 3", None),
        ("Subtract 6", None),
        ("Divide by 5", None),
        ("Add 12", None),
        ("Multiply by 2", None),
    ]
    final_question = "What is the current total?"
    # 0 -> 7 -> 21 -> 15 -> 3 -> 15 -> 30
    try:
        response, elapsed, tokens = multi_turn(system, turns, final_question)
        score = score_exact(30, response, tolerance=0.1)
    except Exception:
        response, elapsed, tokens, score = "", 0.0, 0, 0.0
    print_test_result(name, score, elapsed, tokens)
    return {"name": name, "score": score, "latency": elapsed, "tokens": tokens, "response_preview": response[:300]}


# ---------------------------------------------------------------------------
# Test 3: preference_memory
# ---------------------------------------------------------------------------
def test_preference_memory() -> dict:
    name = "preference_memory"
    system = "You are a personal assistant. Remember and respect the user's stated preferences."
    turns = [
        ("I'm vegetarian and allergic to nuts.", None),
        ("My favorite cuisine is Thai food.", None),
        ("I prefer spicy food, level 3 out of 5.", None),
        ("I don't like mushrooms either.", None),
    ]
    final_question = "Recommend a specific Thai dish for me, explaining why it matches my preferences."
    try:
        response, elapsed, tokens = multi_turn(system, turns, final_question)
        response_lower = response.lower()
        # Must reference Thai and spice/spicy
        base_score = score_contains_all(["thai"], response)
        has_spice = any(word in response_lower for word in ["spic", "spicy", "level 3", "heat"])
        # Must NOT recommend something with meat or nuts
        has_meat = any(word in response_lower for word in ["chicken", "pork", "beef", "meat", "fish sauce"])
        has_nuts = any(word in response_lower for word in ["peanut", "cashew", "almond", "nut"])
        if has_meat or has_nuts:
            score = 0.0
        elif base_score >= 1.0 and has_spice:
            score = 1.0
        elif base_score >= 1.0:
            score = 0.7
        else:
            score = base_score * 0.5
    except Exception:
        response, elapsed, tokens, score = "", 0.0, 0, 0.0
    print_test_result(name, score, elapsed, tokens)
    return {"name": name, "score": score, "latency": elapsed, "tokens": tokens, "response_preview": response[:300]}


# ---------------------------------------------------------------------------
# Test 4: contradiction_detection
# ---------------------------------------------------------------------------
def test_contradiction_detection() -> dict:
    name = "contradiction_detection"
    system = "You are an attentive assistant. If the user contradicts something they said earlier, point it out."
    turns = [
        ("I've been programming in Python for 10 years.", None),
        ("I mainly work on backend services.", None),
        ("I've never used any programming language before.", None),
        ("Can you recommend a project for me?", None),
    ]
    final_question = "Wait — do you see any contradictions in what I've told you?"
    try:
        response, elapsed, tokens = multi_turn(system, turns, final_question)
        response_lower = response.lower()
        has_contradict = "contradict" in response_lower
        has_python_ref = "python" in response_lower or "10 year" in response_lower
        has_never_ref = "never" in response_lower
        if has_contradict and has_python_ref and has_never_ref:
            score = 1.0
        elif has_contradict and (has_python_ref or has_never_ref):
            score = 0.75
        elif has_contradict:
            score = 0.5
        else:
            score = 0.0
    except Exception:
        response, elapsed, tokens, score = "", 0.0, 0, 0.0
    print_test_result(name, score, elapsed, tokens)
    return {"name": name, "score": score, "latency": elapsed, "tokens": tokens, "response_preview": response[:300]}


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> None:
    print("=== Conversation Coherence Benchmark ===")
    tests = [
        test_pronoun_resolution,
        test_running_counter,
        test_preference_memory,
        test_contradiction_detection,
    ]

    results: list[dict] = []
    for fn in tests:
        result = fn()
        results.append(result)

    write_results("conversation", results)

    total = len(results)
    mean_score = sum(r["score"] for r in results) / max(total, 1)
    passed = sum(1 for r in results if r["score"] >= 0.8)
    print(f"\n  Category summary: {passed}/{total} passed  |  mean score: {mean_score:.2f}")


if __name__ == "__main__":
    main()
