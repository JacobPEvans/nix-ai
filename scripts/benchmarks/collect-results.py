#!/usr/bin/env python3
# /// script
# dependencies = ["jsonschema>=4.0"]
# ///
"""Collect benchmark results for a single suite and write a schema-conforming JSON file.

Usage:
  uv run scripts/benchmarks/collect-results.py --suite throughput
  uv run scripts/benchmarks/collect-results.py --suite throughput --model mlx-community/gemma-4-31b-it-4bit
  uv run scripts/benchmarks/collect-results.py --suite framework-eval --dry-run

Suites:
  throughput            Token generation speed at various output lengths
  ttft                  Time-to-first-token (cold vs warm)
  tool-calling          Tool selection accuracy with function calling
  code-accuracy         Code planning and bug detection accuracy
  framework-eval        Agent framework comparison (LangGraph, Qwen-Agent, etc.)
  capability-comparison Full capability suite vs Claude baselines
  coding                Code generation (HumanEval via lm-eval)
  reasoning             Math and logical reasoning (GSM8K, HellaSwag, ARC)
  knowledge             Knowledge breadth and instruction following (MMLU, IFEval)

Output:
  Writes data/benchmarks/{timestamp}-{sha7}-{suite}.json and prints JSON to stdout.
  On dry-run: builds a synthetic result and validates it without running inference.
"""

import argparse
import importlib.metadata
import json
import os
import re
import subprocess
import sys
import time
from datetime import UTC, datetime
from pathlib import Path

import jsonschema

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCHEMA_PATH = REPO_ROOT / "data" / "benchmarks" / "schema.json"
AGENT_SCRIPTS_DIR = REPO_ROOT / "orchestrator" / "examples" / "evaluations"
BENCHMARKS_DIR = REPO_ROOT / "mlx-server" / "benchmarks"
MLX_API_URL = os.environ.get("MLX_API_URL", "http://127.0.0.1:11434/v1")
SCHEMA_VERSION = "1"

ALL_SUITES = [
    "throughput", "ttft", "tool-calling", "code-accuracy",
    "framework-eval", "capability-comparison",
    "coding", "reasoning", "knowledge",
]

INFERENCE_SUITES = {
    "throughput", "ttft", "tool-calling", "code-accuracy",
    "coding", "reasoning", "knowledge",
}

