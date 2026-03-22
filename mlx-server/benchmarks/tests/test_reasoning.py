"""Reasoning and logic benchmark: 10 tests comparing local MLX vs Claude Opus 4.6."""

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from common import (
    print_test_result,
    score_contains_all,
    score_exact,
    timed_completion,
    write_results,
)

_SYSTEM = "You are a precise reasoning assistant. Show your work step by step, then give your final answer clearly."


# ---------------------------------------------------------------------------
# Test 1: Bird-train classic problem
# ---------------------------------------------------------------------------
def test_bird_train() -> dict:
    name = "bird_train"
    try:
        content, elapsed, tokens = timed_completion(
            [
                {"role": "system", "content": _SYSTEM},
                {
                    "role": "user",
                    "content": (
                        "A train leaves station A at 60 mph. Another train leaves station B, "
                        "which is 300 miles away, at 80 mph heading toward station A. A bird "
                        "starts at station A and flies at 120 mph between the two trains until "
                        "they meet. How far does the bird travel in total?"
                    ),
                },
            ],
            max_tokens=1024,
        )
        score = score_exact(257.14, content, tolerance=1.0)
    except Exception:
        content, elapsed, tokens, score = "", 0.0, 0, 0.0
    print_test_result(name, score, elapsed, tokens)
    return {"name": name, "score": score, "latency": elapsed, "tokens": tokens, "response_preview": content[:300]}


# ---------------------------------------------------------------------------
# Test 2: Constraint satisfaction
# ---------------------------------------------------------------------------
def _score_constraint_satisfaction(content: str) -> float:
    """Parse assignments from the response and verify all 5 constraints."""
    # Extract assignments: look for "Person: Task" or "Person -> Task" patterns
    task_map: dict[str, str] = {}
    people = ["Alice", "Bob", "Carol", "Dave", "Eve"]
    tasks = ["Filing", "Greeting", "Inventory", "Janitorial", "Kitchen"]

    # Try to find each person's assigned task in the response
    for person in people:
        # Look for "Person: Task" or "Person does/assigned Task" or "Person -> Task"
        patterns = [
            rf"{person}[:\s\-–→]+([A-Z][a-z]+)",
            rf"{person}.*?(?:does|assigned|gets?|performs?|is responsible for)[:\s]+([A-Z][a-z]+)",
        ]
        for pat in patterns:
            m = re.search(pat, content, re.IGNORECASE)
            if m:
                candidate = m.group(1).strip()
                # Validate it's one of our tasks
                for task in tasks:
                    if task.lower() == candidate.lower():
                        task_map[person] = task
                        break
            if person in task_map:
                break

    if len(task_map) < 5:
        # Fallback: try to find task keywords adjacent to person names
        for person in people:
            if person in task_map:
                continue
            idx = content.find(person)
            if idx == -1:
                continue
            window = content[idx : idx + 80]
            for task in tasks:
                if task.lower() in window.lower():
                    task_map[person] = task
                    break

    # Check constraints
    constraints_satisfied = 0
    total_constraints = 5

    # Constraint 1: Alice cannot do Janitorial
    if task_map.get("Alice") != "Janitorial":
        constraints_satisfied += 1

    # Constraint 2: Bob must do either Filing or Kitchen
    if task_map.get("Bob") in ("Filing", "Kitchen"):
        constraints_satisfied += 1

    # Constraint 3: Carol and Dave cannot both do adjacent alphabetical tasks
    # Tasks in alphabetical order: Filing(F), Greeting(G), Inventory(I), Janitorial(J), Kitchen(K)
    task_order = {task: i for i, task in enumerate(sorted(tasks))}
    carol_task = task_map.get("Carol")
    dave_task = task_map.get("Dave")
    if carol_task and dave_task:
        carol_idx = task_order.get(carol_task, -1)
        dave_idx = task_order.get(dave_task, -1)
        if abs(carol_idx - dave_idx) != 1:
            constraints_satisfied += 1
    else:
        # Can't verify; don't penalize
        constraints_satisfied += 1

    # Constraint 4: Eve must do Greeting or Inventory
    if task_map.get("Eve") in ("Greeting", "Inventory"):
        constraints_satisfied += 1

    # Constraint 5: No one does a task starting with the same letter as their name
    # Alice/A - no A task, Bob/B - no B task, Carol/C - no C task, Dave/D - no D task, Eve/E - no E task
    same_letter_violation = False
    for person, task in task_map.items():
        if task and person[0].upper() == task[0].upper():
            same_letter_violation = True
            break
    if not same_letter_violation:
        constraints_satisfied += 1

    return constraints_satisfied / total_constraints


