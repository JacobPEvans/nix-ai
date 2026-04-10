"""Declarative skill schema and registry for local AI skill orchestration.

Defines Pydantic models for skill configuration loaded from YAML files.
Skills describe a task template with model requirements, prompts, tools,
and output schemas that the orchestrator uses to route and execute requests.
"""

from __future__ import annotations

import os
from enum import Enum
from pathlib import Path
from typing import Any

from pydantic import BaseModel, ConfigDict, Field

from orchestrator.common import load_yaml_file

_DEFAULT_MODEL = os.environ.get("MLX_DEFAULT_MODEL", "default")


class ModelSize(str, Enum):
    """Model size categories for resource planning."""

    SMALL = "small"  # 7-8B params, ~5GB VRAM
    MEDIUM = "medium"  # 27-35B params, ~15-20GB VRAM
    LARGE = "large"  # 70B+ params, ~40GB+ VRAM
    EMBEDDING = "embedding"  # Embedding models, ~300MB


class OutputFormat(str, Enum):
    """Supported output formats for skill results."""

    TEXT = "text"
    JSON = "json"
    MARKDOWN = "markdown"
    DIFF = "diff"


class ModelRequirement(BaseModel):
    """Specifies which model a skill needs and how to reach it."""

    endpoint: str = Field(
        default="http://127.0.0.1:11434/v1",
        description="OpenAI-compatible API endpoint URL",
    )
    model: str = Field(
        default=_DEFAULT_MODEL,
        description="Model identifier (HuggingFace ID for MLX models)",
    )
    size: ModelSize = Field(
        default=ModelSize.MEDIUM,
        description="Model size category for resource planning",
    )
    temperature: float = Field(
        default=0.7,
        ge=0.0,
        le=2.0,
        description="Sampling temperature",
    )
    max_tokens: int = Field(
        default=4096,
        gt=0,
        description="Maximum tokens in the response",
    )
    json_mode: bool = Field(
        default=False,
        description="Whether to request structured JSON output",
    )


class ToolDefinition(BaseModel):
    """A tool that can be invoked during skill execution."""

    name: str = Field(description="Tool name")
    description: str = Field(description="What the tool does")
    parameters: dict[str, Any] = Field(
        default_factory=dict,
        description="JSON Schema for tool parameters",
    )


class ResourceBudget(BaseModel):
    """Resource constraints for skill execution."""

    max_memory_gb: float = Field(
        default=20.0,
        description="Maximum GPU/unified memory in GB",
    )
    max_duration_seconds: int = Field(
        default=300,
        description="Maximum execution time in seconds",
    )
    max_input_tokens: int = Field(
        default=32768,
        description="Maximum input context tokens",
    )


class SkillDefinition(BaseModel):
    """Complete definition of a skill loaded from YAML.

    A skill is a repeatable task template that specifies:
    - What model to use (and how to configure it)
    - What system prompt to apply
    - What tools are available
    - What output format to expect
    - What resources it needs
    """

    model_config = ConfigDict(extra="forbid")

    name: str = Field(description="Unique skill identifier (kebab-case)")
    description: str = Field(description="Human-readable description of what the skill does")
    version: str = Field(default="1.0.0", description="Semantic version of the skill definition")
    tags: list[str] = Field(
        default_factory=list,
        description="Tags for categorization and routing",
    )

    model: ModelRequirement = Field(
        default_factory=ModelRequirement,
        description="Model configuration for this skill",
    )

    system_prompt: str = Field(
        default="",
        description="System prompt text (inline). Use system_prompt_file for file-based prompts",
    )
    system_prompt_file: str | None = Field(
        default=None,
        description="Path to external system prompt file (relative to skill YAML)",
    )

    tools: list[ToolDefinition] = Field(
        default_factory=list,
        description="Tools available during skill execution",
    )

    output_format: OutputFormat = Field(
        default=OutputFormat.TEXT,
        description="Expected output format",
    )
    output_schema: dict[str, Any] | None = Field(
        default=None,
        description="JSON Schema for structured output (when output_format is JSON)",
    )

    resources: ResourceBudget = Field(
        default_factory=ResourceBudget,
        description="Resource constraints for this skill",
    )

    examples: list[str] = Field(
        default_factory=list,
        description="Example prompts that should route to this skill",
    )

    def resolve_system_prompt(self, base_dir: Path) -> str:
        """Resolve the system prompt, loading from file if specified."""
        if self.system_prompt_file:
            prompt_path = base_dir / self.system_prompt_file
            if prompt_path.exists():
                return prompt_path.read_text()
            msg = f"System prompt file not found: {prompt_path}"
            raise FileNotFoundError(msg)
        return self.system_prompt