FRAMEWORK_SCRIPTS = [
    ("eval_langgraph.py", "langgraph"),
    ("eval_qwen_agent.py", "qwen-agent"),
    ("eval_smolagents.py", "smolagents"),
    ("eval_google_adk.py", "google-adk"),
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _run(cmd: list[str], default: str = "unknown") -> str:
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return default


def _curl_ttft(url: str, model: str, prompt: str, max_time: int = 30) -> float | None:
    """Send a chat completion request and return wall-clock time in seconds."""
    payload = json.dumps({
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": 1,
        "temperature": 0,
    })
    try:
        proc = subprocess.run(
            ["curl", "-s", f"{url}/chat/completions",
             "-H", "Content-Type: application/json",
             "-d", payload,
             "-o", "/dev/null",
             "-w", "%{time_total}",
             "--max-time", str(max_time)],
            capture_output=True, text=True, timeout=max_time + 5,
        )
        if proc.returncode == 0:
            return float(proc.stdout.strip())
    except (subprocess.TimeoutExpired, ValueError, FileNotFoundError):
        pass
    return None


def _chat_completion(url: str, model: str, messages: list, tools: list | None = None,
                     max_tokens: int = 256, temperature: float = 0) -> dict | None:
    """Send a chat completion request and return the parsed JSON response."""
    payload: dict = {
        "model": model,
        "messages": messages,
        "max_tokens": max_tokens,
        "temperature": temperature,
    }
    if tools:
        payload["tools"] = tools
    try:
        proc = subprocess.run(
            ["curl", "-sf", f"{url}/chat/completions",
             "-H", "Content-Type: application/json",
             "-d", json.dumps(payload),
             "--max-time", "120"],
            capture_output=True, text=True, timeout=130,
        )
        if proc.returncode == 0:
            return json.loads(proc.stdout)
    except (subprocess.TimeoutExpired, json.JSONDecodeError, FileNotFoundError):
        pass
    return None


# ---------------------------------------------------------------------------
# System info
# ---------------------------------------------------------------------------

def collect_system_info() -> dict:
    os_version = _run(["sw_vers", "-productVersion"])
    if os_version != "unknown":
        os_str = f"macOS {os_version}"
    else:
        os_str = _run(["uname", "-s"], "unknown")

    chip = _run(["sysctl", "-n", "machdep.cpu.brand_string"])
    if chip == "unknown":
        chip = _run(["uname", "-m"], "unknown")

    mem_bytes_str = _run(["sysctl", "-n", "hw.memsize"])
    try:
        memory_gb = int(mem_bytes_str) // (1024 ** 3)
    except ValueError:
        memory_gb = 0

    try:
        vllm_version = importlib.metadata.version("vllm-mlx")
    except importlib.metadata.PackageNotFoundError:
        vllm_version = "unknown"

    runner = os.environ.get("RUNNER_NAME", "local")

    return {
        "os": os_str,
        "chip": chip,
        "memory_gb": memory_gb,
        "vllm_mlx_version": vllm_version,
        "runner": runner,
    }


def get_git_sha() -> str:
    sha = _run(["git", "rev-parse", "--short", "HEAD"])
    if sha == "unknown":
        sha = os.environ.get("GITHUB_SHA", "unknown")[:7]
    return sha


def get_trigger() -> str:
    event = os.environ.get("GITHUB_EVENT_NAME", "")
    if event == "pull_request":
        return "pr"
    if event == "schedule":
        return "schedule"
    if event == "workflow_dispatch":
        return "workflow_dispatch"
    # Local runs (no GITHUB_EVENT_NAME set)
    return "local"


def get_pr_number() -> int | None:
    val = os.environ.get("GITHUB_REF", "")
    match = re.match(r"refs/pull/(\d+)/merge", val)
    if match:
        return int(match.group(1))
    return None


# ---------------------------------------------------------------------------
# MLX server health check
# ---------------------------------------------------------------------------

def mlx_server_available() -> bool:
    try:
        result = subprocess.run(
            ["curl", "-sf", f"{MLX_API_URL}/models"],
            capture_output=True,
            timeout=5,
        )
        return result.returncode == 0
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False


# ---------------------------------------------------------------------------
# Suite runners
# ---------------------------------------------------------------------------

def run_throughput_suite(model: str) -> tuple[list[dict], list[str]]:
    """Measure token generation throughput at various output lengths."""
    results = []
    errors = []

    test_configs = [
        ("short-50", 50),
        ("medium-256", 256),
        ("long-512", 512),
        ("long-1024", 1024),
    ]

    for name, max_tokens in test_configs:
        prompt = "Write a detailed explanation of how neural networks work, covering architecture, training, and applications."
        payload = json.dumps({
            "model": model,
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": max_tokens,
            "temperature": 0.7,
        })
        try:
            start = time.monotonic()
            proc = subprocess.run(
                ["curl", "-sf", f"{MLX_API_URL}/chat/completions",
                 "-H", "Content-Type: application/json",
                 "-d", payload,
                 "--max-time", "300"],
                capture_output=True, text=True, timeout=310,
            )
            elapsed = time.monotonic() - start

            if proc.returncode != 0:
                errors.append(f"throughput/{name}: curl failed (exit {proc.returncode})")
                continue

            resp = json.loads(proc.stdout)
            usage = resp.get("usage", {})
            completion_tokens = usage.get("completion_tokens", 0)

            if completion_tokens > 0 and elapsed > 0:
                tok_s = completion_tokens / elapsed
                results.append({
                    "name": name,
                    "metric": "throughput",
                    "value": round(tok_s, 1),
                    "unit": "tok/s",
                    "tags": {
                        "max_tokens": str(max_tokens),
                        "completion_tokens": str(completion_tokens),
                        "elapsed_s": f"{elapsed:.2f}",
                    },
                })
            else:
                errors.append(f"throughput/{name}: no completion tokens returned")

        except (subprocess.TimeoutExpired, json.JSONDecodeError) as e:
            errors.append(f"throughput/{name}: {e}")

    return results, errors


def run_ttft_suite(model: str) -> tuple[list[dict], list[str]]:
    """Measure time-to-first-token (cold vs warm)."""
    results = []
    errors = []

    cold_prompts = [
        "What is the capital of France?",
        "Explain quantum entanglement briefly.",
        "List three benefits of exercise.",
    ]
    warm_prompt = "Hello, how are you?"

    # Cold TTFT (3 unique prompts — no prefix cache hits)
    cold_times = []
    for prompt in cold_prompts:
        t = _curl_ttft(MLX_API_URL, model, prompt)
        if t is not None:
            cold_times.append(t)
        else:
            errors.append(f"ttft/cold: failed for prompt '{prompt[:30]}...'")

    if cold_times:
        avg_cold = sum(cold_times) / len(cold_times)
        results.append({
            "name": "cold-avg",
            "metric": "ttft",
            "value": round(avg_cold, 4),
            "unit": "seconds",
            "tags": {"type": "cold", "samples": str(len(cold_times))},
        })

    # Warm TTFT (same prompt 3 times — prefix cache should help)
    warm_times = []
    for _ in range(3):
        t = _curl_ttft(MLX_API_URL, model, warm_prompt)
        if t is not None:
            warm_times.append(t)
        else:
            errors.append("ttft/warm: failed")

    if warm_times:
        avg_warm = sum(warm_times) / len(warm_times)
        results.append({
            "name": "warm-avg",
            "metric": "ttft",
            "value": round(avg_warm, 4),
            "unit": "seconds",
            "tags": {"type": "warm", "samples": str(len(warm_times))},
        })

    # Cache speedup ratio
    if cold_times and warm_times:
        avg_cold = sum(cold_times) / len(cold_times)
        avg_warm = sum(warm_times) / len(warm_times)
        speedup = avg_cold / avg_warm if avg_warm > 0 else 0
        results.append({
            "name": "cache-speedup",
            "metric": "ratio",
            "value": round(speedup, 2),
            "unit": "x",
            "tags": {"cold_avg": f"{avg_cold:.4f}", "warm_avg": f"{avg_warm:.4f}"},
        })

    return results, errors


def run_tool_calling_suite(model: str) -> tuple[list[dict], list[str]]:
    """Test tool selection accuracy with function calling."""
    results = []
    errors = []

    tools = [{
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "Get the current weather for a location",
            "parameters": {
                "type": "object",
                "properties": {
                    "location": {"type": "string", "description": "City name"},
                    "unit": {"type": "string", "enum": ["celsius", "fahrenheit"]},
                },
                "required": ["location"],
            },
        },
    }]

    test_cases = [
        {
            "name": "should-call-tool",
            "messages": [{"role": "user", "content": "What's the weather in San Francisco?"}],
            "expect_tool": True,
            "expect_function": "get_weather",
        },
        {
            "name": "both-args",
            "messages": [{"role": "user", "content": "What's the weather in Tokyo in celsius?"}],
            "expect_tool": True,
            "expect_function": "get_weather",
        },
        {
            "name": "no-tool-needed",
            "messages": [{"role": "user", "content": "What is 2 + 2?"}],
            "expect_tool": False,
            "expect_function": None,
        },
        {
            "name": "ambiguous-no-tool",
            "messages": [{"role": "user", "content": "Tell me about climate change."}],
            "expect_tool": False,
            "expect_function": None,
        },
    ]

    for tc in test_cases:
        start = time.monotonic()
        resp = _chat_completion(MLX_API_URL, model, tc["messages"], tools=tools)
        elapsed = time.monotonic() - start

        if resp is None:
            errors.append(f"tool-calling/{tc['name']}: request failed")
            continue

        choices = resp.get("choices", [])
        if not choices:
            errors.append(f"tool-calling/{tc['name']}: no choices in response")
            continue

        message = choices[0].get("message", {})
        tool_calls = message.get("tool_calls", [])
        called_tool = len(tool_calls) > 0

        correct = called_tool == tc["expect_tool"]
        if tc["expect_function"] and tool_calls:
            called_fn = tool_calls[0].get("function", {}).get("name", "")
            correct = correct and called_fn == tc["expect_function"]

        results.append({
            "name": tc["name"],
            "metric": "accuracy",
            "value": 1.0 if correct else 0.0,
            "unit": "bool",
            "tags": {
                "expect_tool": str(tc["expect_tool"]),
                "called_tool": str(called_tool),
                "elapsed_s": f"{elapsed:.2f}",
            },
        })

    return results, errors