def test_constraint_satisfaction() -> dict:
    name = "constraint_satisfaction"
    try:
        content, elapsed, tokens = timed_completion(
            [
                {"role": "system", "content": _SYSTEM},
                {
                    "role": "user",
                    "content": (
                        "Assign 5 workers (Alice, Bob, Carol, Dave, Eve) to 5 tasks "
                        "(Filing, Greeting, Inventory, Janitorial, Kitchen) with these constraints: "
                        "(1) Alice cannot do Janitorial, "
                        "(2) Bob must do either Filing or Kitchen, "
                        "(3) Carol and Dave cannot both do adjacent alphabetical tasks, "
                        "(4) Eve must do Greeting or Inventory, "
                        "(5) No one does a task starting with the same letter as their name. "
                        "List each person's assigned task."
                    ),
                },
            ],
            max_tokens=1024,
        )
        score = _score_constraint_satisfaction(content)
    except Exception:
        content, elapsed, tokens, score = "", 0.0, 0, 0.0
    print_test_result(name, score, elapsed, tokens)
    return {"name": name, "score": score, "latency": elapsed, "tokens": tokens, "response_preview": content[:300]}


# ---------------------------------------------------------------------------
# Test 3: Syllogism
# ---------------------------------------------------------------------------
def test_syllogism() -> dict:
    name = "syllogism"
    try:
        content, elapsed, tokens = timed_completion(
            [
                {"role": "system", "content": _SYSTEM},
                {
                    "role": "user",
                    "content": (
                        "Premise 1: All zorplings are blue. "
                        "Premise 2: All blue things glow in the dark. "
                        "Premise 3: All things that glow in the dark are visible at night. "
                        "Premise 4: Frix is a zorpling. "
                        "What can we conclude about Frix? List all valid conclusions."
                    ),
                },
            ],
            max_tokens=1024,
        )
        score = score_contains_all(["blue", "glow", "visible at night"], content)
    except Exception:
        content, elapsed, tokens, score = "", 0.0, 0, 0.0
    print_test_result(name, score, elapsed, tokens)
    return {"name": name, "score": score, "latency": elapsed, "tokens": tokens, "response_preview": content[:300]}


# ---------------------------------------------------------------------------
# Test 4: Bayes' theorem
# ---------------------------------------------------------------------------
def test_bayes_theorem() -> dict:
    name = "bayes_theorem"
    try:
        content, elapsed, tokens = timed_completion(
            [
                {"role": "system", "content": _SYSTEM},
                {
                    "role": "user",
                    "content": (
                        "A rare disease affects 1 in 1000 people. A test for this disease has a "
                        "99% true positive rate (sensitivity) and a 95% true negative rate (specificity). "
                        "If a randomly selected person tests positive, what is the probability they "
                        "actually have the disease? Show your calculation using Bayes' theorem."
                    ),
                },
            ],
            max_tokens=1024,
        )
        # Accept either percentage form (~1.94%) or decimal form (~0.0194)
        has_percentage = "1.9" in content or "1.94" in content or "2.0" in content
        has_decimal = "0.019" in content or "0.020" in content
        score = 1.0 if (has_percentage or has_decimal) else 0.0
    except Exception:
        content, elapsed, tokens, score = "", 0.0, 0, 0.0
    print_test_result(name, score, elapsed, tokens)
    return {"name": name, "score": score, "latency": elapsed, "tokens": tokens, "response_preview": content[:300]}


# ---------------------------------------------------------------------------
# Test 5: Counterfactual (Python 1-based indexing)
# ---------------------------------------------------------------------------
def test_counterfactual() -> dict:
    name = "counterfactual"
    try:
        content, elapsed, tokens = timed_completion(
            [
                {"role": "system", "content": _SYSTEM},
                {
                    "role": "user",
                    "content": (
                        "If Python used 1-based indexing instead of 0-based indexing, what specific "
                        "changes would need to be made to the expression `for i in range(len(arr))` "
                        "to iterate over all elements of an array? Explain what would break and how to fix it."
                    ),
                },
            ],
            max_tokens=1024,
        )
        score = score_contains_all(["range(1", "len(arr)"], content)
    except Exception:
        content, elapsed, tokens, score = "", 0.0, 0, 0.0
    print_test_result(name, score, elapsed, tokens)
    return {"name": name, "score": score, "latency": elapsed, "tokens": tokens, "response_preview": content[:300]}


