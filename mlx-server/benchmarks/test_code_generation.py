"""Benchmark: code generation capabilities of local MLX model."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from common import (
    extract_code_block,
    print_test_result,
    score_code_runs,
    timed_completion,
    write_results,
)

SYSTEM_PROMPT = (
    "You are an expert programmer. Write clean, correct, production-quality code. "
    "Return ONLY the code in a single code block with the appropriate language tag."
)

# ---------------------------------------------------------------------------
# Test 1: LRU Cache
# ---------------------------------------------------------------------------

_LRU_ASSERTIONS = """
cache = LRUCache(2)
cache.put(1, 1)
cache.put(2, 2)
assert cache.get(1) == 1, "FAIL: basic get"
cache.put(3, 3)  # evicts key 2
assert cache.get(2) == -1, "FAIL: eviction"
assert cache.get(3) == 3, "FAIL: get after eviction"
cache.put(4, 4)  # evicts key 1
assert cache.get(1) == -1, "FAIL: second eviction"
assert cache.get(3) == 3, "FAIL: not evicted"
assert cache.get(4) == 4, "FAIL: latest"
cache.put(3, 30)  # update existing
assert cache.get(3) == 30, "FAIL: update value"
cache.put(5, 5)  # evicts key 4 (LRU)
assert cache.get(4) == -1, "FAIL: LRU after update"
assert cache.get(5) == 5, "FAIL: new entry"
cache2 = LRUCache(1)
cache2.put(1, 1)
cache2.put(2, 2)
assert cache2.get(1) == -1, "FAIL: capacity 1"
print("All LRU cache tests passed")
"""


def test_lru_cache() -> dict:
    content, elapsed, tokens = timed_completion(
        [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": (
                    "Implement an LRU (Least Recently Used) cache in Python with O(1) time "
                    "complexity for both get and put operations. The class should be called "
                    "LRUCache, take a capacity parameter, and have get(key) and put(key, value) "
                    "methods. get() should return -1 for missing keys."
                ),
            },
        ],
        max_tokens=2048,
    )
    code = extract_code_block(content, "python")
    score = score_code_runs(code, "python", test_code=_LRU_ASSERTIONS)
    print_test_result("lru_cache", score, elapsed, tokens)
    return {"name": "lru_cache", "score": score, "latency": round(elapsed, 2), "tokens": tokens}


# ---------------------------------------------------------------------------
# Test 2: Async Rate Limiter
# ---------------------------------------------------------------------------

_RATE_LIMITER_TEST = """
import asyncio
async def test_rate_limiter():
    bucket = TokenBucket(rate=10, capacity=10)
    # Should succeed immediately (bucket starts full)
    assert await bucket.acquire(5), "FAIL: initial acquire"
    assert await bucket.acquire(5), "FAIL: second acquire"
    # Bucket now empty, next acquire should take ~0.1s for 1 token
    start = asyncio.get_event_loop().time()
    assert await bucket.acquire(1), "FAIL: refill acquire"
    elapsed = asyncio.get_event_loop().time() - start
    assert elapsed >= 0.05, f"FAIL: should wait for refill, got {elapsed}"
    assert elapsed < 2.0, f"FAIL: waited too long {elapsed}"
    print("All rate limiter tests passed")
