#!/usr/bin/env python3
# /// script
# dependencies = ["jsonschema>=4.0"]
# ///
"""Collect benchmark results for a single suite and write a schema-conforming JSON file.

Usage:
  uv run scripts/benchmarks/collect-results.py --suite framework-eval
  uv run scripts/benchmarks/collect-results.py --suite framework-eval --dry-run
  uv run scripts/benchmarks/collect-results.py --suite throughput

Suites:
  framework-eval        Run 4 agent framework benchmark scripts, capture JSON output
  capability-comparison Run mlx-server/benchmarks/run_all.sh, capture category results
  throughput            Requires MLX server — skipped on standard runners
  ttft                  Requires MLX server — skipped on standard runners
  tool-calling          Requires MLX server — skipped on standard runners
  code-accuracy         Requires MLX server — skipped on standard runners

Output:
  Writes data/benchmarks/{timestamp}-{sha7}-{suite}.json and prints JSON to stdout.
  On dry-run: builds a synthetic result and validates it without running inference.
"""

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import UTC, datetime
from pathlib import Path

import jsonschema

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCHEMA_PATH = REPO_ROOT / "data" / "benchmarks" / "schema.json"
AGENT_SCRIPTS_DIR = REPO_ROOT / "orchestrator" / "examples" / "evaluations"
BENCHMARKS_DIR = REPO_ROOT / "mlx-server" / "benchmarks"
MLX_API_URL = os.environ.get("MLX_API_URL", "http://127.0.0.1:11434/v1")
MLX_DEFAULT_MODEL = os.environ.get("MLX_DEFAULT_MODEL", "mlx-community/Qwen3.5-122B-A10B-4bit")

FRAMEWORK_SCRIPTS = [
    ("eval_langgraph.py", "langgraph"),
    ("eval_qwen_agent.py", "qwen-agent"),
    ("eval_smolagents.py", "smolagents"),
    ("eval_google_adk.py", "google-adk"),
]

INFERENCE_SUITES = {"throughput", "ttft", "tool-calling", "code-accuracy"}


# ---------------------------------------------------------------------------
# System info
# ---------------------------------------------------------------------------

def _run(cmd: list[str], default: str = "unknown") -> str:
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return default


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

    vllm_ver = _run(["pip", "show", "vllm-mlx"])
    vllm_version = "unknown"
    if vllm_ver != "unknown":
        for line in vllm_ver.splitlines():
            if line.startswith("Version:"):
                vllm_version = line.split(":", 1)[1].strip()
                break

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


def get_model_name() -> str:
    return os.environ.get("MLX_DEFAULT_MODEL", MLX_DEFAULT_MODEL)


def get_trigger() -> str:
    event = os.environ.get("GITHUB_EVENT_NAME", "")
    if event == "pull_request":
        return "pr"
    if event == "schedule":
        return "schedule"
    if event == "workflow_dispatch":
        return "workflow_dispatch"
    return "workflow_dispatch"


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
        score = category_data.get("score", 0)
        baseline = category_data.get("claude_baseline", None)

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


def run_inference_stub(suite: str) -> tuple[list[dict], list[str], bool]:
    """Placeholder for inference suites that require MLX hardware."""
    if not mlx_server_available():
        return (
            [],
            [f"{suite}: MLX server not available — requires M-series hardware with vllm-mlx running"],
            True,
        )
    # Inference suite implementations are tracked in Issue #9
    return [], [f"{suite}: inference suite collection not yet implemented — run mlx-bench* tools manually"], False


# ---------------------------------------------------------------------------
# Dry-run mock
# ---------------------------------------------------------------------------

def build_dry_run_result(suite: str, system: dict, git_sha: str) -> dict:
    return {
        "schema_version": "1",
        "timestamp": datetime.now(UTC).strftime("%Y-%m-%dT%H%M%SZ"),
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
    parser.add_argument("--suite", required=True, choices=[
        "throughput", "ttft", "tool-calling", "code-accuracy",
        "framework-eval", "capability-comparison",
    ])
    parser.add_argument("--dry-run", action="store_true",
                        help="Build mock result without running inference")
    args = parser.parse_args()

    schema = json.loads(SCHEMA_PATH.read_text())
    timestamp = datetime.now(UTC).strftime("%Y-%m-%dT%H%M%SZ")
    git_sha = get_git_sha()
    system = collect_system_info()

    if args.dry_run:
        result = build_dry_run_result(args.suite, system, git_sha)
        jsonschema.validate(instance=result, schema=schema)
        print(json.dumps(result, indent=2))
        return

    skipped = False
    errors: list[str] = []

    if args.suite == "framework-eval":
        suite_results, errors = run_framework_suite()
    elif args.suite == "capability-comparison":
        if not mlx_server_available():
            suite_results = []
            errors = ["capability-comparison: MLX server not available — requires M-series hardware"]
            skipped = True
        else:
            suite_results, errors = run_capability_suite()
    else:
        suite_results, errors, skipped = run_inference_stub(args.suite)

    result: dict = {
        "schema_version": "1",
        "timestamp": timestamp,
        "git_sha": git_sha,
        "trigger": get_trigger(),
        "pr_number": get_pr_number(),
        "suite": args.suite,
        "model": get_model_name(),
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
    filename = f"{timestamp}-{git_sha}-{args.suite}.json"
    out_path = out_dir / filename
    out_path.write_text(json.dumps(result, indent=2) + "\n")
    print(f"Wrote {out_path}", file=sys.stderr)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
