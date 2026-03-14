{
  config,
  lib,
  pkgs,
  ...
}:
#
# MLX Inference Server Module
#
# Manages the vllm-mlx inference server as a macOS LaunchAgent for Apple Silicon.
# MLX is ~2x faster than Ollama for token generation on M4 Max with ~50% less memory.
#
# Features:
#   - Always-on LaunchAgent running a default ~15GB model
#   - Foreground model switching (auto-restores default on exit)
#   - CLI tools for quick prompts (mlx) and interactive chat (mlx-chat)
#   - OpenAI-compatible API at http://127.0.0.1:11435/v1
#
# Models stored on dedicated APFS volume: /Volumes/HuggingFace
#
let
  cfg = config.programs.mlx;

  # Central vllm-mlx wrapper definition. This is the single source of truth —
  # the LaunchAgent ProgramArguments needs a Nix store path, not a PATH lookup,
  # so the derivation lives here. CLI tools (mlx-switch) also reference it directly.
  vllmMlxBin = "${lib.getExe (
    pkgs.writeShellScriptBin "vllm-mlx" ''
      exec ${pkgs.uv}/bin/uvx --from "vllm-mlx==0.2.6" vllm-mlx "$@"
    ''
  )}";

  apiUrl = "http://${cfg.host}:${toString cfg.port}/v1";
  launchAgentLabel = "dev.vllm-mlx.server";
