"""Shared infrastructure for MLX vs Claude Opus 4.6 benchmark suite."""

import json
import os
import re
import subprocess
import tempfile
import time
from pathlib import Path

from openai import OpenAI

RESULTS_DIR = Path(os.environ.get("BENCHMARK_RESULTS_DIR", "/tmp/mlx-benchmark-results"))
RESULTS_DIR.mkdir(parents=True, exist_ok=True)

API_URL = os.environ.get("MLX_API_URL", "http://127.0.0.1:11434/v1")
MODEL = os.environ.get("MLX_DEFAULT_MODEL", "mlx-community/Qwen3.5-122B-A10B-4bit")
DEFAULT_TEMPERATURE = 0
DEFAULT_MAX_TOKENS = 2048


def get_client() -> OpenAI:
    return OpenAI(base_url=API_URL, api_key="EMPTY")


def get_model() -> str:
    return MODEL


def timed_completion(
    messages: list[dict],
    max_tokens: int = DEFAULT_MAX_TOKENS,
    temperature: float = DEFAULT_TEMPERATURE,
    **kwargs,
) -> tuple[str, float, int]:
    """Send a chat completion and return (content, elapsed_seconds, completion_tokens)."""
    client = get_client()
    start = time.time()
    response = client.chat.completions.create(
        model=get_model(),
        messages=messages,
        max_tokens=max_tokens,
        temperature=temperature,
        **kwargs,
    )
    elapsed = time.time() - start
    content = response.choices[0].message.content or ""
    tokens = response.usage.completion_tokens if response.usage else 0
    return content, elapsed, tokens


def timed_tool_loop(
    messages: list[dict],
    tools: list[dict],
    tool_executor: callable,
    max_steps: int = 10,
    max_tokens: int = DEFAULT_MAX_TOKENS,
    temperature: float = DEFAULT_TEMPERATURE,
) -> dict:
    """Run a multi-step tool calling loop. Returns full trace."""
    client = get_client()
    tool_calls_made = []
    total_tokens = 0
    start = time.time()

    for step in range(max_steps):
        response = client.chat.completions.create(
            model=get_model(),
            messages=messages,
            tools=tools,
            tool_choice="auto",
            max_tokens=max_tokens,
            temperature=temperature,
        )
        msg = response.choices[0].message
        total_tokens += response.usage.completion_tokens if response.usage else 0

        if msg.tool_calls:
            messages.append(msg)
            for tc in msg.tool_calls:
                result = tool_executor(tc.function.name, tc.function.arguments)
                tool_calls_made.append({
                    "step": step + 1,
                    "tool": tc.function.name,
                    "args": tc.function.arguments,
                    "result_preview": str(result)[:200],
                })
                messages.append({"role": "tool", "tool_call_id": tc.id, "content": str(result)})
        else:
            elapsed = time.time() - start
            return {
                "answer": msg.content[:500] if msg.content else "(empty)",
                "tool_calls": tool_calls_made,
                "tokens": total_tokens,
                "latency": round(elapsed, 2),
                "steps": step + 1,
            }

    elapsed = time.time() - start
    return {
        "answer": "(max steps reached)",
        "tool_calls": tool_calls_made,
        "tokens": total_tokens,
        "latency": round(elapsed, 2),
        "steps": max_steps,
    }


# --- Scoring functions ---


def score_exact(expected: str | int | float, actual: str, tolerance: float = 0.0) -> float:
    """1.0 if actual contains the expected value (with optional numeric tolerance)."""
    if isinstance(expected, (int, float)):
        numbers = re.findall(r"-?\d+\.?\d*", actual)
        for n in numbers:
            if abs(float(n) - float(expected)) <= tolerance:
                return 1.0
        return 0.0
    return 1.0 if str(expected).lower() in actual.lower() else 0.0


def score_contains_all(required: list[str], text: str) -> float:
    """Fraction of required items found in text (case-insensitive)."""
    if not required:
        return 1.0
    text_lower = text.lower()
    found = sum(1 for item in required if item.lower() in text_lower)
    return found / len(required)


def score_json_valid(text: str) -> tuple[float, dict | list | None]:
    """Extract and parse JSON from text. Returns (score, parsed_obj)."""
    json_match = re.search(r"```(?:json)?\s*([\s\S]*?)```", text)
    json_str = json_match.group(1).strip() if json_match else text.strip()

    if json_str.startswith("```"):
        json_str = json_str.split("```")[1] if "```" in json_str[3:] else json_str[3:]
        json_str = json_str.strip()

    try:
        obj = json.loads(json_str)
        return 1.0, obj
    except (json.JSONDecodeError, ValueError):
        lines = json_str.split("\n")
        for i in range(len(lines)):
            for j in range(len(lines), i, -1):
                candidate = "\n".join(lines[i:j])
                try:
                    obj = json.loads(candidate)
                    return 0.8, obj
                except (json.JSONDecodeError, ValueError):
                    continue
        return 0.0, None


