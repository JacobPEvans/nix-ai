#
# MLX Module — CLI Tools & Environment
#
# All home.packages and home.sessionVariables for the MLX module.
# Includes: vllm-mlx wrapper, mlx CLI tools, benchmark suite, health check.
#
{
  config,
  lib,
  pkgs,
  mlxShared,
  ...
}:
let
  inherit (mlxShared)
    cfg
    vllmMlxPkg
    apiUrl
    ;
in
{
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
      MLX_SAFETY_OVERHEAD = toString cfg.safetyOverheadGb;
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

      # ======================================================================
      # Pre-flight Memory Check
      # ======================================================================

      # mlx-preflight — validate model fits in memory before loading
      (pkgs.writeShellApplication {
        name = "mlx-preflight";
        runtimeInputs = with pkgs; [ coreutils ];
        text = builtins.readFile ./scripts/mlx-preflight.sh;
      })

      # ======================================================================
      # Benchmark Suite (with OOM safety wrappers)
      # ======================================================================

      # mlx-bench — vllm-mlx throughput/latency benchmark (pre-flight protected)
      (pkgs.writeShellApplication {
        name = "mlx-bench";
        runtimeInputs = [ vllmMlxPkg ];
        text = builtins.readFile ./scripts/mlx-bench-safe.sh;
      })

      # mlx-bench-engine — engine benchmark with cache/batching knobs (pre-flight protected)
      (pkgs.writeShellApplication {
        name = "mlx-bench-engine";
        runtimeInputs = [ vllmMlxPkg ];
        text = builtins.readFile ./scripts/mlx-bench-engine-safe.sh;
      })

      # mlx-bench-raw — raw MLX prefill + decode tok/s (pre-flight protected, ulimit capped)
      (pkgs.writeShellApplication {
        name = "mlx-bench-raw";
        runtimeInputs = with pkgs; [ uv ];
        text = builtins.readFile ./scripts/mlx-bench-raw-safe.sh;
      })

      # mlx-eval — accuracy evaluation against the live vllm-mlx server API
      (pkgs.writeShellScriptBin "mlx-eval" ''
        exec ${pkgs.uv}/bin/uvx --from "lm-eval[api]" lm-eval run \
          --model local-chat-completions \
          --model_args "base_url=''${MLX_API_URL:-${apiUrl}},model=''${MLX_DEFAULT_MODEL:-${cfg.defaultModel}},tokenizer_backend=None,tokenized_requests=False" \
          --apply_chat_template \
          "$@"
      '')

      # ======================================================================
      # Health Check
      # ======================================================================

      # mlx-wait — poll /v1/models until the server is ready (closes #254)
      (pkgs.writeShellApplication {
        name = "mlx-wait";
        runtimeInputs = with pkgs; [ curl ];
        text = ''
          timeout=''${1:-120}
          elapsed=0
          while ! curl -sf "${apiUrl}/models" > /dev/null; do
            sleep 2
            elapsed=$((elapsed + 2))
            if [ "$elapsed" -ge "$timeout" ]; then
              echo "Timed out waiting for vllm-mlx after ''${timeout}s" >&2
              exit 1
            fi
          done
          echo "vllm-mlx ready (''${elapsed}s)"
        '';
      })

      # ======================================================================
      # Model Inventory
      # ======================================================================

      # mlx-models — list all downloaded models with memory fit status
      (pkgs.writeShellApplication {
        name = "mlx-models";
        runtimeInputs = with pkgs; [
          coreutils
          curl
          jq
        ];
        text = builtins.readFile ./scripts/mlx-models.sh;
      })
    ];
  };
}