asyncio.run(test_rate_limiter())
"""


def test_async_rate_limiter() -> dict:
    content, elapsed, tokens = timed_completion(
        [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": (
                    "Write a Python async token bucket rate limiter class called TokenBucket. "
                    "Constructor takes rate (tokens per second) and capacity (max tokens). "
                    "It should have an async method acquire(tokens=1) that waits if insufficient "
                    "tokens are available. Use asyncio."
                ),
            },
        ],
        max_tokens=2048,
    )
    code = extract_code_block(content, "python")
    score = score_code_runs(code, "python", test_code=_RATE_LIMITER_TEST)
    print_test_result("async_rate_limiter", score, elapsed, tokens)
    return {
        "name": "async_rate_limiter",
        "score": score,
        "latency": round(elapsed, 2),
        "tokens": tokens,
    }


# ---------------------------------------------------------------------------
# Test 3: TypeScript Generics
# ---------------------------------------------------------------------------


def test_typescript_generics() -> dict:
    content, elapsed, tokens = timed_completion(
        [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": (
                    "Write a TypeScript type-safe event emitter class "
                    "EventEmitter<T extends Record<string, any[]>>. It should have methods "
                    "on<K extends keyof T>(event: K, handler: (...args: T[K]) => void), "
                    "off<K extends keyof T>(event: K, handler: (...args: T[K]) => void), and "
                    "emit<K extends keyof T>(event: K, ...args: T[K]). Include a usage example."
                ),
            },
        ],
        max_tokens=2048,
    )
    code = extract_code_block(content, "typescript")
    score = score_code_runs(code, "typescript")
    if score == -1.0:
        print(f"  [SKIPPED] typescript_generics: TypeScript toolchain not available ({elapsed:.1f}s, {tokens} tok)")
        return {
            "name": "typescript_generics",
            "score": 0.0,
            "skipped": True,
            "latency": round(elapsed, 2),
            "tokens": tokens,
        }
    print_test_result("typescript_generics", score, elapsed, tokens)
    return {
        "name": "typescript_generics",
        "score": score,
        "latency": round(elapsed, 2),
        "tokens": tokens,
    }


# ---------------------------------------------------------------------------
# Test 4: Nix Derivation
# ---------------------------------------------------------------------------


def test_nix_derivation() -> dict:
    content, elapsed, tokens = timed_completion(
        [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": (
                    "Write a Nix expression using mkDerivation to build a simple C 'Hello World' "
                    "program. The source should be inline (using writeText or builtins.toFile). "
                    "Import nixpkgs with `{ pkgs ? import <nixpkgs> {} }:`. "
                    "The derivation should produce a binary called 'hello'."
                ),
            },
        ],
        max_tokens=2048,
    )
    code = extract_code_block(content, "nix")
    score = score_code_runs(code, "nix")
    if score == -1.0:
        print(f"  [SKIPPED] nix_derivation: nix-instantiate not available ({elapsed:.1f}s, {tokens} tok)")
        return {
            "name": "nix_derivation",
            "score": 0.0,
            "skipped": True,
            "latency": round(elapsed, 2),
            "tokens": tokens,
        }
    print_test_result("nix_derivation", score, elapsed, tokens)
    return {
        "name": "nix_derivation",
        "score": score,
        "latency": round(elapsed, 2),
        "tokens": tokens,
    }


# ---------------------------------------------------------------------------
# Test 5: CSV to JSON Bash
# ---------------------------------------------------------------------------


def test_csv_to_json_bash() -> dict:
    content, elapsed, tokens = timed_completion(
        [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": (
                    "Write a bash script that reads CSV from stdin and outputs JSON array to stdout. "
                    "Handle: (1) quoted fields containing commas, (2) header row becomes JSON keys, "
                    "(3) empty fields become null. "
                    "Do NOT use python, perl, or other languages — pure bash only."
                ),
            },
        ],
        max_tokens=2048,
    )
    code = extract_code_block(content, "bash")
    score = score_code_runs(code, "bash")
    print_test_result("csv_to_json_bash", score, elapsed, tokens)
    return {
        "name": "csv_to_json_bash",
        "score": score,
        "latency": round(elapsed, 2),
        "tokens": tokens,
    }


# ---------------------------------------------------------------------------
# Test 6: Dijkstra
# ---------------------------------------------------------------------------

_DIJKSTRA_ASSERTIONS = """
graph = {
    'A': [('B', 1), ('C', 4)],
    'B': [('C', 2), ('D', 5)],
    'C': [('D', 1)],
    'D': [],
}
dist, path = dijkstra(graph, 'A', 'D')
assert dist == 4, f"FAIL: expected 4, got {dist}"
assert path == ['A', 'B', 'C', 'D'], f"FAIL: wrong path {path}"
dist2, path2 = dijkstra(graph, 'A', 'A')
assert dist2 == 0, f"FAIL: same node distance"
dist3, path3 = dijkstra(graph, 'D', 'A')
assert dist3 == -1, f"FAIL: unreachable should be -1"
assert path3 == [], "FAIL: unreachable path should be empty"
graph2 = {'A': [('B', 10), ('C', 3)], 'B': [('D', 2)], 'C': [('B', 1), ('D', 8)], 'D': []}
dist4, path4 = dijkstra(graph2, 'A', 'D')
assert dist4 == 6, f"FAIL: expected 6, got {dist4}"
print("All Dijkstra tests passed")
"""


def test_dijkstra() -> dict:
    content, elapsed, tokens = timed_completion(
        [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": (
                    "Implement Dijkstra's shortest path algorithm in Python. "
                    "Function signature: `def dijkstra(graph: dict[str, list[tuple[str, int]]], "
                    "start: str, end: str) -> tuple[int, list[str]]` where graph is adjacency list "
                    "with (neighbor, weight) tuples. Return (distance, path) or (-1, []) if unreachable."
                ),
            },
        ],
        max_tokens=2048,
    )
    code = extract_code_block(content, "python")
    score = score_code_runs(code, "python", test_code=_DIJKSTRA_ASSERTIONS)
    print_test_result("dijkstra", score, elapsed, tokens)
    return {"name": "dijkstra", "score": score, "latency": round(elapsed, 2), "tokens": tokens}


# ---------------------------------------------------------------------------
# Test 7: Generate Tests
# ---------------------------------------------------------------------------

_MERGE_INTERVALS_IMPL = """
def merge_intervals(intervals: list[tuple[int, int]]) -> list[tuple[int, int]]:
    if not intervals:
        return []
    sorted_intervals = sorted(intervals, key=lambda x: x[0])
    merged = [sorted_intervals[0]]
    for start, end in sorted_intervals[1:]:
        if start <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(merged[-1][1], end))
        else:
            merged.append((start, end))
    return merged