def score_json_schema(schema: dict, text: str) -> float:
    """Validate extracted JSON against a JSON Schema. Returns 1.0/0.0."""
    import jsonschema

    parse_score, obj = score_json_valid(text)
    if obj is None:
        return 0.0
    try:
        jsonschema.validate(instance=obj, schema=schema)
        return parse_score
    except jsonschema.ValidationError:
        return 0.0


def score_code_runs(code: str, language: str = "python", test_code: str | None = None) -> float:
    """Execute code in a subprocess. Returns fraction of tests passed."""
    if language == "python":
        full_code = code
        if test_code:
            full_code = code + "\n\n" + test_code
        with tempfile.NamedTemporaryFile(mode="w", suffix=".py", delete=False) as f:
            f.write(full_code)
            f.flush()
            try:
                result = subprocess.run(
                    ["python3", f.name],
                    capture_output=True,
                    text=True,
                    timeout=30,
                )
                if result.returncode == 0:
                    return 1.0
                output = result.stdout + result.stderr
                passed = len(re.findall(r"PASS", output))
                failed = len(re.findall(r"FAIL|Error|Traceback", output))
                if passed + failed > 0:
                    return passed / (passed + failed)
                return 0.0
            except subprocess.TimeoutExpired:
                return 0.0
            finally:
                os.unlink(f.name)
    elif language == "bash":
        with tempfile.NamedTemporaryFile(mode="w", suffix=".sh", delete=False) as f:
            f.write(code)
            f.flush()
            try:
                result = subprocess.run(
                    ["bash", "-n", f.name],
                    capture_output=True,
                    text=True,
                    timeout=10,
                )
                if result.returncode != 0:
                    return 0.0
                if test_code:
                    result = subprocess.run(
                        ["bash", f.name],
                        input=test_code,
                        capture_output=True,
                        text=True,
                        timeout=30,
                    )
                    return 1.0 if result.returncode == 0 else 0.0
                return 1.0
            except subprocess.TimeoutExpired:
                return 0.0
            finally:
                os.unlink(f.name)
    elif language == "typescript":
        try:
            subprocess.run(["npx", "--version"], capture_output=True, timeout=5)
        except (FileNotFoundError, subprocess.TimeoutExpired):
            return -1.0  # skip — toolchain not available
        with tempfile.NamedTemporaryFile(mode="w", suffix=".ts", delete=False) as f:
            f.write(code)
            f.flush()
            try:
                result = subprocess.run(
                    ["npx", "tsc", "--noEmit", "--strict", "--target", "ES2020", f.name],
                    capture_output=True,
                    text=True,
                    timeout=30,
                )
                return 1.0 if result.returncode == 0 else 0.0
            except subprocess.TimeoutExpired:
                return 0.0
            finally:
                os.unlink(f.name)
    elif language == "nix":
        try:
            subprocess.run(["nix-instantiate", "--version"], capture_output=True, timeout=5)
        except (FileNotFoundError, subprocess.TimeoutExpired):
            return -1.0  # skip — toolchain not available
        with tempfile.NamedTemporaryFile(mode="w", suffix=".nix", delete=False) as f:
            f.write(code)
            f.flush()
            try:
                result = subprocess.run(
                    ["nix-instantiate", "--parse", f.name],
                    capture_output=True,
                    text=True,
                    timeout=10,
                )
                return 1.0 if result.returncode == 0 else 0.0
            except subprocess.TimeoutExpired:
                return 0.0
            finally:
                os.unlink(f.name)
    return 0.0


def extract_code_block(text: str, language: str = "") -> str:
    """Extract the first code block from model response."""
    patterns = [
        rf"```{language}\s*\n([\s\S]*?)```",
        r"```\s*\n([\s\S]*?)```",
    ]
    for pattern in patterns:
        match = re.search(pattern, text)
        if match:
            return match.group(1).strip()
    return text.strip()


# --- Result I/O ---