def run_code_accuracy_suite(model: str) -> tuple[list[dict], list[str]]:
    """Test code planning and bug detection accuracy."""
    results = []
    errors = []

    # Test 1: Bug detection (planted bugs in code snippet)
    buggy_code = '''
def process_items(items):
    """Process a list of items and return their sum."""
    total = 0
    for i in range(1, len(items)):  # Bug: off-by-one, skips first item
        total += items[i]

    query = f"SELECT * FROM users WHERE name = '{items[0]}'"  # Bug: SQL injection

    result = items[0].upper()  # Bug: no null check, crashes if items is empty

    return total
'''
    resp = _chat_completion(
        MLX_API_URL, model,
        [{"role": "user", "content": f"Review this Python code for bugs. List each bug found:\n```python\n{buggy_code}\n```"}],
        max_tokens=512,
    )
    if resp:
        content = resp.get("choices", [{}])[0].get("message", {}).get("content", "").lower()
        bugs_found = 0
        if "off-by-one" in content or "range(1" in content or "skip" in content or "index 0" in content:
            bugs_found += 1
        if "sql injection" in content or "sql" in content or "f-string" in content or "parameterized" in content:
            bugs_found += 1
        if "null" in content or "none" in content or "empty" in content or "check" in content:
            bugs_found += 1

        results.append({
            "name": "bug-detection",
            "metric": "accuracy",
            "value": round(bugs_found / 3, 2),
            "unit": "ratio",
            "tags": {"bugs_planted": "3", "bugs_found": str(bugs_found)},
        })
    else:
        errors.append("code-accuracy/bug-detection: request failed")

    # Test 2: Code planning (tool selection accuracy)
    planning_tools = [
        {"type": "function", "function": {"name": "file_read", "description": "Read contents of a file", "parameters": {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]}}},
        {"type": "function", "function": {"name": "file_write", "description": "Write contents to a file", "parameters": {"type": "object", "properties": {"path": {"type": "string"}, "content": {"type": "string"}}, "required": ["path", "content"]}}},
        {"type": "function", "function": {"name": "bash_exec", "description": "Execute a bash command", "parameters": {"type": "object", "properties": {"command": {"type": "string"}}, "required": ["command"]}}},
        {"type": "function", "function": {"name": "grep_search", "description": "Search for pattern in files", "parameters": {"type": "object", "properties": {"pattern": {"type": "string"}, "path": {"type": "string"}}, "required": ["pattern"]}}},
    ]

    planning_tests = [
        ("Add input validation to auth.py", "file_read"),
        ("Create a new config.yaml file with default settings", "file_write"),
        ("Run the test suite", "bash_exec"),
    ]

    correct_plans = 0
    for task, expected_tool in planning_tests:
        resp = _chat_completion(
            MLX_API_URL, model,
            [{"role": "user", "content": f"You need to: {task}. What's the first tool you'd use?"}],
            tools=planning_tools, max_tokens=128,
        )
        if resp:
            choices = resp.get("choices", [{}])
            message = choices[0].get("message", {}) if choices else {}
            tool_calls = message.get("tool_calls", [])
            if tool_calls:
                called_fn = tool_calls[0].get("function", {}).get("name", "")
                if called_fn == expected_tool:
                    correct_plans += 1
                elif expected_tool == "file_read" and called_fn in ("grep_search", "file_read"):
                    correct_plans += 1  # Read-before-edit is also acceptable

    results.append({
        "name": "code-planning",
        "metric": "accuracy",
        "value": round(correct_plans / len(planning_tests), 2),
        "unit": "ratio",
        "tags": {"correct": str(correct_plans), "total": str(len(planning_tests))},
    })

    return results, errors


