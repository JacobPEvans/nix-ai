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
import subprocess
from enum import Enum
from pathlib import Path
from typing import Any, TypedDict

from pydantic import BaseModel, ConfigDict, Field

from orchestrator.common import load_yaml_file

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
# Pydantic models
# ---------------------------------------------------------------------------


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


# ---------------------------------------------------------------------------
# Graph state
# ---------------------------------------------------------------------------


class WorkflowState(TypedDict, total=False):
    """Shared state passed between all nodes in a workflow graph."""

    messages: list[dict[str, str]]
    current_node: str
    metadata: dict[str, Any]
    output: Any
    pending_human_input: bool
    human_input_prompt: str


# ---------------------------------------------------------------------------
# Node function factories
# ---------------------------------------------------------------------------


def _error_state(
    state: WorkflowState, node_name: str, msg: str, returncode: int, error_type: str
) -> WorkflowState:
    """Build a state dict for a node error."""
    return {
        **state,
        "current_node": node_name,
        "output": msg,
        "metadata": {
            **state.get("metadata", {}),
            f"{node_name}_returncode": returncode,
            f"{node_name}_error": error_type,
        },
    }


def _make_passthrough_node(node_def: NodeDefinition):  # noqa: ANN202
    """Return a no-op node function used as a routing placeholder."""

    def _node(state: WorkflowState) -> WorkflowState:
        return {**state, "current_node": node_def.name}

    _node.__name__ = node_def.name
    return _node


def _make_llm_call_node(node_def: NodeDefinition):  # noqa: ANN202
    """Return a node function that calls an OpenAI-compatible LLM endpoint."""
    cfg = node_def.config
    endpoint = cfg.get("endpoint", "http://127.0.0.1:11435/v1")
    model = cfg.get("model", "qwen3-coder:30b")
    system_prompt = cfg.get("system_prompt", "You are a helpful assistant.")
    temperature = float(cfg.get("temperature", 0.7))
    max_tokens = int(cfg.get("max_tokens", 4096))

    # Create client once at factory time instead of per-invocation
    from openai import OpenAI

    client = OpenAI(base_url=endpoint, api_key="not-needed")

    def _node(state: WorkflowState) -> WorkflowState:
        messages: list[dict[str, str]] = [{"role": "system", "content": system_prompt}]
        messages.extend(state.get("messages", []))

        logger.debug("llm_call node '%s' → %s/%s", node_def.name, endpoint, model)
        response = client.chat.completions.create(
            model=model,
            messages=messages,  # type: ignore[arg-type]
            temperature=temperature,
            max_tokens=max_tokens,
        )
        reply = response.choices[0].message.content or ""

        updated_messages = list(state.get("messages", []))
        updated_messages.append({"role": "assistant", "content": reply})

        return {
            **state,
            "messages": updated_messages,
            "current_node": node_def.name,
            "output": reply,
        }

    _node.__name__ = node_def.name
    return _node


def _make_tool_exec_node(node_def: NodeDefinition):  # noqa: ANN202
    """Return a node function that executes a configured shell command."""
    cfg = node_def.config
    command = cfg.get("command", "echo")
    args = [str(a) for a in cfg.get("args", [])]
    timeout = int(cfg.get("timeout", 30))

    def _node(state: WorkflowState) -> WorkflowState:
        cmd = [command, *args]
        logger.debug("tool_exec node '%s' → %s", node_def.name, cmd)
        try:
            result = subprocess.run(  # noqa: S603
                cmd, capture_output=True, text=True, timeout=timeout,
            )
        except FileNotFoundError:
            return _error_state(
                state, node_def.name,
                f"tool_exec '{node_def.name}': command not found: {command}",
                127, "command_not_found",
            )
        except subprocess.TimeoutExpired:
            return _error_state(
                state, node_def.name,
                f"tool_exec '{node_def.name}': timed out after {timeout}s",
                -1, "timeout",
            )
        output = result.stdout.strip() if result.returncode == 0 else result.stderr.strip()
        return {
            **state,
            "current_node": node_def.name,
            "output": output,
            "metadata": {
                **state.get("metadata", {}),
                f"{node_def.name}_returncode": result.returncode,
            },
        }

    _node.__name__ = node_def.name
    return _node


def _make_human_input_node(node_def: NodeDefinition):  # noqa: ANN202
    """Return a node that records a pending human-input request."""
    prompt = node_def.config.get("prompt", "Human review required. Please provide input.")

    def _node(state: WorkflowState) -> WorkflowState:
        logger.info("human_input node '%s': %s", node_def.name, prompt)
        return {
            **state,
            "current_node": node_def.name,
            "pending_human_input": True,
            "human_input_prompt": prompt,
        }

    _node.__name__ = node_def.name
    return _node


_NODE_FACTORIES = {
    NodeType.LLM_CALL: _make_llm_call_node,
    NodeType.TOOL_EXEC: _make_tool_exec_node,
    NodeType.HUMAN_INPUT: _make_human_input_node,
    NodeType.CONDITIONAL: _make_passthrough_node,
}


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
            factory = _NODE_FACTORIES.get(node_def.type)
            if factory is None:
                msg = f"Unknown node type: {node_def.type}"
                raise ValueError(msg)
            graph.add_node(node_def.name, factory(node_def))

        # Wire edges
        for node_def in workflow.nodes:
            outgoing = edges_by_source.get(node_def.name, [])

            if node_def.type == NodeType.CONDITIONAL:
                self._wire_conditional(graph, node_def, node_names)
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
