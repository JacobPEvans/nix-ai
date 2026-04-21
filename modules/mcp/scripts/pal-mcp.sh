# shellcheck shell=bash
# PAL MCP launcher — static config.
#
# Dynamic values exported by pal-models.nix wrapper (Nix-interpolated paths):
#   CUSTOM_MODELS_CONFIG_PATH, CUSTOM_MODEL_NAME, OPENROUTER_MODELS_CONFIG_PATH
#   PAL_LOG_DIR, PAL_MCP_SERVER
#
# Enabled tools: chat, listmodels, clink, consensus
# All other PAL tools disabled — native equivalents exist or the tool is unnecessary.
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
