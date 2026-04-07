#!/usr/bin/env bash
# Agent Framework Evaluation — run all 4 frameworks back-to-back.
#
# Each script is self-contained with ephemeral deps via `uv run --with`.
# No changes to pyproject.toml or uv.lock required.
#
# Usage: ./examples/evaluations/run_all.sh
# Prereqs: vllm-mlx running at localhost:11434 with tool-call-parser enabled

set -euo pipefail
cd "$(dirname "$0")/../.."

# Create test fixture
echo "The quick brown fox jumps over the lazy dog. This sentence contains every letter of the English alphabet and is commonly used as a typing exercise." > /tmp/eval-test.txt

echo "============================================================"
echo "  Agent Framework Evaluation — $(date '+%Y-%m-%d %H:%M:%S')"
echo "  Model: ${MLX_DEFAULT_MODEL:?MLX_DEFAULT_MODEL not set}"
echo "  Server: ${MLX_API_URL:-http://127.0.0.1:11434/v1}"
echo "============================================================"

echo ""
echo ">>> 1/4: LangGraph (baseline — existing dependency)"
uv run examples/evaluations/eval_langgraph.py 2>&1

echo ""
echo ">>> 2/4: Qwen-Agent (official Qwen framework)"
uv run --with "qwen-agent>=0.0.14,soundfile>=0.13.0" examples/evaluations/eval_qwen_agent.py 2>&1

echo ""
echo ">>> 3/4: smolagents (HuggingFace)"
uv run --with "smolagents>=1.0.0" examples/evaluations/eval_smolagents.py 2>&1

echo ""
echo ">>> 4/4: Google ADK"
uv run --with "google-adk>=0.5.0" examples/evaluations/eval_google_adk.py 2>&1

echo ""
echo "============================================================"
echo "  Evaluation complete — $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"
