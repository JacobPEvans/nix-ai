"""Shared utilities for the orchestrator."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import numpy as np
import yaml


def load_yaml_file(path: str | Path) -> dict[str, Any]:
    """Load and return parsed YAML from a file."""
    path = Path(path)
    try:
        with path.open() as fh:
            return yaml.safe_load(fh)
    except FileNotFoundError:
        msg = f"File not found: {path}"
        raise FileNotFoundError(msg) from None


def l2_normalize(arr: np.ndarray) -> np.ndarray:
    """L2-normalize an array of vectors (row-wise)."""
    norms = np.linalg.norm(arr, axis=1, keepdims=True) + 1e-10
    return arr / norms
