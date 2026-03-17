"""Pydantic models and state definition for declarative workflows."""

from __future__ import annotations

from enum import Enum
from typing import Any, TypedDict

from pydantic import BaseModel, ConfigDict, Field


class NodeType(str, Enum):
    """Supported node types in a workflow graph."""

    LLM_CALL = "llm_call"
    TOOL_EXEC = "tool_exec"
    HUMAN_INPUT = "human_input"
    CONDITIONAL = "conditional"


class NodeDefinition(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str = Field(description="Unique node identifier within the workflow")
    type: NodeType = Field(description="Node type that determines execution behaviour")
    config: dict[str, Any] = Field(default_factory=dict)
    description: str | None = Field(default=None)


class EdgeDefinition(BaseModel):
    model_config = ConfigDict(extra="forbid")

    source: str = Field(description="Name of the source node")
    target: str = Field(description="Name of the target node")
    condition: str | None = Field(default=None)


class WorkflowDefinition(BaseModel):
    """Complete definition of a workflow loaded from YAML."""

    model_config = ConfigDict(extra="forbid")

    name: str = Field(description="Unique workflow identifier (kebab-case)")
    description: str = Field(description="Human-readable description of the workflow")
    nodes: list[NodeDefinition] = Field(description="Ordered list of workflow nodes")
    edges: list[EdgeDefinition] = Field(default_factory=list)
    entry_point: str = Field(description="Name of the node where execution starts")


class WorkflowState(TypedDict, total=False):
    """Shared state passed between all nodes in a workflow graph."""

    messages: list[dict[str, str]]
    current_node: str
    metadata: dict[str, Any]
    output: Any
    pending_human_input: bool
    human_input_prompt: str
