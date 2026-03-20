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
# MLX is ~2x faster than llama.cpp for token generation on M4 Max with ~50% less memory.
#
# Features:
#   - Always-on LaunchAgent running a default MoE model (~70GB, 10B active)
#   - Foreground model switching (auto-restores default on exit)
#   - CLI tools for quick prompts (mlx) and interactive chat (mlx-chat)
#   - OpenAI-compatible API at http://127.0.0.1:11434/v1
#
# Models stored on dedicated APFS volume: /Volumes/HuggingFace
#
let
  cfg = config.programs.mlx;

  # Central vllm-mlx wrapper — single source of truth for the pinned version.
  # The LaunchAgent needs a Nix store path (not a PATH lookup), so the
  # derivation lives here. Also added to home.packages for CLI access.
  vllmMlxPkg = pkgs.writeShellScriptBin "vllm-mlx" ''
    exec ${pkgs.uv}/bin/uvx --from "vllm-mlx==0.2.6" vllm-mlx "$@"
  '';

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
      default = "mlx-community/Qwen3.5-122B-A10B-4bit";
      description = "Default HuggingFace model to serve via vllm-mlx";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 11434;
      description = "Port for the vllm-mlx API server (avoids conflict with 8080 used by Open WebUI)";
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
      MLX_API_URL = apiUrl;
      MLX_DEFAULT_MODEL = cfg.defaultModel;
      MLX_PORT = toString cfg.port;
      MLX_HOST = cfg.host;
      MLX_HF_HOME = cfg.huggingFaceHome;
    };

    # ==========================================================================
    # CLI Tools
    # ==========================================================================
    home.packages = [
      # vllm-mlx wrapper (on PATH for scripts, store path for LaunchAgent)
      vllmMlxPkg

      # mlx — one-shot prompt (curl + jq, no Python)
      (pkgs.writeShellApplication {
        name = "mlx";
        runtimeInputs = with pkgs; [
          curl
          jq
        ];
        text = builtins.readFile ./scripts/mlx.sh;
      })

      # mlx-switch — foreground model swap, auto-restores default on Ctrl-C
      (pkgs.writeShellApplication {
        name = "mlx-switch";
        runtimeInputs = with pkgs; [
          lsof
          vllmMlxPkg
        ];
        text = builtins.readFile ./scripts/mlx-switch.sh;
      })

      # mlx-default — safety net to restore the default LaunchAgent
      (pkgs.writeShellApplication {
        name = "mlx-default";
        runtimeInputs = with pkgs; [ lsof ];
        text = builtins.readFile ./scripts/mlx-default.sh;
      })

      # mlx-status — show running model, memory, uptime, LaunchAgent state
      (pkgs.writeShellApplication {
        name = "mlx-status";
        runtimeInputs = with pkgs; [
          curl
          jq
          lsof
          bc
        ];
        text = builtins.readFile ./scripts/mlx-status.sh;
      })

      # mlx-chat — interactive multi-turn chat via openai SDK
      (pkgs.writeShellScriptBin "mlx-chat" ''
        exec ${pkgs.uv}/bin/uv run \
          --with "openai==1.82.0" \
          python3 ${./scripts/mlx-chat.py} "$@"
      '')
    ];

    # ==========================================================================
    # LaunchAgent for Auto-Start
    # ==========================================================================
    launchd.agents.vllm-mlx = {
      enable = true;
      config = {
        Label = launchAgentLabel;
        ProgramArguments = [
          (lib.getExe vllmMlxPkg)
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
}