def run_lm_eval_suite(model: str, tasks: list[tuple[str, int]]) -> tuple[list[dict], list[str]]:
    """Run lm-eval harness tasks and return results.

    Args:
        model: HuggingFace model ID
        tasks: List of (task_name, limit) tuples
    """
    results = []
    errors_list = []

    for task_name, limit in tasks:
        try:
            proc = subprocess.run(
                ["mlx-eval",
                 "--tasks", task_name,
                 "--limit", str(limit),
                 "--log_samples",
                 "--output_path", f"/tmp/mlx-eval-{task_name}"],
                capture_output=True, text=True,
                timeout=1800,  # 30 min per task
                env={**os.environ, "MLX_DEFAULT_MODEL": model},
            )
        except subprocess.TimeoutExpired:
            errors_list.append(f"lm-eval/{task_name}: timed out after 30 min")
            continue
        except FileNotFoundError:
            errors_list.append(f"lm-eval/{task_name}: mlx-eval not found")
            continue

        if proc.returncode != 0:
            errors_list.append(f"lm-eval/{task_name}: exited {proc.returncode}: {proc.stderr[:200]}")
            continue

        # Parse lm-eval output from results JSON
        results_dir = Path(f"/tmp/mlx-eval-{task_name}")
        result_files = sorted(results_dir.glob("**/results.json")) if results_dir.exists() else []

        if not result_files:
            # Try parsing from stdout — lm-eval prints a summary table
            errors_list.append(f"lm-eval/{task_name}: no results.json found; check output")
            continue

        try:
            result_data = json.loads(result_files[-1].read_text())
            task_results = result_data.get("results", {})

            for task_key, metrics in task_results.items():
                # lm-eval uses various metric names: acc, acc_norm, exact_match, pass@1, etc.
                for metric_name in ("acc,none", "acc_norm,none", "exact_match,none",
                                    "pass@1,none", "acc", "acc_norm", "exact_match"):
                    if metric_name in metrics:
                        score = metrics[metric_name]
                        results.append({
                            "name": task_key,
                            "metric": metric_name.split(",")[0],
                            "value": round(float(score), 4),
                            "unit": "ratio",
                            "tags": {"task": task_name, "limit": str(limit)},
                        })
                        break

        except (json.JSONDecodeError, OSError) as e:
            errors_list.append(f"lm-eval/{task_name}: could not parse results: {e}")

    return results, errors_list