def load_skill(path: Path) -> SkillDefinition:
    """Load a single skill definition from a YAML file."""
    data = load_yaml_file(path)
    return SkillDefinition.model_validate(data)


def load_skill_registry(directory: Path) -> dict[str, SkillDefinition]:
    """Load all skill definitions from a directory of YAML files.

    Scans for *.yaml and *.yml files, validates each against the schema,
    and returns a dict keyed by skill name.
    """
    skills: dict[str, SkillDefinition] = {}
    if not directory.is_dir():
        msg = f"Skill registry directory not found: {directory}"
        raise FileNotFoundError(msg)

    for yaml_path in sorted(directory.iterdir()):
        if yaml_path.suffix not in {".yaml", ".yml"}:
            continue
        skill = load_skill(yaml_path)
        if skill.name in skills:
            msg = f"Duplicate skill name '{skill.name}' in {yaml_path}"
            raise ValueError(msg)
        skills[skill.name] = skill

    return skills


def load_fabric_pattern(
    pattern_dir: Path,
    *,
    description: str | None = None,
    model: ModelRequirement | None = None,
) -> SkillDefinition:
    """Load a single Fabric pattern as an orchestrator SkillDefinition.

    Fabric patterns (https://github.com/danielmiessler/fabric/tree/main/data/patterns)
    are directories containing a `system.md` file with the AI instructions and
    optionally a `user.md` or `README.md` for human documentation.

    The pattern directory name becomes the skill name (with hyphens replacing
    underscores for kebab-case consistency). The `system.md` content becomes
    the skill's system_prompt. Default model is taken from MLX_DEFAULT_MODEL,
    with markdown output and a generous resource budget appropriate for
    fabric's prompt-in/prompt-out workflow.
    """
    if not pattern_dir.is_dir():
        msg = f"Fabric pattern directory not found: {pattern_dir}"
        raise FileNotFoundError(msg)

    system_md = pattern_dir / "system.md"
    if not system_md.is_file():
        msg = f"Fabric pattern missing system.md: {system_md}"
        raise FileNotFoundError(msg)

    pattern_name = pattern_dir.name
    skill_name = pattern_name.replace("_", "-")
    system_prompt = system_md.read_text()

    return SkillDefinition(
        name=skill_name,
        description=description or f"Fabric pattern: {pattern_name}",
        version="1.0.0",
        tags=["fabric", "pattern", pattern_name.split("_", 1)[0]],
        model=model or ModelRequirement(),
        system_prompt=system_prompt,
        output_format=OutputFormat.MARKDOWN,
        resources=ResourceBudget(
            max_memory_gb=20.0,
            max_duration_seconds=300,
            max_input_tokens=32768,
        ),
        examples=[],
    )


def load_fabric_pattern_registry(
    patterns_dir: Path,
    *,
    only: list[str] | None = None,
    descriptions: dict[str, str] | None = None,
) -> dict[str, SkillDefinition]:
    """Load Fabric patterns as a registry of SkillDefinition objects.

    Args:
        patterns_dir: Path to the fabric data/patterns/ directory.
        only: Optional whitelist of pattern names to load. When None, loads
              all patterns under patterns_dir.
        descriptions: Optional mapping from pattern name to a hand-written
                      description. Patterns not in the mapping get a generic
                      description derived from the pattern name.

    Returns:
        A dict keyed by skill name (kebab-case version of the pattern name).
    """
    if not patterns_dir.is_dir():
        msg = f"Fabric patterns directory not found: {patterns_dir}"
        raise FileNotFoundError(msg)

    descriptions = descriptions or {}
    skills: dict[str, SkillDefinition] = {}

    for pattern_dir in sorted(patterns_dir.iterdir()):
        if not pattern_dir.is_dir():
            continue
        pattern_name = pattern_dir.name
        if only is not None and pattern_name not in only:
            continue
        if not (pattern_dir / "system.md").is_file():
            continue
        skill = load_fabric_pattern(
            pattern_dir,
            description=descriptions.get(pattern_name),
        )
        skills[skill.name] = skill

    return skills
