#!/usr/bin/env python3
# /// script
# dependencies = ["jsonschema>=4.0"]
# ///
"""Validate imports and schema construction without running inference.

Constructs a synthetic result matching every required schema field, validates it
against data/benchmarks/schema.json, and exits 0 on success. Safe to run on any
runner — no MLX server or hardware required.

Usage:
  uv run scripts/benchmarks/dry-run-check.py
"""

import json
import sys
from pathlib import Path

import jsonschema

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
SCHEMA_PATH = REPO_ROOT / "data" / "benchmarks" / "schema.json"


def build_mock_result() -> dict:
    return {
        "schema_version": "1",
        "timestamp": "2026-01-01T00:00:00Z",
        "git_sha": "abc1234",
        "trigger": "workflow_dispatch",
        "pr_number": None,
        "suite": "framework-eval",
        "model": "dry-run-model",
        "skipped": False,
        "system": {
            "os": "macOS 15.0",
            "chip": "Apple M4 Max",
            "memory_gb": 128,
            "vllm_mlx_version": "0.0.0",
            "runner": "self-hosted",
        },
        "results": [
            {
                "name": "dry-run-test",
                "metric": "latency",
                "value": 0.001,
                "unit": "seconds",
                "tags": {"framework": "dry-run"},
                "raw": {"note": "synthetic result"},
            }
        ],
        "memory_snapshots": [
            {
                "phase": "before",
                "rss_gb": 1.0,
                "free_gb": 100.0,
                "wired_gb": 10.0,
                "swap_mb": 0.0,
            }
        ],
        "errors": [],
    }


def main() -> None:
    if not SCHEMA_PATH.exists():
        print(f"ERROR: schema not found at {SCHEMA_PATH}", file=sys.stderr)
        sys.exit(1)

    schema = json.loads(SCHEMA_PATH.read_text())

    mock = build_mock_result()
    try:
        jsonschema.validate(instance=mock, schema=schema)
    except jsonschema.ValidationError as e:
        print(f"ERROR: mock result failed schema validation: {e.message}", file=sys.stderr)
        sys.exit(1)

    # Validate new suite/trigger values added for dynamic benchmarks
    for suite, trigger in [("coding", "local"), ("reasoning", "local"), ("knowledge", "local")]:
        variant = build_mock_result()
        variant["suite"] = suite
        variant["trigger"] = trigger
        try:
            jsonschema.validate(instance=variant, schema=schema)
        except jsonschema.ValidationError as e:
            print(f"ERROR: mock with suite={suite}, trigger={trigger} failed: {e.message}", file=sys.stderr)
            sys.exit(1)

    print("OK: dry-run passed — imports healthy, mock result validates against schema")


if __name__ == "__main__":
    main()
