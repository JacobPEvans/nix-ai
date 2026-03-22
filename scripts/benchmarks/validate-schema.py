#!/usr/bin/env python3
# /// script
# dependencies = ["jsonschema>=4.0"]
# ///
"""Validate data/benchmarks/schema.json and optionally result files against it.

Usage:
  uv run scripts/benchmarks/validate-schema.py data/benchmarks/schema.json
  uv run scripts/benchmarks/validate-schema.py data/benchmarks/schema.json result1.json result2.json
"""

import json
import sys
from pathlib import Path

import jsonschema
import jsonschema.validators


def load_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError as e:
        print(f"ERROR: {path}: invalid JSON: {e}", file=sys.stderr)
        sys.exit(1)
    except FileNotFoundError:
        print(f"ERROR: {path}: file not found", file=sys.stderr)
        sys.exit(1)


def validate_meta_schema(schema_path: Path) -> dict:
    """Confirm schema.json is itself valid JSON Schema draft-07."""
    schema = load_json(schema_path)
    meta = "http://json-schema.org/draft-07/schema#"
    validator_cls = jsonschema.validators.validator_for({"$schema": meta})
    try:
        validator_cls.check_schema(schema)
    except jsonschema.SchemaError as e:
        print(f"ERROR: {schema_path}: invalid schema: {e.message}", file=sys.stderr)
        sys.exit(1)
    print(f"OK: {schema_path} is valid JSON Schema draft-07")
    return schema


def validate_result(result_path: Path, schema: dict) -> bool:
    result = load_json(result_path)
    try:
        jsonschema.validate(instance=result, schema=schema)
        print(f"OK: {result_path}")
        return True
    except jsonschema.ValidationError as e:
        print(f"FAIL: {result_path}: {e.message} (path: {list(e.absolute_path)})", file=sys.stderr)
        return False


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: validate-schema.py <schema.json> [result.json ...]", file=sys.stderr)
        sys.exit(1)

    schema_path = Path(sys.argv[1])
    result_paths = [Path(p) for p in sys.argv[2:]]

    schema = validate_meta_schema(schema_path)

    if not result_paths:
        return

    failures = sum(1 for p in result_paths if not validate_result(p, schema))
    if failures:
        print(f"\n{failures}/{len(result_paths)} file(s) failed validation", file=sys.stderr)
        sys.exit(1)

    print(f"\nAll {len(result_paths)} result file(s) valid")


if __name__ == "__main__":
    main()