def write_results(category: str, results: list[dict]) -> None:
    """Write test results to JSON file in CI-compatible format."""
    output = {
        "category": category,
        "model": get_model(),
        "api_url": API_URL,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "tests": results,
        "summary": {
            "total": len(results),
            "scores": [r.get("score", 0) for r in results],
            "mean_score": sum(r.get("score", 0) for r in results) / max(len(results), 1),
            "total_tokens": sum(r.get("tokens", 0) for r in results),
            "total_latency": sum(r.get("latency", 0) for r in results),
        },
        # CI-compatible result items (aligned with data/benchmarks/schema.json)
        "results": [
            {
                "name": r["name"],
                "metric": "score",
                "value": r.get("score", 0),
                "unit": "ratio",
                "tags": {"category": category},
            }
            for r in results
        ],
    }
    path = RESULTS_DIR / f"{category}.json"
    path.write_text(json.dumps(output, indent=2))
    print(f"  Results written to {path}")


# --- Claude Opus 4.6 Baselines ---
# Hardcoded expected performance based on known capabilities.
# These are NOT measured in this suite — they represent what we'd expect from Claude.

CLAUDE_BASELINES = {
    "reasoning": {
        "mean_score": 0.95,
        "per_test": {
            "bird_train": 1.0,
            "constraint_satisfaction": 1.0,
            "syllogism": 1.0,
            "bayes_theorem": 1.0,
            "counterfactual": 1.0,
            "missionaries_cannibals": 1.0,
            "chinese_remainder": 1.0,
            "temporal_reasoning": 1.0,
            "multi_hop": 0.9,
            "floating_point": 1.0,
        },
    },
    "code_generation": {
        "mean_score": 0.95,
        "per_test": {
            "lru_cache": 1.0,
            "async_rate_limiter": 1.0,
            "typescript_generics": 1.0,
            "nix_derivation": 0.9,
            "csv_to_json_bash": 1.0,
            "dijkstra": 1.0,
            "generate_tests": 0.9,
            "regex_engine": 0.8,
        },
    },
    "code_review": {
        "mean_score": 0.92,
        "per_test": {
            "auth_bypass": 0.95,
            "race_condition": 0.90,
            "memory_leak": 0.95,
            "subtle_off_by_one": 0.85,
            "type_coercion": 0.95,
            "clean_code": 0.90,
        },
    },
    "tool_use": {
        "mean_score": 0.96,
        "per_test": {
            "config_port_check": 1.0,
            "grep_count_write": 1.0,
            "csv_error_recovery": 0.9,
            "api_error_recovery": 0.9,
            "refactor_chain": 1.0,
        },
    },
    "instruction_following": {
        "mean_score": 0.83,
        "per_test": {
            "lipogram": 0.9,
            "persona": 1.0,
            "yaml_only": 1.0,
            "word_count": 0.5,
            "numbered_steps": 1.0,
            "multi_constraint": 1.0,
        },
    },
    "structured_output": {
        "mean_score": 0.95,
        "per_test": {
            "flat_object": 1.0,
            "nested_object": 1.0,
            "array_of_objects": 1.0,
            "enum_fields": 1.0,
            "optional_required": 0.9,
            "recursive_structure": 0.8,
            "api_response": 0.9,
            "conflicting_instructions": 1.0,
        },
    },
    "long_context": {
        "mean_score": 0.975,
        "per_test": {
            "needle_2k": 1.0,
            "synthesis_8k": 1.0,
            "needle_16k": 1.0,
            "multi_needle_32k": 0.9,
        },
    },
    "conversation": {
        "mean_score": 0.975,
        "per_test": {
            "pronoun_resolution": 1.0,
            "running_counter": 1.0,
            "preference_memory": 1.0,
            "contradiction_detection": 0.9,
        },
    },
}

VERDICT_THRESHOLDS = {
    "ACCEPTABLE": 0.10,
    "MINOR GAP": 0.25,
    "SHORTCOMING": float("inf"),
}


def get_verdict(mlx_score: float, claude_score: float) -> str:
    """Classify the gap between MLX and Claude scores."""
    if claude_score == 0:
        return "ACCEPTABLE"
    gap = (claude_score - mlx_score) / claude_score
    if gap < VERDICT_THRESHOLDS["ACCEPTABLE"]:
        return "ACCEPTABLE"
    if gap < VERDICT_THRESHOLDS["MINOR GAP"]:
        return "MINOR GAP"
    return "SHORTCOMING"


def print_test_result(name: str, score: float, elapsed: float, tokens: int) -> None:
    """Print a single test result line."""
    status = "PASS" if score >= 0.8 else "PARTIAL" if score > 0 else "FAIL"
    print(f"  [{status}] {name}: {score:.2f} ({elapsed:.1f}s, {tokens} tok)")
