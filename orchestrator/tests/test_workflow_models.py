"""Tests for orchestrator.workflows.models."""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from orchestrator.workflows.models import (
    EdgeDefinition,
    NodeDefinition,
    NodeType,
    WorkflowDefinition,
    WorkflowState,
)


# ---------------------------------------------------------------------------
# TestNodeType
# ---------------------------------------------------------------------------


class TestNodeType:
    """Tests for the NodeType enum."""

    def test_member_count(self) -> None:
        assert len(NodeType) == 4

    def test_string_coercion(self) -> None:
        assert str(NodeType.LLM_CALL) == "NodeType.LLM_CALL"
        assert NodeType.LLM_CALL.value == "llm_call"

    def test_is_str_subclass(self) -> None:
        assert isinstance(NodeType.TOOL_EXEC, str)


# ---------------------------------------------------------------------------
# TestNodeDefinition
# ---------------------------------------------------------------------------


class TestNodeDefinition:
    """Tests for the NodeDefinition model."""

    def test_defaults(self) -> None:
        node = NodeDefinition(name="n1", type=NodeType.LLM_CALL)
        assert node.config == {}
        assert node.description is None

    def test_extra_field_forbidden(self) -> None:
        with pytest.raises(ValidationError):
            NodeDefinition(name="n1", type=NodeType.LLM_CALL, bogus="x")

    def test_full_construction(self) -> None:
        node = NodeDefinition(
            name="step1",
            type=NodeType.TOOL_EXEC,
            config={"command": "echo", "args": ["hi"]},
            description="Echoes hi",
        )
        assert node.name == "step1"
        assert node.type is NodeType.TOOL_EXEC
        assert node.config["command"] == "echo"
        assert node.description == "Echoes hi"

    def test_arbitrary_config_dict(self) -> None:
        node = NodeDefinition(
            name="n", type=NodeType.CONDITIONAL, config={"a": [1, 2], "b": {"nested": True}}
        )
        assert node.config["b"]["nested"] is True


# ---------------------------------------------------------------------------
# TestEdgeDefinition
# ---------------------------------------------------------------------------


class TestEdgeDefinition:
    """Tests for the EdgeDefinition model."""

    def test_minimal(self) -> None:
        edge = EdgeDefinition(source="a", target="b")
        assert edge.condition is None

    def test_with_condition(self) -> None:
        edge = EdgeDefinition(source="a", target="b", condition="state.output == 'yes'")
        assert edge.condition == "state.output == 'yes'"

    def test_extra_field_forbidden(self) -> None:
        with pytest.raises(ValidationError):
            EdgeDefinition(source="a", target="b", weight=5)


# ---------------------------------------------------------------------------
# TestWorkflowDefinition
# ---------------------------------------------------------------------------


class TestWorkflowDefinition:
    """Tests for the WorkflowDefinition model."""

    def test_required_fields_validation(self) -> None:
        with pytest.raises(ValidationError):
            WorkflowDefinition()  # type: ignore[call-arg]

    def test_edges_default_empty(self) -> None:
        wf = WorkflowDefinition(
            name="w",
            description="test",
            nodes=[NodeDefinition(name="n1", type=NodeType.LLM_CALL)],
            entry_point="n1",
        )
        assert wf.edges == []

    def test_extra_field_forbidden(self) -> None:
        with pytest.raises(ValidationError):
            WorkflowDefinition(
                name="w",
                description="test",
                nodes=[NodeDefinition(name="n1", type=NodeType.LLM_CALL)],
                entry_point="n1",
                version="1.0",
            )


# ---------------------------------------------------------------------------
# TestWorkflowState
# ---------------------------------------------------------------------------


class TestWorkflowState:
    """Tests for the WorkflowState TypedDict."""

    def test_total_false_accepts_subset(self) -> None:
        state: WorkflowState = {"current_node": "start"}
        assert state["current_node"] == "start"
        assert "messages" not in state
