"""Tests for skill schema validation and registry loading."""

from __future__ import annotations

from pathlib import Path
import pytest
import yaml
from pydantic import ValidationError

from orchestrator.skill_schema import (
    ModelRequirement,
    ModelSize,
    OutputFormat,
    ResourceBudget,
    SkillDefinition,
    _DEFAULT_MODEL,
    load_fabric_pattern,
    load_fabric_pattern_registry,
    load_skill,
    load_skill_registry,
)

# Test fixture constant: model name used in override tests. Kept as a
# module-level constant so a single edit updates every assertion. This is
# purely test data — the test doesn't actually load this model, it just
# verifies ModelRequirement field assignment works.
_TEST_LARGE_MODEL = "mlx-community/Qwen3.5-122B-A10B-4bit"


@pytest.fixture
def sample_skill_data() -> dict:
    return {
        "name": "code-review",
        "description": "Review code for quality, security, and best practices",
        "version": "1.0.0",
        "tags": ["code", "review", "quality"],
        "model": {
            "endpoint": "http://127.0.0.1:11434/v1",
            "model": "mlx-community/Qwen2.5-Coder-32B-Instruct-4bit",
            "size": "medium",
            "temperature": 0.3,
            "max_tokens": 8192,
            "json_mode": False,
        },
        "system_prompt": "You are an expert code reviewer.",
        "output_format": "markdown",
        "resources": {
            "max_memory_gb": 20.0,
            "max_duration_seconds": 120,
            "max_input_tokens": 32768,
        },
        "examples": [
            "Review this Python function for bugs",
            "Check this code for security issues",
        ],
    }


@pytest.fixture
def skill_yaml_dir(tmp_path: Path, sample_skill_data: dict) -> Path:
    skill_dir = tmp_path / "skills"
    skill_dir.mkdir()
    skill_file = skill_dir / "code-review.yaml"
    with skill_file.open("w") as f:
        yaml.dump(sample_skill_data, f)
    return skill_dir


class TestSkillDefinition:
    def test_minimal_skill(self):
        skill = SkillDefinition(
            name="test-skill",
            description="A test skill",
        )
        assert skill.name == "test-skill"
        assert skill.version == "1.0.0"
        assert skill.output_format == OutputFormat.TEXT
        assert skill.model.model == _DEFAULT_MODEL

    def test_full_skill(self, sample_skill_data: dict):
        skill = SkillDefinition.model_validate(sample_skill_data)
        assert skill.name == "code-review"
        assert skill.model.temperature == 0.3
        assert skill.model.size == ModelSize.MEDIUM
        assert skill.output_format == OutputFormat.MARKDOWN
        assert len(skill.examples) == 2

    def test_model_defaults(self):
        model = ModelRequirement()
        assert model.endpoint == "http://127.0.0.1:11434/v1"
        assert model.model == _DEFAULT_MODEL
        assert model.temperature == 0.7

    def test_resource_defaults(self):
        resources = ResourceBudget()
        assert resources.max_memory_gb == 20.0
        assert resources.max_duration_seconds == 300

    def test_temperature_validation(self):
        with pytest.raises(ValidationError):
            ModelRequirement(temperature=3.0)

    def test_max_tokens_validation(self):
        with pytest.raises(ValidationError):
            ModelRequirement(max_tokens=0)


class TestSystemPromptResolution:
    def test_inline_prompt(self):
        skill = SkillDefinition(
            name="test",
            description="test",
            system_prompt="You are helpful.",
        )
        assert skill.resolve_system_prompt(Path(".")) == "You are helpful."

    def test_file_prompt(self, tmp_path: Path):
        prompt_file = tmp_path / "prompt.md"
        prompt_file.write_text("You are an expert assistant.")
        skill = SkillDefinition(
            name="test",
            description="test",
            system_prompt_file="prompt.md",
        )
        assert skill.resolve_system_prompt(tmp_path) == "You are an expert assistant."

    def test_missing_file_prompt(self, tmp_path: Path):
        skill = SkillDefinition(
            name="test",
            description="test",
            system_prompt_file="nonexistent.md",
        )
        with pytest.raises(FileNotFoundError):
            skill.resolve_system_prompt(tmp_path)


class TestLoadSkill:
    def test_load_from_yaml(self, skill_yaml_dir: Path):
        skill = load_skill(skill_yaml_dir / "code-review.yaml")
        assert skill.name == "code-review"
        assert skill.model.temperature == 0.3

    def test_load_invalid_yaml(self, tmp_path: Path):
        bad_file = tmp_path / "bad.yaml"
        bad_file.write_text("name: 123\n")
        with pytest.raises(ValidationError):
            load_skill(bad_file)


