#!/usr/bin/env bash
# PAL MCP launcher — static config.
#
# Dynamic values exported by pal-models.nix before this script is sourced:
#   CUSTOM_MODELS_CONFIG_PATH       — path to PAL custom models JSON
#   CUSTOM_MODEL_NAME               — default local model (tracks programs.mlx.defaultModel)
#   OPENROUTER_MODELS_CONFIG_PATH   — path to OpenRouter models JSON
#   PAL_LOG_DIR                     — writable log directory
#   PAL_MCP_SERVER                  — absolute Nix store path to pal-mcp-server binary
#
# Enabled tools: chat, listmodels, clink, consensus (see pal-mcp-policy.md).
# All other PAL tools disabled — native Claude Code / Bifrost equivalents exist.
# See: JacobPEvans/nix-ai#450 for the full audit matrix.
export DISABLED_TOOLS="thinkdeep,planner,codereview,precommit,debug,analyze,tracer,refactor,testgen,secaudit,docgen,apilookup,challenge,version"
# 'auto' = PAL picks model alias per-task; Bifrost routes to the right provider.
export DEFAULT_MODEL="auto"
# Route through Bifrost AI gateway — fans out to OpenAI/Gemini/OpenRouter/MLX.
export CUSTOM_API_URL="http://localhost:30080/v1"
# OpenAI-compatible client timeouts (connect / read)
export CUSTOM_CONNECT_TIMEOUT="30"
export CUSTOM_READ_TIMEOUT="300"
# Conversation limits
export CONVERSATION_TIMEOUT_HOURS="6"
export MAX_CONVERSATION_TURNS="50"
export LOG_LEVEL="INFO"
exec doppler-mcp "$PAL_MCP_SERVER" "$@"