in
{
  # ============================================================================
  # Configuration Options
  # ============================================================================
  options.programs.mlx = {
    enable = lib.mkEnableOption "MLX inference server via vllm-mlx";

    defaultModel = lib.mkOption {
      type = lib.types.str;
      default = "mlx-community/Qwen3.5-27B-4bit";
      description = "Default HuggingFace model to serve (~15GB for Qwen3.5-27B-4bit)";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 11435;
      description = "Port for the vllm-mlx API server (avoids Ollama 11434, Open WebUI 8080)";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address for the vllm-mlx API server";
    };

    huggingFaceHome = lib.mkOption {
      type = lib.types.str;
      default = "/Volumes/HuggingFace";
      description = "Path to HuggingFace model cache (dedicated APFS volume)";
    };
  };

  # ============================================================================
  # Implementation
  # ============================================================================
  config = lib.mkIf cfg.enable {
    # ==========================================================================
    # Environment Variables
    # ==========================================================================
    home.sessionVariables = {
      # Discovery endpoint for other tools (PAL MCP, agents, scripts)
      MLX_API_URL = apiUrl;
      # Default model identifier for CLI tools
      MLX_DEFAULT_MODEL = cfg.defaultModel;
    };

    # ==========================================================================
    # CLI Tools
    # ==========================================================================
    home.packages = [
      # ----------------------------------------------------------------------
      # mlx - One-shot prompt CLI
      # ----------------------------------------------------------------------
      # Usage: mlx "What is the capital of France?"
      # Usage: mlx --model mlx-community/Qwen3-8B-4bit "Hello"
      # Usage: echo "summarize this" | mlx
      (pkgs.writeShellScriptBin "mlx" ''
        set -euo pipefail

        model="''${MLX_DEFAULT_MODEL:-${cfg.defaultModel}}"
        api_url="''${MLX_API_URL:-${apiUrl}}"
        stream=false

        # Parse flags
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --model|-m)
              model="$2"
              shift 2
              ;;
            --stream|-s)
              stream=true
              shift
              ;;
            --help|-h)
              echo "Usage: mlx [OPTIONS] [PROMPT]"
              echo ""
              echo "One-shot prompt against the local MLX inference server."
              echo ""
              echo "Options:"
              echo "  -m, --model MODEL   Model to query (default: \$MLX_DEFAULT_MODEL)"
              echo "  -s, --stream        Stream output tokens"
              echo "  -h, --help          Show this help"
              echo ""
              echo "Prompt can also be piped via stdin:"
              echo "  echo 'hello' | mlx"
              exit 0
              ;;
            *)
              break
              ;;
          esac
        done

        # Build prompt from args or stdin
        if [[ $# -gt 0 ]]; then
          prompt="$*"
        elif [[ ! -t 0 ]]; then
          prompt="$(cat)"
        else
          echo "Error: No prompt provided. Use: mlx \"your prompt\" or pipe via stdin." >&2
          exit 1
        fi

        # Build JSON payload
        payload=$(${pkgs.jq}/bin/jq -n \
          --arg model "$model" \
          --arg prompt "$prompt" \
          --argjson stream "$stream" \
          '{model: $model, messages: [{role: "user", content: $prompt}], stream: $stream}')

        if [[ "$stream" == "true" ]]; then
          ${pkgs.curl}/bin/curl -sfN "$api_url/chat/completions" \
            -H "Content-Type: application/json" \
            -d "$payload" \
          | while IFS= read -r line; do
              # Skip empty lines and [DONE] marker
              [[ -z "$line" || "$line" == "data: [DONE]" ]] && continue
              # Strip "data: " prefix from SSE
              json="''${line#data: }"
              token=$(echo "$json" | ${pkgs.jq}/bin/jq -r '.choices[0].delta.content // empty' 2>/dev/null)
              [[ -n "$token" ]] && printf '%s' "$token"
            done
          echo ""
        else
          ${pkgs.curl}/bin/curl -sf "$api_url/chat/completions" \
            -H "Content-Type: application/json" \
            -d "$payload" \
          | ${pkgs.jq}/bin/jq -r '.choices[0].message.content'
        fi
      '')

      # ----------------------------------------------------------------------
      # mlx-switch - Foreground model switcher (auto-restores default on exit)
      # ----------------------------------------------------------------------
      # Usage: mlx-switch mlx-community/Qwen3-235B-A22B-4bit
      (pkgs.writeShellScriptBin "mlx-switch" ''
        set -euo pipefail

        if [[ $# -lt 1 ]]; then
          echo "Usage: mlx-switch <model>"
          echo ""
          echo "Switch to a different MLX model in the foreground."
          echo "The default model auto-restores when you press Ctrl-C."
          echo ""
          echo "Examples:"
          echo "  mlx-switch mlx-community/Qwen3-235B-A22B-4bit"
          echo "  mlx-switch mlx-community/Qwen2.5-Coder-32B-Instruct-4bit"
          exit 1
        fi

        model="$1"
        port="${toString cfg.port}"
        host="${cfg.host}"
        label="${launchAgentLabel}"

        restore_default() {
          echo ""
          echo "Restoring default model..."
          # Kill any vllm-mlx still holding the port
          ${pkgs.lsof}/bin/lsof -ti :"$port" 2>/dev/null | xargs kill 2>/dev/null || true
          sleep 1
          launchctl start "$label" 2>/dev/null || true
          echo "Default model restored via LaunchAgent."
        }

        trap restore_default EXIT

        echo "Stopping default LaunchAgent..."
        launchctl stop "$label" 2>/dev/null || true

        # Wait for port to be free
        for i in $(seq 1 30); do
          if ! ${pkgs.lsof}/bin/lsof -ti :"$port" >/dev/null 2>&1; then
            break
          fi
          sleep 1
        done

        if ${pkgs.lsof}/bin/lsof -ti :"$port" >/dev/null 2>&1; then
          echo "Error: Port $port still in use after 30s. Killing remaining processes..." >&2
          ${pkgs.lsof}/bin/lsof -ti :"$port" | xargs kill -9 2>/dev/null || true
          sleep 1
        fi

        echo "Starting $model on port $port (foreground)..."
        echo "Press Ctrl-C to restore default model (${cfg.defaultModel})"
        echo ""

        HF_HOME="${cfg.huggingFaceHome}" ${vllmMlxBin} serve "$model" \
          --port "$port" \
          --host "$host"
      '')

      # ----------------------------------------------------------------------
      # mlx-default - Safety net to restore the default LaunchAgent
      # ----------------------------------------------------------------------
      # Usage: mlx-default
      (pkgs.writeShellScriptBin "mlx-default" ''
        set -euo pipefail

        port="${toString cfg.port}"
        label="${launchAgentLabel}"

        echo "Killing any vllm-mlx process on port $port..."
        ${pkgs.lsof}/bin/lsof -ti :"$port" 2>/dev/null | xargs kill 2>/dev/null || true
        sleep 2

        # Force-kill if still lingering
        if ${pkgs.lsof}/bin/lsof -ti :"$port" >/dev/null 2>&1; then
          ${pkgs.lsof}/bin/lsof -ti :"$port" | xargs kill -9 2>/dev/null || true
          sleep 1
        fi

        echo "Restarting default LaunchAgent ($label)..."
        launchctl start "$label" 2>/dev/null || true

        echo "Default model restored: ${cfg.defaultModel}"
      '')

      # ----------------------------------------------------------------------
      # mlx-status - Show current MLX server state
      # ----------------------------------------------------------------------
      # Usage: mlx-status
      (pkgs.writeShellScriptBin "mlx-status" ''
        set -euo pipefail

        port="${toString cfg.port}"
        api_url="''${MLX_API_URL:-${apiUrl}}"
        label="${launchAgentLabel}"

        echo "=== MLX Inference Server Status ==="
        echo ""

        # Check if port is listening
        if ${pkgs.lsof}/bin/lsof -ti :"$port" >/dev/null 2>&1; then
          pid=$(${pkgs.lsof}/bin/lsof -ti :"$port" | head -1)
          echo "Status:  running (PID $pid)"

          # Get process uptime
          ps_out=$(ps -o etime= -p "$pid" 2>/dev/null || echo "unknown")
          echo "Uptime:  $ps_out"

          # Get memory usage
          mem=$(ps -o rss= -p "$pid" 2>/dev/null || echo "0")
          mem_gb=$(echo "scale=1; $mem / 1048576" | bc 2>/dev/null || echo "?")
          echo "Memory:  ''${mem_gb}GB"

          # Query model info
          model_info=$(${pkgs.curl}/bin/curl -sf "$api_url/models" 2>/dev/null || echo "")
          if [[ -n "$model_info" ]]; then
            model_id=$(echo "$model_info" | ${pkgs.jq}/bin/jq -r '.data[0].id // "unknown"' 2>/dev/null)
            echo "Model:   $model_id"
          else
            echo "Model:   (API not responding)"
          fi

          echo "Port:    $port"
          echo "API:     $api_url"
        else
          echo "Status:  stopped"
          echo "Port:    $port (not listening)"
        fi

        echo ""

        # LaunchAgent status
        if launchctl list "$label" >/dev/null 2>&1; then
          echo "LaunchAgent: loaded ($label)"
        else
          echo "LaunchAgent: not loaded ($label)"
        fi
      '')

      # ----------------------------------------------------------------------
      # mlx-chat - Interactive multi-turn chat via openai SDK
      # ----------------------------------------------------------------------
      # Usage: mlx-chat "Tell me about MLX"
      # Usage: mlx-chat --system "You are a tagger" "Tag this note"
      # Usage: cat file.md | mlx-chat "summarize this"
      # Usage: mlx-chat --json "Extract entities from: Hello World"
      (pkgs.writeShellScriptBin "mlx-chat" ''
        exec ${pkgs.uv}/bin/uvx \
          --from openai \
          --with openai \
          python3 ${./mlx-chat.py} "$@"
      '')
    ];

    # ==========================================================================
    # LaunchAgent for Auto-Start
    # ==========================================================================
    # Start vllm-mlx server on login with default model
    launchd.agents.vllm-mlx = {
      enable = true;
      config = {
        Label = launchAgentLabel;
        ProgramArguments = [
          vllmMlxBin
          "serve"
          cfg.defaultModel
          "--port"
          (toString cfg.port)
          "--host"
          cfg.host
        ];
        RunAtLoad = true;
        KeepAlive = true;
        EnvironmentVariables = {
          HF_HOME = cfg.huggingFaceHome;
        };
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/vllm-mlx/vllm-mlx.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/vllm-mlx/vllm-mlx.error.log";
      };
    };
  };
  # ============================================================================
  # Notes
  # ============================================================================
  # - MLX models cached at /Volumes/HuggingFace (dedicated APFS volume)
  # - LaunchAgent starts vllm-mlx serve on login (auto-restart if crashes)
  # - Logs: ~/Library/Logs/vllm-mlx/vllm-mlx.log
  # - API: http://127.0.0.1:11435/v1 (OpenAI-compatible)
  # - CLI: mlx "prompt", mlx-chat for interactive, mlx-switch for model swap
  # - Model switching is foreground-only: Ctrl-C always restores default
}
