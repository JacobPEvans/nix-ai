# Claude Code Module Options
#
# All configuration options for the unified Claude Code module.
# Cross-platform: no Darwin-specific code here.
{ lib, ... }:

with lib;

let
  # Reusable submodule types
  marketplaceModule = types.submodule {
    options = {
      source = mkOption {
        type = types.submodule {
          options = {
            type = mkOption {
              type = types.enum [
                "git"
                "github"
                "local"
              ];
              default = "git";
            };
            url = mkOption { type = types.str; };
          };
        };
      };
      flakeInput = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Flake input for Nix-managed (immutable) plugins";
      };
    };
  };

  componentModule = types.submodule {
    options = {
      name = mkOption { type = types.str; };
      source = mkOption { type = types.path; };
    };
  };

  mcpServerModule = types.submodule {
    options = {
      type = mkOption {
        type = types.enum [
          "stdio"
          "sse"
          "http"
        ];
        default = "stdio";
      };
      command = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      args = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
      env = mkOption {
        type = types.attrsOf types.str;
        default = { };
      };
      url = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      headers = mkOption {
        type = types.attrsOf types.str;
        default = { };
      };
      disabled = mkOption {
        type = types.bool;
        default = false;
      };
    };
  };

  hookType = types.nullOr (types.either types.path types.lines);

