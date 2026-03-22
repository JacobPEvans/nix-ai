#!/usr/bin/env bash
# MLX vs Claude Opus 4.6 — Comprehensive Benchmark Suite
#
# Tests 8 capability dimensions with ~50 individual tests.
# Expected runtime: ~1 hour on Apple Silicon with vllm-mlx.
#
# Usage: cd mlx-server/benchmarks && ./run_all.sh
# Prereqs: vllm-mlx running at localhost:11434

set -euo pipefail
cd "$(dirname "$0")"

RESULTS_DIR="${BENCHMARK_RESULTS_DIR:-/tmp/mlx-benchmark-results}"
rm -rf "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR"

API_URL="${MLX_API_URL:-http://127.0.0.1:11434/v1}"
MODEL="${MLX_DEFAULT_MODEL:-mlx-community/Qwen3.5-122B-A10B-4bit}"
UV_DEPS="openai>=1.82.0,jsonschema>=4.0,pyyaml"

echo "============================================================"
echo "  MLX vs Claude Opus 4.6 — Capability Benchmark Suite"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "  Model: $MODEL"
echo "  Server: $API_URL"
echo "============================================================"

# Pre-flight: verify server is responding
echo ""
echo "Pre-flight check..."
if ! curl -sf "$API_URL/models" > /dev/null 2>&1; then
    echo "ERROR: MLX server not responding at $API_URL"
    echo "Start with: launchctl start dev.vllm-mlx.server"
    echo "Or run: mlx-status"
    exit 1
fi
echo "Server OK — $(curl -sf "$API_URL/models" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["data"][0]["id"])' 2>/dev/null || echo 'unknown model')"

START=$(date +%s)

echo ""
echo ">>> 1/8: Reasoning & Logic (~10 min)"
echo "------------------------------------------------------------"
uv run --with "$UV_DEPS" test_reasoning.py

echo ""
echo ">>> 2/8: Code Generation (~15 min)"
echo "------------------------------------------------------------"
uv run --with "$UV_DEPS" test_code_generation.py

echo ""
echo ">>> 3/8: Code Review & Bug Detection (~10 min)"
echo "------------------------------------------------------------"
uv run --with "$UV_DEPS" test_code_review.py

echo ""
echo ">>> 4/8: Tool Use Chains (~10 min)"
echo "------------------------------------------------------------"
uv run --with "$UV_DEPS" test_tool_use.py

echo ""
echo ">>> 5/8: Instruction Following (~5 min)"
echo "------------------------------------------------------------"
uv run --with "$UV_DEPS" test_instruction_following.py

echo ""
echo ">>> 6/8: Structured Output (~5 min)"
echo "------------------------------------------------------------"
uv run --with "$UV_DEPS" test_structured_output.py

echo ""
echo ">>> 7/8: Long Context (~5 min)"
echo "------------------------------------------------------------"
uv run --with "$UV_DEPS" test_long_context.py

echo ""
echo ">>> 8/8: Conversation Coherence (~5 min)"
echo "------------------------------------------------------------"
uv run --with "$UV_DEPS" test_conversation.py

echo ""
echo ">>> Generating Report"
echo "------------------------------------------------------------"
uv run --with "$UV_DEPS" report.py

END=$(date +%s)
ELAPSED=$(( END - START ))
echo ""
echo "============================================================"
echo "  Suite complete — $(date '+%Y-%m-%d %H:%M:%S')"
echo "  Total runtime: $(( ELAPSED / 60 ))m $(( ELAPSED % 60 ))s"
echo "  Results: $RESULTS_DIR/"
echo "  Report: $RESULTS_DIR/report.md"
echo "============================================================"
