"""LangGraph Workflow Engine for declarative multi-node AI workflows.

Translates YAML WorkflowDefinitions into executable LangGraph StateGraphs.

Node types:
  - llm_call: Invoke an OpenAI-compatible LLM endpoint
  - tool_exec: Execute a configured shell command/tool.
    **Warning**: This can execute arbitrary code and should only be used
    with trusted workflow definitions.
  - human_input: Pause execution and record pending human review
  - conditional: Route to different nodes based on state values
"""

from __future__ import annotations

import logging
from pathlib import Path
from typing import Any

from orchestrator.common import load_yaml_file
from orchestrator.workflows.models import (
    EdgeDefinition,
    NodeDefinition,
    NodeType,
    WorkflowDefinition,
    WorkflowState,
)
from orchestrator.workflows.nodes import NODE_FACTORIES

# Re-export models so existing ``from orchestrator.workflows.engine import …``
# statements continue to work without modification.
__all__ = [
    "EdgeDefinition",
    "NodeDefinition",
    "NodeType",
    "WorkflowDefinition",
    "WorkflowEngine",
    "WorkflowState",
]

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Optional LangGraph import
# ---------------------------------------------------------------------------
try:
    from langgraph.graph import END, StateGraph

    _LANGGRAPH_AVAILABLE = True
except ImportError:  # pragma: no cover
    _LANGGRAPH_AVAILABLE = False
    StateGraph = None  # type: ignore[assignment,misc]
    END = "__end__"  # type: ignore[assignment]
    logger.warning("langgraph not installed — WorkflowEngine.build_graph() will raise")


# ---------------------------------------------------------------------------
# Workflow Engine
# ---------------------------------------------------------------------------


class WorkflowEngine:
    """Translates WorkflowDefinition objects into executable LangGraph graphs."""

    def __init__(self, *, checkpointing: bool = False, db_path: str = ":memory:") -> None:
        self.checkpointing = checkpointing
        self.db_path = db_path
        self._checkpointer = None

        if checkpointing:
            try:
                from langgraph.checkpoint.sqlite import SqliteSaver

                self._checkpointer = SqliteSaver.from_conn_string(db_path)
                logger.info("Checkpointing enabled at %s", db_path)
            except ImportError:
                logger.warning("langgraph[sqlite] not installed — checkpointing disabled")

    def load_workflow(self, path: str | Path) -> WorkflowDefinition:
        """Parse a YAML file into a WorkflowDefinition."""
        data = load_yaml_file(path)
        return self.load_workflow_from_dict(data)

    def load_workflow_from_dict(self, data: dict[str, Any]) -> WorkflowDefinition:
        """Parse a dict into a WorkflowDefinition."""
        return WorkflowDefinition.model_validate(data)

    def build_graph(self, workflow: WorkflowDefinition) -> Any:
        """Translate a WorkflowDefinition into a compiled LangGraph StateGraph."""
        if not _LANGGRAPH_AVAILABLE:
            msg = "langgraph is not installed — run: pip install langgraph"
            raise ImportError(msg)

        node_names = {n.name for n in workflow.nodes}

        if workflow.entry_point not in node_names:
            msg = (
                f"entry_point '{workflow.entry_point}' is not defined in nodes: "
                f"{sorted(node_names)}"
            )
            raise ValueError(msg)

        graph = StateGraph(WorkflowState)

        # Validate edges and group by source
        edges_by_source: dict[str, list[EdgeDefinition]] = {}
        for edge in workflow.edges:
            for attr, label in [("source", edge.source), ("target", edge.target)]:
                if label not in node_names:
                    msg = (
                        f"Edge references unknown {attr} node '{label}'. "
                        f"Known nodes: {sorted(node_names)}"
                    )
                    raise ValueError(msg)
            edges_by_source.setdefault(edge.source, []).append(edge)

        # Add nodes
        for node_def in workflow.nodes:
            factory = NODE_FACTORIES.get(node_def.type)
            if factory is None:
                msg = f"Unknown node type: {node_def.type}"
                raise ValueError(msg)
            graph.add_node(node_def.name, factory(node_def))

        # Wire edges
        for node_def in workflow.nodes:
            outgoing = edges_by_source.get(node_def.name, [])

            if node_def.type == NodeType.CONDITIONAL:
                self._wire_conditional(graph, node_def, node_names)
            elif node_def.type == NodeType.HUMAN_INPUT:
                # human_input nodes are always terminal: they set pending_human_input=True
                # and halt the graph so the caller can resume after obtaining human input.
                # Any outgoing edges in the YAML are intentionally ignored here.
                graph.add_edge(node_def.name, END)
            elif outgoing:
                for edge in outgoing:
                    graph.add_edge(node_def.name, edge.target)
            else:
                graph.add_edge(node_def.name, END)

        graph.set_entry_point(workflow.entry_point)

        compile_kwargs: dict[str, Any] = {}
        if self._checkpointer is not None:
            compile_kwargs["checkpointer"] = self._checkpointer

        return graph.compile(**compile_kwargs)

    @staticmethod
    def _wire_conditional(
        graph: Any, node_def: NodeDefinition, node_names: set[str]
    ) -> None:
        """Add conditional edges for a routing node."""
        cfg = node_def.config
        condition_key = cfg.get("condition_key", "")
        true_target = cfg.get("true_target", "")
        false_target = cfg.get("false_target", "")

        for target_name in (true_target, false_target):
            if target_name and target_name not in node_names:
                msg = (
                    f"Conditional node '{node_def.name}' references "
                    f"unknown target '{target_name}'"
                )
                raise ValueError(msg)

        def _make_router(key: str, t_target: str, f_target: str):  # noqa: ANN202
            def _router(state: WorkflowState) -> str:
                meta = state.get("metadata", {})
                if meta.get(key) or state.get(key):  # type: ignore[call-overload]
                    return t_target or END
                return f_target or END

            return _router

        router_fn = _make_router(condition_key, true_target, false_target)
        path_map: dict[str, str] = {}
        if true_target:
            path_map[true_target] = true_target
        if false_target:
            path_map[false_target] = false_target
        graph.add_conditional_edges(node_def.name, router_fn, path_map)

    def execute(self, workflow: WorkflowDefinition, input_state: dict[str, Any]) -> dict[str, Any]:
        """Build and run a workflow graph with the given initial state."""
        compiled = self.build_graph(workflow)

        initial: WorkflowState = {
            "messages": input_state.get("messages", []),
            "current_node": "",
            "metadata": input_state.get("metadata", {}),
            "output": input_state.get("output", None),
            "pending_human_input": False,
            "human_input_prompt": "",
        }

        invoke_kwargs: dict[str, Any] = {}
        if self.checkpointing and self._checkpointer is not None:
            invoke_kwargs["config"] = {"configurable": {"thread_id": workflow.name}}

        result = compiled.invoke(initial, **invoke_kwargs)
        return dict(result)