def run_coding_suite(model: str) -> tuple[list[dict], list[str]]:
    """Code generation benchmark via lm-eval HumanEval."""
    return run_lm_eval_suite(model, [("humaneval", 164)])


def run_reasoning_suite(model: str) -> tuple[list[dict], list[str]]:
    """Math and logical reasoning benchmarks."""
    return run_lm_eval_suite(model, [
        ("gsm8k", 200),
        ("hellaswag", 200),
        ("arc_challenge", 200),
    ])


def run_knowledge_suite(model: str) -> tuple[list[dict], list[str]]:
    """Knowledge breadth and instruction following benchmarks."""
    return run_lm_eval_suite(model, [
        ("mmlu", 200),
        ("ifeval", 100),
    ])


def run_framework_suite() -> tuple[list[dict], list[str]]:
    """Run 4 agent framework benchmark scripts and normalise their JSON output."""
    results = []
    errors = []

    for script_name, slug in FRAMEWORK_SCRIPTS:
        script_path = AGENT_SCRIPTS_DIR / script_name
        if not script_path.exists():
            errors.append(f"{script_name}: not found at {script_path}")
            continue

        try:
            proc = subprocess.run(
                ["uv", "run", str(script_path)],
                capture_output=True,
                text=True,
                timeout=120,
                cwd=str(REPO_ROOT),
            )
        except subprocess.TimeoutExpired:
            errors.append(f"{script_name}: timed out after 120s")
            continue
        except FileNotFoundError:
            errors.append(f"{script_name}: uv not found")
            continue

        if proc.returncode != 0:
            errors.append(f"{script_name}: exited {proc.returncode}: {proc.stderr[:200]}")
            continue

        try:
            raw = json.loads(proc.stdout)
        except json.JSONDecodeError as e:
            errors.append(f"{script_name}: invalid JSON output: {e}")
            continue

        latency = float(raw.get("latency", 0))
        tags: dict[str, str] = {
            "framework": str(raw.get("framework", slug)),
        }
        if "tokens" in raw:
            tags["tokens"] = str(raw["tokens"])
        if "steps" in raw:
            tags["steps"] = str(raw["steps"])
        if "tool_calls" in raw:
            tags["tool_calls"] = str(len(raw["tool_calls"]))

        results.append({
            "name": slug,
            "metric": "latency",
            "value": latency,
            "unit": "seconds",
            "tags": tags,
            "raw": raw,
        })

    return results, errors


