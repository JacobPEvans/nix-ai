#!/usr/bin/env python3
# /// script
# dependencies = []
# ///
"""Orchestrate benchmark runs across models and suites.

Usage:
  uv run scripts/benchmarks/orchestrate.py                                    # All suites, current model
  uv run scripts/benchmarks/orchestrate.py --model mlx-community/gemma-4-31b-it-4bit
  uv run scripts/benchmarks/orchestrate.py --suite throughput,ttft            # Specific suites
  uv run scripts/benchmarks/orchestrate.py --all-models                       # Every fitting model
  uv run scripts/benchmarks/orchestrate.py --all-models --suite throughput    # One suite, all models
  uv run scripts/benchmarks/orchestrate.py --dry-run                          # Validate without inference
"""

import argparse
import os
import re
import subprocess
import sys
import time
from pathlib import Path

ALL_SUITES = [
    "throughput",
    "ttft",
    "tool-calling",
    "code-accuracy",
    "coding",
    "reasoning",
    "knowledge",
    "framework-eval",
    "capability-comparison",
]

SKIP_PATTERN = re.compile(
    r"FLUX|whisper|OCR|Embedding|TTS|GGUF|clip|siglip|reranker|gte-|bge-",
    re.IGNORECASE,
)


def _find_repo_root() -> Path:
    """Find nix-ai repo root from script location, env var, or CWD."""
    # Try script location first (works when run directly from repo)
    script_based = Path(__file__).resolve().parent.parent.parent
    if (script_based / "flake.nix").exists():
        return script_based
    # Try env var
    env = os.environ.get("NIX_AI_REPO_ROOT")
    if env:
        p = Path(env)
        if (p / "scripts" / "benchmarks").is_dir():
            return p
    # Walk up from CWD
    d = Path.cwd()
    while d != d.parent:
        if (d / "flake.nix").exists() and (d / "scripts" / "benchmarks").is_dir():
            return d
        d = d.parent
    sys.exit(
        "ERROR: Cannot find nix-ai repo root. Set NIX_AI_REPO_ROOT or run from repo."
    )


REPO_ROOT = _find_repo_root()


def get_available_gb() -> int:
    """Return available memory in GB (total - 20 GB reserved)."""
    result = subprocess.run(
        ["sysctl", "-n", "hw.memsize"], capture_output=True, text=True, check=True
    )
    total_gb = int(result.stdout.strip()) // (1024**3)
    return total_gb - 20


def dir_size_gb(path: Path) -> int:
    """Return directory size in GB (rounded)."""
    total = sum(f.stat().st_size for f in path.rglob("*") if f.is_file())
    return round(total / (1024**3))


def discover_models() -> list[str]:
    """Scan HF cache for fitting mlx-community models."""
    hf_home = Path(os.environ.get("MLX_HF_HOME", "/Volumes/HuggingFace"))
    hub = hf_home / "hub"
    if not hub.is_dir():
        return []

    available_gb = get_available_gb()
    models = []

    # Run mlx-discover to ensure all models are registered
    subprocess.run(["mlx-discover", "--quiet"], capture_output=True)

    for model_dir in sorted(hub.glob("models--mlx-community--*")):
        if not model_dir.is_dir():
            continue
        model_id = model_dir.name.removeprefix("models--").replace("--", "/")

        if SKIP_PATTERN.search(model_id):
            continue

        est_gb = round(dir_size_gb(model_dir) * 1.3)
        if est_gb <= available_gb:
            models.append(model_id)

    return models


def switch_model(model: str) -> bool:
    """Switch to model via mlx-switch. Returns True on success."""
    print(f"Switching to {model}...")
    result = subprocess.run(["mlx-switch", model], capture_output=False)
    return result.returncode == 0


def wait_for_ready(timeout: int = 180) -> bool:
    """Wait for model to become ready. Returns True on success."""
    print("Waiting for model to become ready...")
    result = subprocess.run(
        ["mlx-wait", str(timeout)], capture_output=False
    )
    return result.returncode == 0


def warmup(model: str, count: int) -> None:
    """Send throwaway requests to warm up the model."""
    if count <= 0:
        return
    api = os.environ.get("MLX_API_URL", "http://127.0.0.1:11434/v1")
    print(f"Warming up ({count} requests)...")
    for i in range(1, count + 1):
        subprocess.run(
            [
                "curl",
                "-sf",
                f"{api}/chat/completions",
                "-H",
                "Content-Type: application/json",
                "--max-time",
                "60",
                "-d",
                f'{{"model": "{model}", "messages": [{{"role": "user", "content": "warmup {i}"}}], "max_tokens": 10}}',
            ],
            capture_output=True,
        )