"""


def test_generate_tests() -> dict:
    content, elapsed, tokens = timed_completion(
        [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": (
                    "Here is a Python function. Write comprehensive pytest-style test functions for it. "
                    "Cover edge cases, boundary conditions, and error cases.\n\n"
                    "```python\n"
                    "def merge_intervals(intervals: list[tuple[int, int]]) -> list[tuple[int, int]]:\n"
                    "    if not intervals:\n"
                    "        return []\n"
                    "    sorted_intervals = sorted(intervals, key=lambda x: x[0])\n"
                    "    merged = [sorted_intervals[0]]\n"
                    "    for start, end in sorted_intervals[1:]:\n"
                    "        if start <= merged[-1][1]:\n"
                    "            merged[-1] = (merged[-1][0], max(merged[-1][1], end))\n"
                    "        else:\n"
                    "            merged.append((start, end))\n"
                    "    return merged\n"
                    "```"
                ),
            },
        ],
        max_tokens=2048,
    )
    test_code = extract_code_block(content, "python")
    # Prepend the implementation so test functions can call it, then run everything
    full_test_code = _MERGE_INTERVALS_IMPL + "\n" + test_code
    score = score_code_runs(full_test_code, "python")
    print_test_result("generate_tests", score, elapsed, tokens)
    return {
        "name": "generate_tests",
        "score": score,
        "latency": round(elapsed, 2),
        "tokens": tokens,
    }


# ---------------------------------------------------------------------------
# Test 8: Regex Engine
# ---------------------------------------------------------------------------

_REGEX_ASSERTIONS = """
assert match("a", "a") == True, "FAIL: literal"
assert match("a", "b") == False, "FAIL: literal mismatch"
assert match("a.c", "abc") == True, "FAIL: dot"
assert match("a.c", "aXc") == True, "FAIL: dot any"
assert match("a*", "") == True, "FAIL: star zero"
assert match("a*", "aaa") == True, "FAIL: star many"
assert match("a*b", "b") == True, "FAIL: star zero prefix"
assert match("a*b", "aaab") == True, "FAIL: star prefix"
assert match("a+", "") == False, "FAIL: plus zero"
assert match("a+", "a") == True, "FAIL: plus one"
assert match("a+", "aaa") == True, "FAIL: plus many"
assert match("a?b", "b") == True, "FAIL: question zero"
assert match("a?b", "ab") == True, "FAIL: question one"
assert match("a?b", "aab") == False, "FAIL: question two"
assert match(".*", "anything") == True, "FAIL: dot star"
print("All regex tests passed")
"""


def test_regex_engine() -> dict:
    content, elapsed, tokens = timed_completion(
        [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": (
                    "Implement a basic regex engine in Python. "
                    "Function signature: `def match(pattern: str, text: str) -> bool`. "
                    "Support these operators: `.` (any char), `*` (zero or more of previous), "
                    "`+` (one or more of previous), `?` (zero or one of previous). "
                    "Match must cover the entire string."
                ),
            },
        ],
        max_tokens=2048,
    )
    code = extract_code_block(content, "python")
    score = score_code_runs(code, "python", test_code=_REGEX_ASSERTIONS)
    print_test_result("regex_engine", score, elapsed, tokens)
    return {
        "name": "regex_engine",
        "score": score,
        "latency": round(elapsed, 2),
        "tokens": tokens,
    }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

_TESTS = [
    test_lru_cache,
    test_async_rate_limiter,
    test_typescript_generics,
    test_nix_derivation,
    test_csv_to_json_bash,
    test_dijkstra,
    test_generate_tests,
    test_regex_engine,
]


def main() -> None:
    print("=== Code Generation Benchmark ===\n")
    results: list[dict] = []

    for test_fn in _TESTS:
        try:
            result = test_fn()
        except Exception as exc:  # noqa: BLE001
            name = test_fn.__name__.removeprefix("test_")
            print(f"  [ERROR] {name}: {exc}")
            result = {"name": name, "score": 0.0, "latency": 0.0, "tokens": 0, "error": str(exc)}
        results.append(result)

    write_results("code_generation", results)

    # Summary
    scored = [r for r in results if not r.get("skipped") and not r.get("error")]
    skipped = sum(1 for r in results if r.get("skipped"))
    errors = sum(1 for r in results if r.get("error"))
    mean_score = sum(r["score"] for r in scored) / max(len(scored), 1)
    total_tokens = sum(r.get("tokens", 0) for r in results)
    total_latency = sum(r.get("latency", 0.0) for r in results)

    print(f"\n--- Summary ---")
    print(f"  Tests run:    {len(_TESTS)}")
    print(f"  Scored:       {len(scored)}")
    print(f"  Skipped:      {skipped}")
    print(f"  Errors:       {errors}")
    print(f"  Mean score:   {mean_score:.3f}")
    print(f"  Total tokens: {total_tokens}")
    print(f"  Total time:   {total_latency:.1f}s")


if __name__ == "__main__":
    main()