def run_capability_suite() -> tuple[list[dict], list[str]]:
    """Run mlx-server/benchmarks/run_all.sh and collect per-category JSON results."""
    results = []
    errors = []
    results_dir = Path("/tmp/mlx-benchmark-results")

    run_script = BENCHMARKS_DIR / "run_all.sh"
    if not run_script.exists():
        errors.append(
            f"run_all.sh not found at {run_script} — "
            "capability-comparison suite not yet implemented"
        )
        return results, errors

    try:
        subprocess.run(
            ["bash", str(run_script)],
            timeout=4200,  # 70 minutes
            cwd=str(BENCHMARKS_DIR),
            check=True,
        )
    except subprocess.TimeoutExpired:
        errors.append("run_all.sh timed out after 70 minutes")
        return results, errors
    except subprocess.CalledProcessError as e:
        errors.append(f"run_all.sh failed with exit code {e.returncode}")
        return results, errors

    for json_path in sorted(results_dir.glob("*.json")):
        if json_path.name == "report.json":
            continue
        try:
            category_data = json.loads(json_path.read_text())
        except (json.JSONDecodeError, OSError) as e:
            errors.append(f"{json_path.name}: could not read: {e}")
            continue

        category = json_path.stem
        score = category_data.get("score") or category_data.get("summary", {}).get("mean_score", 0)
        baseline = category_data.get("claude_baseline")

        tags: dict[str, str] = {"category": category}
        if baseline is not None:
            tags["claude_baseline"] = str(baseline)
            gap_pct = round((baseline - score) / baseline * 100, 1) if baseline > 0 else 0
            tags["gap_pct"] = str(gap_pct)

        results.append({
            "name": category,
            "metric": "score",
            "value": float(score),
            "unit": "ratio",
            "tags": tags,
            "raw": category_data,
        })

    return results, errors


# ---------------------------------------------------------------------------
# Suite dispatcher
# ---------------------------------------------------------------------------