def run_suite(suite: str, model: str, dry_run: bool) -> bool:
    """Run a single benchmark suite. Returns True on success."""
    collect_script = REPO_ROOT / "scripts" / "benchmarks" / "collect-results.py"
    cmd = ["uv", "run", str(collect_script), "--suite", suite, "--model", model]
    if dry_run:
        cmd.append("--dry-run")

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        # Print last line (summary)
        lines = result.stdout.strip().splitlines()
        if lines:
            print(f"    {lines[-1]}")
    return result.returncode == 0


def regenerate_summary() -> None:
    """Run generate-summary.py to update docs."""
    summary_script = REPO_ROOT / "scripts" / "benchmarks" / "generate-summary.py"
    if not summary_script.is_file():
        return
    print("\nRegenerating benchmark summary...")
    result = subprocess.run(
        ["uv", "run", str(summary_script)], capture_output=True, text=True
    )
    if result.returncode != 0:
        print("WARNING: Summary generation failed", file=sys.stderr)
    elif result.stdout:
        print(result.stdout.strip())


def main() -> None:
    parser = argparse.ArgumentParser(description="Orchestrate MLX benchmark runs")
    parser.add_argument("--model", help="Model ID to benchmark")
    parser.add_argument(
        "--suite",
        default=",".join(ALL_SUITES),
        help="Comma-separated suite list (default: all)",
    )
    parser.add_argument(
        "--all-models",
        action="store_true",
        help="Benchmark every downloaded model that fits in memory",
    )
    parser.add_argument(
        "--warmup", type=int, default=3, help="Warmup requests (default: 3)"
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="Validate without running inference"
    )
    args = parser.parse_args()

    # Build model list
    if args.all_models:
        print("Discovering models...")
        models = discover_models()
        if not models:
            print("ERROR: No fitting models found", file=sys.stderr)
            sys.exit(1)
        print(f"Found {len(models)} models to benchmark")
    elif args.model:
        models = [args.model]
    else:
        default_model = os.environ.get("MLX_DEFAULT_MODEL", "")
        if not default_model:
            print(
                "ERROR: No model specified and MLX_DEFAULT_MODEL not set",
                file=sys.stderr,
            )
            print("Use --model <id> or --all-models", file=sys.stderr)
            sys.exit(1)
        models = [default_model]

    suite_list = [s.strip() for s in args.suite.split(",")]
    total_runs = len(models) * len(suite_list)
    run_count = 0
    failed = 0

    print()
    print("=" * 55)
    print("  MLX Benchmark Run")
    print(
        f"  Models: {len(models)}  |  Suites: {len(suite_list)}  |  Total: {total_runs}"
    )
    print("=" * 55)
    print()

    for model in models:
        print("-" * 52)
        print(f"  Model: {model}")
        print("-" * 52)

        if not args.dry_run:
            if not switch_model(model):
                print(f"WARNING: Failed to switch to {model} -- skipping", file=sys.stderr)
                failed += len(suite_list)
                run_count += len(suite_list)
                continue

            if not wait_for_ready():
                print(
                    f"WARNING: Model {model} did not become ready -- skipping",
                    file=sys.stderr,
                )
                failed += len(suite_list)
                run_count += len(suite_list)
                continue

            warmup(model, args.warmup)

        for suite in suite_list:
            run_count += 1
            print(f"  [{run_count}/{total_runs}] Suite: {suite}")

            if run_suite(suite, model, args.dry_run):
                print(f"  > {suite} complete")
            else:
                print(f"  x {suite} failed", file=sys.stderr)
                failed += 1

        # Sleep between models for memory reclamation
        if not args.dry_run and len(models) > 1:
            print("  Waiting 10s for memory reclamation...")
            time.sleep(10)

    regenerate_summary()

    print()
    print("=" * 55)
    print("  Benchmark Complete")
    print(f"  Passed: {total_runs - failed}/{total_runs}")
    if failed > 0:
        print(f"  Failed: {failed}")
    print("=" * 55)

    sys.exit(1 if failed > 0 else 0)


if __name__ == "__main__":
    main()