in
{
  options.programs.claude = {
    enable = lib.mkEnableOption "Claude Code configuration";

    # Plugins
    plugins = {
      marketplaces = mkOption {
        type = types.attrsOf marketplaceModule;
        default = { };
      };
      enabled = mkOption {
        type = types.attrsOf types.bool;
        default = { };
      };
      allowRuntimeInstall = mkOption {
        type = types.bool;
        default = true;
      };
    };

    # Commands
    commands = {
      fromFlakeInputs = mkOption {
        type = types.listOf componentModule;
        default = [ ];
      };
      local = mkOption {
        type = types.attrsOf types.path;
        default = { };
      };
      fromLiveRepo = mkOption {
        type = types.nullOr types.path;
        default = null;
      };
      liveRepoCommands = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
    };

    # Agents
    agents = {
      fromFlakeInputs = mkOption {
        type = types.listOf componentModule;
        default = [ ];
      };
      local = mkOption {
        type = types.attrsOf types.path;
        default = { };
      };
    };

    # Skills
    skills = {
      fromFlakeInputs = mkOption {
        type = types.listOf componentModule;
        default = [ ];
      };
      local = mkOption {
        type = types.attrsOf types.path;
        default = { };
      };
    };

    # Hooks (Phase 2 - not yet implemented)
    # These options are declared for future hook support.
    # Implementation will generate ~/.claude/hooks/ scripts.
    hooks = {
      preToolUse = mkOption {
        type = hookType;
        default = null;
      };
      postToolUse = mkOption {
        type = hookType;
        default = null;
      };
      userPromptSubmit = mkOption {
        type = hookType;
        default = null;
      };
      stop = mkOption {
        type = hookType;
        default = null;
      };
      subagentStop = mkOption {
        type = hookType;
        default = null;
      };
      sessionStart = mkOption {
        type = hookType;
        default = null;
      };
      sessionEnd = mkOption {
        type = hookType;
        default = null;
      };
    };

    # MCP Servers
    mcpServers = mkOption {
      type = types.attrsOf mcpServerModule;
      default = { };
    };

    # API Key Helper (for headless authentication)
    # Requires ~/.config/bws/.env with Bitwarden/Claude API key env vars.
    # bws_helper.py performs minimal validation — see it for required vars.
    apiKeyHelper = {
      enable = lib.mkEnableOption "API key helper for headless Claude authentication";

      scriptPath = mkOption {
        type = types.str;
        default = ".local/bin/claude-api-key-helper";
        description = "Path (relative to home) where the API key helper script is installed";
      };
    };

    # Agent teams: coordinate multiple Claude Code instances
    # See: https://code.claude.com/docs/en/agent-teams
    teammateMode = mkOption {
      type = types.enum [
        "auto"
        "in-process"
        "tmux"
      ];
      default = "auto";
      description = ''
        Display mode for agent team teammates.
        - "auto": split panes if already in tmux, in-process otherwise
        - "in-process": all teammates in main terminal (Shift+Up/Down to navigate)
        - "tmux": force split-pane mode (requires tmux)
      '';
    };

    # Auto-update channel for Claude Code binary
    autoUpdatesChannel = mkOption {
      type = types.enum [
        "stable"
        "latest"
      ];
      default = "latest";
      description = ''
        Release channel for Claude Code binary updates.
        - "latest": newest releases immediately (default upstream)
        - "stable": ~1 week delay, fewer regressions
      '';
    };

    # Show turn duration in UI
    showTurnDuration = mkOption {
      type = types.bool;
      default = false;
      description = "Show how long each turn takes in the Claude Code UI";
    };

    # Remote Control auto-start (Feb 2026 feature)
    # Stored in ~/.claude.json (global config) via home.activation.
    # See: https://code.claude.com/docs/en/remote-control
    remoteControlAtStartup = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Enable Remote Control for all sessions automatically.
        null = leave unmanaged (Claude Code default is false).
      '';
    };

    model = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Override the default model. Accepts aliases ("opus", "sonnet",
        "haiku", "opusplan") or full names ("claude-opus-4-6").
        null = account-tier default. See: https://code.claude.com/docs/en/model-config
      '';
    };

    effortLevel = mkOption {
      type = types.enum [
        "low"
        "medium"
        "high"
      ];
      default = "high";
      description = ''
        Adaptive reasoning effort for Opus 4.6.
        - "high": Full reasoning (upstream default)
        - "medium": Balanced cost/quality for routine tasks
        - "low": Minimal reasoning, fastest and cheapest
        Override per-session via /model effort slider.
      '';
    };

    attribution = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Commit attribution trailer. Set commit = \"(claude)\" for minimal attribution.";
    };

    # Settings
    settings = {
      # Extended thinking mode
      alwaysThinkingEnabled = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable Claude's extended thinking capability by default.
          When enabled, Claude can reason through complex problems step-by-step.
          Token budget controlled by MAX_THINKING_TOKENS in env.
        '';
      };

      # Session management
      cleanupPeriodDays = mkOption {
        type = types.int;
        default = 14;
        description = ''
          Sessions inactive longer than this period are deleted.
          Default upstream is 30, we use 14 to reduce storage.
        '';
      };

      # Permissions
      permissions = {
        allow = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Commands and operations to auto-approve without prompting";
        };
        deny = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Commands and operations to permanently block";
        };
        ask = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Commands and operations requiring user confirmation";
        };
      };

      additionalDirectories = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Directories accessible to Claude Code without prompts";
        example = [
          "~/projects"
          "~/Documents"
          "~/.config"
        ];
      };

      # Environment variables for Claude Code
      # See: https://code.claude.com/docs/en/settings
      env = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = ''
          Environment variables passed to Claude Code.
          See: https://code.claude.com/docs/en/settings
        '';
        example = {
          MAX_THINKING_TOKENS = "16000";
          CLAUDE_CODE_MAX_OUTPUT_TOKENS = "16000";
        };
      };

      schemaUrl = mkOption {
        type = types.str;
        default = "https://json.schemastore.org/claude-code-settings.json";
        description = "JSON schema URL for settings validation";
      };

      # Sandbox configuration (Dec 2025 feature)
      # Provides filesystem/network isolation for untrusted codebases
      sandbox = {
        enabled = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Enable sandbox mode for filesystem/network isolation.
            Useful when working in untrusted codebases.
          '';
        };
        autoAllowBashIfSandboxed = mkOption {
          type = types.bool;
          default = true;
          description = ''
            Automatically allow bash commands when sandboxed.
            Safe because sandbox prevents destructive operations.
          '';
        };
        excludedCommands = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Commands to exclude from sandbox restrictions";
          example = [
            "git"
            "nix"
            "darwin-rebuild"
          ];
        };
      };
    };

    # Status Line (supports claude-code-statusline)
    statusLine = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };
      script = mkOption {
        type = types.nullOr types.lines;
        default = null;
      };
      enhanced = {
        enable = mkOption {
          type = types.bool;
          default = false;
        };
        source = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Flake input path to claude-code-statusline repo";
        };
        configFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Path to Config.toml for local/full display (defaults to examples/Config.toml from source)";
        };
        mobileConfigFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Path to minimal Config.toml for SSH/mobile terminals (single-line display)";
        };
        # Internal: package built by statusline.nix, used by settings.nix
        package = mkOption {
          type = types.nullOr types.package;
          default = null;
          internal = true;
          description = "Internal: built statusline package";
        };
      };
    };

    # Feature Flags
    features = {
      pluginSchemaVersion = mkOption {
        type = types.int;
        default = 1;
      };
      experimental = mkOption {
        type = types.attrsOf types.bool;
        default = { };
      };
    };
  };
}