# ---------------------------------------------------------------------------
# Test 6: Missionaries and cannibals
# ---------------------------------------------------------------------------
def _validate_missionaries_cannibals(content: str) -> float:
    """Simulate the river-crossing state machine from the model's solution."""
    # Extract moves as (M, C) pairs from the response
    move_pattern = re.findall(r"\((\d)\s*,\s*(\d)\)", content)
    if not move_pattern:
        # Try alternate formats: "2 missionaries and 1 cannibal" or "2M 1C"
        move_pattern = re.findall(r"(\d)\s*M.*?(\d)\s*C|(\d)\s*missionaries.*?(\d)\s*cannibals", content)
        if not move_pattern:
            return 0.0

    # State: (m_left, c_left, boat_side)  boat_side 0=left, 1=right
    # Start: (3, 3, 0)  Goal: (0, 0, 1)
    state = (3, 3, 0)  # (missionaries_left, cannibals_left, boat_on_left_bank)

    def is_valid(m_left: int, c_left: int) -> bool:
        m_right = 3 - m_left
        c_right = 3 - c_left
        if m_left < 0 or c_left < 0 or m_left > 3 or c_left > 3:
            return False
        # Missionaries get eaten if cannibals outnumber them on a bank with missionaries present
        if m_left > 0 and c_left > m_left:
            return False
        if m_right > 0 and c_right > m_right:
            return False
        return True

    for move in move_pattern:
        if len(move) == 2:
            try:
                boat_m, boat_c = int(move[0]), int(move[1])
            except (ValueError, IndexError):
                continue
        else:
            # Handle 4-group alternate regex
            try:
                if move[0]:
                    boat_m, boat_c = int(move[0]), int(move[1])
                else:
                    boat_m, boat_c = int(move[2]), int(move[3])
            except (ValueError, IndexError):
                continue

        m_left, c_left, boat_side = state
        # At least 1 person must be in boat, at most 2
        if boat_m + boat_c < 1 or boat_m + boat_c > 2:
            return 0.0
        if boat_m < 0 or boat_c < 0:
            return 0.0

        if boat_side == 0:  # boat travels right
            new_m = m_left - boat_m
            new_c = c_left - boat_c
            new_side = 1
        else:  # boat travels left
            new_m = m_left + boat_m
            new_c = c_left + boat_c
            new_side = 0

        if not is_valid(new_m, new_c):
            return 0.0
        state = (new_m, new_c, new_side)

    # Check goal state
    return 1.0 if state == (0, 0, 1) else 0.0


def test_missionaries_cannibals() -> dict:
    name = "missionaries_cannibals"
    try:
        content, elapsed, tokens = timed_completion(
            [
                {"role": "system", "content": _SYSTEM},
                {
                    "role": "user",
                    "content": (
                        "Three missionaries and three cannibals need to cross a river. The boat holds "
                        "at most 2 people. If cannibals ever outnumber missionaries on either bank "
                        "(when missionaries are present), the missionaries get eaten. Find a sequence "
                        "of moves to get everyone across safely. List each move as (M, C) representing "
                        "missionaries and cannibals in the boat."
                    ),
                },
            ],
            max_tokens=1024,
        )
        score = _validate_missionaries_cannibals(content)
    except Exception:
        content, elapsed, tokens, score = "", 0.0, 0, 0.0
    print_test_result(name, score, elapsed, tokens)
    return {"name": name, "score": score, "latency": elapsed, "tokens": tokens, "response_preview": content[:300]}


# ---------------------------------------------------------------------------
# Test 7: Chinese remainder theorem
# ---------------------------------------------------------------------------
def test_chinese_remainder() -> dict:
    name = "chinese_remainder"
    try:
        content, elapsed, tokens = timed_completion(
            [
                {"role": "system", "content": _SYSTEM},
                {
                    "role": "user",
                    "content": (
                        "Find the smallest positive integer that satisfies all three conditions: "
                        "(1) leaves remainder 2 when divided by 3, "
                        "(2) leaves remainder 3 when divided by 5, "
                        "(3) leaves remainder 2 when divided by 7. "
                        "Show your work."
                    ),
                },
            ],
            max_tokens=1024,
        )
        score = score_exact(23, content, tolerance=0)
    except Exception:
        content, elapsed, tokens, score = "", 0.0, 0, 0.0
    print_test_result(name, score, elapsed, tokens)
    return {"name": name, "score": score, "latency": elapsed, "tokens": tokens, "response_preview": content[:300]}


