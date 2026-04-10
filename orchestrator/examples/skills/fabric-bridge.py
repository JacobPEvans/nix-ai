"""Example: Loading Fabric patterns into the orchestrator skill registry.

Daniel Miessler's Fabric (github.com/danielmiessler/fabric) ships 252+ AI prompt
patterns under data/patterns/. Each pattern is a directory with a `system.md`
file containing the AI instructions.

The orchestrator's `load_fabric_pattern_registry` function bridges these
patterns into our SkillDefinition format, so they can be used alongside or
instead of the YAML-defined example skills (code-review.yaml, etc.).

This example shows three usage patterns:
  1. Load all fabric patterns under a directory
  2. Load only a curated subset
  3. Load with custom descriptions and a heavyweight model override

Run via:
    FABRIC_PATTERNS_DIR=~/.config/fabric/patterns \
        python orchestrator/examples/skills/fabric-bridge.py
"""

from __future__ import annotations

import os
from pathlib import Path

from orchestrator.skill_schema import (
    ModelRequirement,
    ModelSize,
    load_fabric_pattern,
    load_fabric_pattern_registry,
)


def main() -> None:
    patterns_dir = Path(
        os.environ.get(
            "FABRIC_PATTERNS_DIR",
            str(Path.home() / ".config" / "fabric" / "patterns"),
        )
    )

    if not patterns_dir.is_dir():
        msg = (
            f"Fabric patterns dir not found: {patterns_dir}\n"
            "Install fabric (modules/fabric/) and ensure home-manager "
            "has symlinked the patterns to ~/.config/fabric/patterns/"
        )
        raise SystemExit(msg)

    # --- Example 1: Load every available pattern ---
    full_registry = load_fabric_pattern_registry(patterns_dir)
    print(f"[1] Loaded {len(full_registry)} fabric patterns from {patterns_dir}")

    # --- Example 2: Load a curated subset ---
    curated_names = [
        "extract_wisdom",
        "summarize",
        "analyze_paper",
        "create_prd",
        "review_code",
    ]
    curated = load_fabric_pattern_registry(patterns_dir, only=curated_names)
    print(f"[2] Loaded {len(curated)} curated patterns:")
    for skill in curated.values():
        snippet = skill.system_prompt.splitlines()[0][:80]
        print(f"    {skill.name}: {snippet}")

    # --- Example 3: Load a single pattern with overrides ---
    heavy_model = ModelRequirement(
        endpoint="http://127.0.0.1:11434/v1",
        model="mlx-community/Qwen3.5-122B-A10B-4bit",
        size=ModelSize.LARGE,
        temperature=0.3,
        max_tokens=8192,
    )
    extract_wisdom = load_fabric_pattern(
        patterns_dir / "extract_wisdom",
        description="Pull the most surprising insights from any content",
        model=heavy_model,
    )
    print(
        f"[3] {extract_wisdom.name}: "
        f"model={extract_wisdom.model.model}, "
        f"size={extract_wisdom.model.size.value}, "
        f"temp={extract_wisdom.model.temperature}"
    )


if __name__ == "__main__":
    main()
