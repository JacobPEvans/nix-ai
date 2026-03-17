"""Tests for orchestrator.common utilities."""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pytest
import yaml

from orchestrator.common import l2_normalize, load_yaml_file


# ---------------------------------------------------------------------------
# TestLoadYamlFile
# ---------------------------------------------------------------------------


class TestLoadYamlFile:
    """Tests for load_yaml_file()."""

    def test_valid_yaml_file(self, tmp_path: Path) -> None:
        f = tmp_path / "good.yaml"
        f.write_text("key: value\nnested:\n  a: 1\n")
        result = load_yaml_file(f)
        assert result == {"key": "value", "nested": {"a": 1}}

    def test_missing_file_raises(self, tmp_path: Path) -> None:
        with pytest.raises(FileNotFoundError, match="File not found"):
            load_yaml_file(tmp_path / "nonexistent.yaml")

    def test_empty_file_raises(self, tmp_path: Path) -> None:
        f = tmp_path / "empty.yaml"
        f.write_text("")
        with pytest.raises(ValueError, match="got NoneType"):
            load_yaml_file(f)

    def test_list_yaml_raises(self, tmp_path: Path) -> None:
        f = tmp_path / "list.yaml"
        f.write_text("- one\n- two\n")
        with pytest.raises(ValueError, match="got list"):
            load_yaml_file(f)

    def test_scalar_yaml_raises(self, tmp_path: Path) -> None:
        f = tmp_path / "scalar.yaml"
        f.write_text("42\n")
        with pytest.raises(ValueError, match="got int"):
            load_yaml_file(f)

    def test_invalid_yaml_syntax(self, tmp_path: Path) -> None:
        f = tmp_path / "bad.yaml"
        f.write_text("key: [unterminated\n")
        with pytest.raises(yaml.YAMLError):
            load_yaml_file(f)


# ---------------------------------------------------------------------------
# TestL2Normalize
# ---------------------------------------------------------------------------


class TestL2Normalize:
    """Tests for l2_normalize()."""

    def test_normal_vectors(self) -> None:
        arr = np.array([[3.0, 4.0]])
        result = l2_normalize(arr)
        norms = np.linalg.norm(result, axis=1)
        np.testing.assert_allclose(norms, 1.0, atol=1e-6)

    def test_zero_norm_vector(self) -> None:
        arr = np.array([[0.0, 0.0, 0.0]])
        result = l2_normalize(arr)
        assert not np.any(np.isnan(result))

    def test_multi_row(self) -> None:
        arr = np.array([[3.0, 4.0], [0.0, 5.0]])
        result = l2_normalize(arr)
        norms = np.linalg.norm(result, axis=1)
        np.testing.assert_allclose(norms, 1.0, atol=1e-6)

    def test_single_element_rows(self) -> None:
        arr = np.array([[7.0], [-3.0]])
        result = l2_normalize(arr)
        norms = np.linalg.norm(result, axis=1)
        np.testing.assert_allclose(norms, 1.0, atol=1e-6)
