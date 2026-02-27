{
  config,
  lib,
  ...
}:
#
# Ollama Configuration Module
#
# Manages Ollama LLM runtime environment variables and settings.
# Models are stored on dedicated APFS volume: /Volumes/Ollama/models
#
# Environment variables: https://github.com/ollama/ollama/blob/main/docs/faq.md#how-do-i-configure-ollama-server
#
let
  cfg = config.programs.ollama;
in
{
  # ============================================================================
  # Configuration Options
  # ============================================================================
  options.programs.ollama = {
    modelsVolume = lib.mkOption {
      type = lib.types.str;
      default = "/Volumes/Ollama";
      description = "Path to the dedicated APFS volume where Ollama models are stored";
    };
  };

  config = {
    # ============================================================================
    # Ollama Environment Variables
    # ============================================================================

    home.sessionVariables = {
      # ========================================================================
      # Model Storage
      # ========================================================================
      # Location where Ollama stores downloaded models
      # Default: ~/.ollama/models
      # Current: ${cfg.modelsVolume}/models (692GB+ on dedicated APFS volume)
      OLLAMA_MODELS = "${cfg.modelsVolume}/models";

      # ========================================================================
      # Performance & Memory Settings
      # ========================================================================

      # Context window size (tokens)
      # Default: 2048
      # Higher values allow longer conversations but use more memory
      # Popular values: 4096, 8192, 16384, 32768
      OLLAMA_CONTEXT_LENGTH = "8192";

      # How long to keep models loaded in memory after last use
      # Default: 5m
      # Format: duration (e.g., "30s", "5m", "1h", "24h", "-1" for infinite)
      # "-1" keeps models always loaded (faster subsequent requests, more memory)
      OLLAMA_KEEP_ALIVE = "1h";

      # Maximum number of parallel model requests
      # Default: 1 (sequential processing)
      # Higher values allow concurrent requests but increase memory usage
      # Popular values: 1, 2, 4
      # OLLAMA_MAX_QUEUE = "1";

      # Number of layers to offload to GPU
      # Default: -1 (all layers if GPU available)
      # Set to 0 to disable GPU, or specific number for partial offload
      # OLLAMA_NUM_GPU = "-1";

      # Number of threads for CPU computation
      # Default: auto-detected (usually CPU core count)
      # OLLAMA_NUM_THREADS = "8";

      # ========================================================================
      # Network & API Settings
      # ========================================================================

      # Host and port for Ollama API server
      # Default: 127.0.0.1:11434
      # Format: "host:port" or ":port" for all interfaces
      # Examples: "127.0.0.1:11434", "0.0.0.0:11434", ":11434"
      # OLLAMA_HOST = "127.0.0.1:11434";

      # Allowed CORS origins for API requests
      # Default: not set (localhost only)
      # Examples: "*" (all), "http://localhost:*", "https://example.com"
      # OLLAMA_ORIGINS = "*";

      # Enable debug logging
      # Default: not set (info level)
      # Set to "1" or "true" for verbose debugging
      # OLLAMA_DEBUG = "0";

      # ========================================================================
      # Advanced Settings
      # ========================================================================

      # Directory for temporary files during model loading
      # Default: system temp directory
      # OLLAMA_TMPDIR = "/tmp/ollama";

      # Flash attention - memory-efficient attention mechanism
      # Reduces VRAM usage significantly for long contexts (useful for 8k+ tokens)
      # Default: auto-detected based on GPU capability
      # Set to "1" to force enable (recommended for Apple Silicon)
      # Set to "0" to disable (if experiencing issues with specific models)
      # OLLAMA_FLASH_ATTENTION = "1";

      # KV cache type
      # Default: "f16" (float16)
      # Options: "f32" (float32), "f16" (float16), "q8_0", "q4_0"
      # Lower precision uses less memory but may reduce quality
      # OLLAMA_KV_CACHE_TYPE = "f16";

      # Runner directory (model execution binaries)
      # Default: ~/.ollama/runners
      # OLLAMA_RUNNERS_DIR = "${config.home.homeDirectory}/.ollama/runners";

      # Disable model file verification
      # Default: not set (verification enabled)
      # Set to "1" to skip SHA256 verification (faster but less safe)
      # OLLAMA_NOPRUNE = "0";

      # ========================================================================
      # Metal (Apple Silicon) Specific
      # ========================================================================

      # Metal GPU selection (macOS only)
      # Default: auto-selected
      # Set to specific GPU index if multiple GPUs
      # OLLAMA_METAL_GPU = "0";
    };

    # ============================================================================
    # SSH Keys for Remote Ollama (if used)
    # ============================================================================
    # Preserve existing SSH keys in ~/.ollama/
    # These are NOT managed by Nix - kept as-is from manual setup
    # Files: ~/.ollama/id_ed25519, ~/.ollama/id_ed25519.pub

    # ============================================================================
    # Symlink Configuration
    # ============================================================================
    # Ollama models on dedicated APFS volume
    # CRITICAL: 692GB+ of models - NEVER delete ${cfg.modelsVolume}
    home.file.".ollama/models".source =
      config.lib.file.mkOutOfStoreSymlink "${cfg.modelsVolume}/models";

    # ============================================================================
    # LaunchAgent for Auto-Start
    # ============================================================================
    # Start Ollama server on login
    launchd.agents.ollama = {
      enable = true;
      config = {
        Label = "dev.ollama.server";
        ProgramArguments = [
          "/run/current-system/sw/bin/ollama"
          "serve"
        ];
        EnvironmentVariables = {
          OLLAMA_MODELS = "${cfg.modelsVolume}/models";
          OLLAMA_CONTEXT_LENGTH = "8192";
          OLLAMA_KEEP_ALIVE = "1h";
        };
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/Ollama/ollama.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/Ollama/ollama.error.log";
      };
    };
  };
  # ============================================================================
  # Notes
  # ============================================================================
  # - Models stay on /Volumes/Ollama (692GB+, symlinked via home-manager)
  # - Database: ~/Library/Application Support/Ollama/db.sqlite (not managed by Nix)
  # - History: ~/.ollama/history (not managed by Nix)
  # - Nixpkgs version: latest (tracking nixpkgs, currently 0.15.x)
  # - LaunchAgent starts ollama serve on login (auto-restart if crashes)
  # - Logs: ~/Library/Logs/Ollama/ollama.log, ~/Library/Logs/Ollama/ollama.error.log
}