SUITE_RUNNERS: dict[str, ...] = {
    "throughput": lambda m: run_throughput_suite(m),
    "ttft": lambda m: run_ttft_suite(m),
    "tool-calling": lambda m: run_tool_calling_suite(m),
    "code-accuracy": lambda m: run_code_accuracy_suite(m),
    "coding": lambda m: run_coding_suite(m),
    "reasoning": lambda m: run_reasoning_suite(m),
    "knowledge": lambda m: run_knowledge_suite(m),
    "framework-eval": lambda _m: run_framework_suite(),
    "capability-comparison": lambda _m: run_capability_suite(),
}


# ---------------------------------------------------------------------------
# Dry-run mock
# ---------------------------------------------------------------------------

def build_dry_run_result(suite: str, system: dict, git_sha: str) -> dict:
    return {
        "schema_version": SCHEMA_VERSION,
        "timestamp": datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "git_sha": git_sha,
        "trigger": get_trigger(),
        "pr_number": get_pr_number(),
        "suite": suite,
        "model": "dry-run-model",
        "skipped": False,
        "system": system,
        "results": [
            {
                "name": "dry-run",
                "metric": "latency",
                "value": 0.001,
                "unit": "seconds",
                "tags": {"mode": "dry-run"},
                "raw": None,
            }
        ],
        "memory_snapshots": [],
        "errors": [],
    }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description="Collect benchmark results")
    parser.add_argument("--suite", required=True, choices=ALL_SUITES)
    parser.add_argument("--model", default=None,
                        help="Model ID (overrides MLX_DEFAULT_MODEL)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Build mock result without running inference")
    args = parser.parse_args()

    model = args.model or os.environ.get("MLX_DEFAULT_MODEL", "mlx-community/Qwen3.5-27B-4bit")

    schema = json.loads(SCHEMA_PATH.read_text())
    now = datetime.now(UTC)
    timestamp = now.strftime("%Y-%m-%dT%H:%M:%SZ")   # RFC 3339 for JSON body
    filename_ts = now.strftime("%Y-%m-%dT%H%M%SZ")    # compact (no colons) for filename
    git_sha = get_git_sha()
    system = collect_system_info()

    if args.dry_run:
        result = build_dry_run_result(args.suite, system, git_sha)
        jsonschema.validate(instance=result, schema=schema)
        print(json.dumps(result, indent=2))
        return

    skipped = False
    suite_results: list[dict] = []
    errors: list[str] = []

    mlx_available = mlx_server_available()

    if args.suite in INFERENCE_SUITES and not mlx_available:
        errors = [f"{args.suite}: MLX server not available — requires M-series hardware with vllm-mlx running"]
        skipped = True
    elif args.suite == "capability-comparison" and not mlx_available:
        errors = ["capability-comparison: MLX server not available — requires M-series hardware"]
        skipped = True
    else:
        runner = SUITE_RUNNERS[args.suite]
        suite_results, errors = runner(model)

    # Build model slug for filename (replace / with -)
    model_slug = model.rsplit("/", 1)[-1] if "/" in model else model

    result: dict = {
        "schema_version": SCHEMA_VERSION,
        "timestamp": timestamp,
        "git_sha": git_sha,
        "trigger": get_trigger(),
        "pr_number": get_pr_number(),
        "suite": args.suite,
        "model": model,
        "system": system,
        "results": suite_results,
        "errors": errors,
    }
    if skipped:
        result["skipped"] = True

    try:
        jsonschema.validate(instance=result, schema=schema)
    except jsonschema.ValidationError as e:
        print(f"WARNING: result failed schema validation: {e.message}", file=sys.stderr)

    out_dir = REPO_ROOT / "data" / "benchmarks"
    out_dir.mkdir(parents=True, exist_ok=True)
    filename = f"{filename_ts}-{git_sha}-{model_slug}-{args.suite}.json"
    out_path = out_dir / filename
    out_path.write_text(json.dumps(result, indent=2) + "\n")
    print(f"Wrote {out_path}", file=sys.stderr)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