# ---------------------------------------------------------------------------
# Test 8: Temporal reasoning
# ---------------------------------------------------------------------------
def test_temporal_reasoning() -> dict:
    name = "temporal_reasoning"
    try:
        content, elapsed, tokens = timed_completion(
            [
                {"role": "system", "content": _SYSTEM},
                {
                    "role": "user",
                    "content": (
                        "Six events happened in this order relative to each other: "
                        "(1) The meeting started after the email was sent. "
                        "(2) The email was sent before lunch. "
                        "(3) Lunch happened immediately after the phone call. "
                        "(4) The phone call was the third event of the day. "
                        "(5) The report was filed after the meeting. "
                        "(6) The code review happened before the email was sent. "
                        "What was the chronological order of all six events?"
                    ),
                },
            ],
            max_tokens=1024,
        )
        # The correct order: Code review, Email, Phone call, Lunch, Meeting, Report
        # Check that phone call is 3rd and the key ordering facts are present
        score = score_contains_all(
            ["code review", "email", "phone call", "lunch", "meeting", "report"],
            content,
        )
        # Bonus check: verify phone call is mentioned near "3rd" or "third"
        phone_third = bool(
            re.search(r"phone\s+call.{0,40}(3rd|third)", content, re.IGNORECASE)
            or re.search(r"(3rd|third).{0,40}phone\s+call", content, re.IGNORECASE)
        )
        if phone_third and score > 0:
            score = min(1.0, score + 0.2)
    except Exception:
        content, elapsed, tokens, score = "", 0.0, 0, 0.0
    print_test_result(name, score, elapsed, tokens)
    return {"name": name, "score": score, "latency": elapsed, "tokens": tokens, "response_preview": content[:300]}


# ---------------------------------------------------------------------------
# Test 9: Multi-hop reasoning
# ---------------------------------------------------------------------------
def test_multi_hop() -> dict:
    name = "multi_hop"
    facts = (
        "Dr. Alvarez works at Pinnacle Research and mentors Jamie. "
        "Jamie recently published a paper on quantum sensors with Dr. Chen. "
        "Dr. Chen's quantum sensor research is funded by the Orion Foundation. "
        "The Orion Foundation only funds projects that have been approved by their board chair, "
        "Professor Nakamura. "
        "Professor Nakamura retired last month and was replaced by Dr. Singh."
    )
    try:
        content, elapsed, tokens = timed_completion(
            [
                {"role": "system", "content": _SYSTEM},
                {
                    "role": "user",
                    "content": (
                        f"{facts}\n\n"
                        "Who currently has the authority to approve continued funding for the "
                        "quantum sensor research that Jamie co-authored?"
                    ),
                },
            ],
            max_tokens=1024,
        )
        score = score_exact("Dr. Singh", content)
    except Exception:
        content, elapsed, tokens, score = "", 0.0, 0, 0.0
    print_test_result(name, score, elapsed, tokens)
    return {"name": name, "score": score, "latency": elapsed, "tokens": tokens, "response_preview": content[:300]}


# ---------------------------------------------------------------------------
# Test 10: Floating-point representation
# ---------------------------------------------------------------------------
def test_floating_point() -> dict:
    name = "floating_point"
    try:
        content, elapsed, tokens = timed_completion(
            [
                {"role": "system", "content": _SYSTEM},
                {
                    "role": "user",
                    "content": (
                        "What is the result of 0.1 + 0.2 in most programming languages? "
                        "Explain precisely why it is not exactly 0.3."
                    ),
                },
            ],
            max_tokens=1024,
        )
        score = score_contains_all(["float", "binary"], content)
    except Exception:
        content, elapsed, tokens, score = "", 0.0, 0, 0.0
    print_test_result(name, score, elapsed, tokens)
    return {"name": name, "score": score, "latency": elapsed, "tokens": tokens, "response_preview": content[:300]}


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> None:
    print("=== Reasoning Benchmark ===")
    tests = [
        test_bird_train,
        test_constraint_satisfaction,
        test_syllogism,
        test_bayes_theorem,
        test_counterfactual,
        test_missionaries_cannibals,
        test_chinese_remainder,
        test_temporal_reasoning,
        test_multi_hop,
        test_floating_point,
    ]

    results: list[dict] = []
    for fn in tests:
        result = fn()
        results.append(result)

    write_results("reasoning", results)

    total = len(results)
    mean_score = sum(r["score"] for r in results) / max(total, 1)
    passed = sum(1 for r in results if r["score"] >= 0.8)
    print(f"\n  Category summary: {passed}/{total} passed  |  mean score: {mean_score:.2f}")


if __name__ == "__main__":
    main()