class TestLoadSkillRegistry:
    def test_load_directory(self, skill_yaml_dir: Path):
        registry = load_skill_registry(skill_yaml_dir)
        assert "code-review" in registry
        assert len(registry) == 1

    def test_missing_directory(self):
        with pytest.raises(FileNotFoundError):
            load_skill_registry(Path("/nonexistent"))

    def test_duplicate_names(self, skill_yaml_dir: Path):
        # Add a second file with the same skill name
        dup_data = {
            "name": "code-review",
            "description": "Duplicate",
        }
        dup_file = skill_yaml_dir / "code-review-dup.yaml"
        with dup_file.open("w") as f:
            yaml.dump(dup_data, f)
        with pytest.raises(ValueError, match="Duplicate skill name"):
            load_skill_registry(skill_yaml_dir)

    def test_ignores_non_yaml(self, skill_yaml_dir: Path):
        (skill_yaml_dir / "readme.md").write_text("# Not a skill")
        registry = load_skill_registry(skill_yaml_dir)
        assert len(registry) == 1

    def test_multiple_skills(self, skill_yaml_dir: Path):
        second_skill = {
            "name": "code-explain",
            "description": "Explain code in plain language",
            "tags": ["code", "explain"],
        }
        with (skill_yaml_dir / "code-explain.yaml").open("w") as f:
            yaml.dump(second_skill, f)
        registry = load_skill_registry(skill_yaml_dir)
        assert len(registry) == 2
        assert "code-explain" in registry


@pytest.fixture
def fabric_patterns_dir(tmp_path: Path) -> Path:
    """Create a tiny synthetic fabric patterns directory layout for tests."""
    patterns = tmp_path / "patterns"
    patterns.mkdir()

    extract = patterns / "extract_wisdom"
    extract.mkdir()
    (extract / "system.md").write_text(
        "# IDENTITY\n\nYou extract wisdom from text content.\n"
    )
    (extract / "README.md").write_text("Human-facing docs (ignored)")

    summarize = patterns / "summarize"
    summarize.mkdir()
    (summarize / "system.md").write_text(
        "# IDENTITY\n\nYou summarize content concisely.\n"
    )

    # A directory without system.md should be skipped
    incomplete = patterns / "broken_pattern"
    incomplete.mkdir()
    (incomplete / "user.md").write_text("Just user docs, no system.md")

    return patterns


class TestLoadFabricPattern:
    def test_load_single_pattern(self, fabric_patterns_dir: Path):
        skill = load_fabric_pattern(fabric_patterns_dir / "extract_wisdom")
        # Underscores converted to hyphens for consistency with kebab-case
        assert skill.name == "extract-wisdom"
        assert "extract wisdom" in skill.system_prompt.lower()
        assert skill.output_format == OutputFormat.MARKDOWN
        assert "fabric" in skill.tags
        assert "pattern" in skill.tags
        assert "extract" in skill.tags

    def test_custom_description(self, fabric_patterns_dir: Path):
        skill = load_fabric_pattern(
            fabric_patterns_dir / "extract_wisdom",
            description="Custom desc",
        )
        assert skill.description == "Custom desc"

    def test_default_description(self, fabric_patterns_dir: Path):
        skill = load_fabric_pattern(fabric_patterns_dir / "extract_wisdom")
        assert "extract_wisdom" in skill.description

    def test_missing_directory(self, tmp_path: Path):
        with pytest.raises(FileNotFoundError):
            load_fabric_pattern(tmp_path / "nonexistent")

    def test_missing_system_md(self, fabric_patterns_dir: Path):
        with pytest.raises(FileNotFoundError, match="system.md"):
            load_fabric_pattern(fabric_patterns_dir / "broken_pattern")

    def test_custom_model_override(self, fabric_patterns_dir: Path):
        custom_model = ModelRequirement(
            model=_TEST_LARGE_MODEL,
            size=ModelSize.LARGE,
            temperature=0.3,
        )
        skill = load_fabric_pattern(
            fabric_patterns_dir / "extract_wisdom",
            model=custom_model,
        )
        assert skill.model.model == _TEST_LARGE_MODEL
        assert skill.model.size == ModelSize.LARGE
        assert skill.model.temperature == 0.3


class TestLoadFabricPatternRegistry:
    def test_load_all_patterns(self, fabric_patterns_dir: Path):
        registry = load_fabric_pattern_registry(fabric_patterns_dir)
        assert len(registry) == 2
        assert "extract-wisdom" in registry
        assert "summarize" in registry
        # broken_pattern is skipped because it has no system.md
        assert "broken-pattern" not in registry

    def test_only_filter(self, fabric_patterns_dir: Path):
        registry = load_fabric_pattern_registry(
            fabric_patterns_dir,
            only=["extract_wisdom"],
        )
        assert len(registry) == 1
        assert "extract-wisdom" in registry
        assert "summarize" not in registry

    def test_descriptions_mapping(self, fabric_patterns_dir: Path):
        registry = load_fabric_pattern_registry(
            fabric_patterns_dir,
            descriptions={"extract_wisdom": "Custom wisdom extractor"},
        )
        assert registry["extract-wisdom"].description == "Custom wisdom extractor"
        # Patterns not in mapping get default description
        assert "summarize" in registry["summarize"].description

    def test_missing_directory(self, tmp_path: Path):
        with pytest.raises(FileNotFoundError):
            load_fabric_pattern_registry(tmp_path / "nonexistent")

    def test_empty_directory(self, tmp_path: Path):
        empty = tmp_path / "empty"
        empty.mkdir()
        registry = load_fabric_pattern_registry(empty)
        assert registry == {}
