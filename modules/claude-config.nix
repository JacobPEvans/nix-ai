# Claude Code Configuration Values
#
# Centralized configuration for the programs.claude module.
# Imported by common.nix to keep it clean and high-level.
{
  config,
  lib,
  ai-assistant-instructions,
  marketplaceInputs,
  claude-cookbooks,
  ...
}:

let
  # Import unified permissions from common module
  # This reads from ai-assistant-instructions agentsmd/permissions/
  aiCommon = import ./common { inherit lib config ai-assistant-instructions; };
  inherit (aiCommon) permissions;
  inherit (aiCommon) formatters;

  # Dynamic discovery helper - finds all .md files in a directory
  discoverMarkdownFiles =
    dir:
    let
      files = if builtins.pathExists dir then builtins.readDir dir else { };
      mdFiles = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".md" name) files;
    in
    map (name: lib.removeSuffix ".md" name) (builtins.attrNames mdFiles);

  # Discover commands and agents from configured sources
  # Commands are discovered from claude-cookbooks; agents from both ai-assistant-instructions and claude-cookbooks
  cbCommands = discoverMarkdownFiles "${claude-cookbooks}/.claude/commands";
  aiAgents = discoverMarkdownFiles "${ai-assistant-instructions}/agentsmd/agents";
  cbAgents = discoverMarkdownFiles "${claude-cookbooks}/.claude/agents";

  # Import modular plugin configuration
  # Plugin configuration moved to claude-plugins.nix and organized by category
  # See: modules/home-manager/ai-cli/claude/plugins/*.nix
  claudePlugins = import ./claude-plugins.nix {
    inherit lib marketplaceInputs claude-cookbooks;
  };

  # Extract enabled plugins from modular configuration
  inherit (claudePlugins.pluginConfig) enabledPlugins;

  # Helper to build command/agent entries from discovered names
  mkSourceEntries =
    sourcePath: names:
    map (name: {
      inherit name;
      source = "${sourcePath}/${name}.md";
    }) names;

in
{
  enable = true;

  # API Key Helper for headless authentication (cron jobs, CI/CD)
  # Uses Bitwarden Secrets Manager to securely fetch OAuth token
  # Configuration: ~/.config/bws/.env (see bws-env.example)
  apiKeyHelper = {
    enable = true;
    # scriptPath default: .local/bin/claude-api-key-helper
  };

  # Agent teams display mode (direct settings.json property)
  teammateMode = "auto";

  # Model: opusplan uses Opus for planning, Sonnet for execution
  # See: https://code.claude.com/docs/en/model-config
  model = "opusplan";

  # Release channel: "stable" delays ~1 week to avoid regressions
  autoUpdatesChannel = "stable";

  # Show turn duration in UI for performance visibility
  showTurnDuration = true;

  # Enable Remote Control for all sessions (Feb 2026 feature).
  # Writes remoteControlAtStartup = true into ~/.claude.json via home.activation.
  # Allows monitoring/controlling sessions from claude.ai or the mobile app.
  # Requires a Claude Max subscription; no-op if not logged in.
  remoteControlAtStartup = true;

  effortLevel = "medium";

  # Minimal commit attribution — replaces verbose Co-Authored-By trailer
  # Claude Code appends this string to every commit message automatically
  attribution = {
    commit = "(claude)";
  };

  # Auto-Claude: DISABLED - migrating to ai-workflows repo
  # Module files preserved (guarded by mkIf), will be extracted later
  autoClaude.enable = false;

  # Menu bar: disabled (depends on auto-claude)
  menubar.enable = false;

  plugins = {
    # Marketplaces from modular configuration with flakeInput for Nix symlinks
    # See: modules/home-manager/ai-cli/claude/plugins/marketplaces.nix
    # Adding flakeInput enables Nix to create immutable symlinks instead of runtime downloads
    # All marketplace names match flake input names -- zero special cases
    marketplaces = lib.mapAttrs (
      name: marketplace: marketplace // { flakeInput = marketplaceInputs.${name}; }
    ) claudePlugins.pluginConfig.marketplaces;

    enabled = enabledPlugins;
    # Enable runtime plugin installation from community marketplaces.
    # Nix defines the baseline (official plugins via flake inputs).
    # Claude can dynamically install additional plugins at runtime.
    # Runtime state tracked in ~/.claude/plugins/installed_plugins.json (not Nix-managed).
    allowRuntimeInstall = true;
  };

  commands = {
    # All commands from Nix store (flake inputs) for reproducibility
    fromFlakeInputs = mkSourceEntries "${claude-cookbooks}/.claude/commands" cbCommands;
  };

  agents.fromFlakeInputs =
    (mkSourceEntries "${ai-assistant-instructions}/agentsmd/agents" aiAgents)
    ++ (mkSourceEntries "${claude-cookbooks}/.claude/agents" cbAgents);

  settings = {
    # Extended thinking enabled with token budget controlled via env vars
    alwaysThinkingEnabled = true;

    # Session cleanup (upstream default is 30)
    cleanupPeriodDays = 14;

    # Environment variables for model config and token optimization
    # See: https://code.claude.com/docs/en/settings
    # See: https://code.claude.com/docs/en/model-config
    env = {
      # Model selection: opusplan is set above (Opus for planning, Sonnet for execution).
      # Auto-claude background jobs use their own CLAUDE_MODEL env var (haiku).
      # ANTHROPIC_MODEL = "sonnet"; # Uncomment to override default model via env var
      # CLAUDE_CODE_SUBAGENT_MODEL = "claude-haiku-4-5-20251001"; # Cost control for subagents

      # Explicit model versions (Jan 2026) - pin to known working versions if customization needed
      # ANTHROPIC_DEFAULT_OPUS_MODEL = "claude-opus-4-5-20251101";
      # ANTHROPIC_DEFAULT_SONNET_MODEL = "claude-sonnet-4-5-20250929";
      # ANTHROPIC_DEFAULT_HAIKU_MODEL = "claude-haiku-4-5-20251001";

      # MCP timeout settings (5 minutes) - required for PAL MCP
      MCP_TIMEOUT = "300000";
      MCP_TOOL_TIMEOUT = "300000";

      # Experimental: Agent teams - coordinate multiple Claude Code instances
      # See: https://code.claude.com/docs/en/agent-teams
      CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";

      # Disable 1M token context window models from model picker
      # No native settings.json key exists; env var removes only 1M variants
      CLAUDE_CODE_DISABLE_1M_CONTEXT = "1";

      # DEFAULT VALUES (upstream) - reference only, do not uncomment unless tuning
      # MAX_THINKING_TOKENS = "31999";
      # CLAUDE_CODE_MAX_OUTPUT_TOKENS = "32000";
      # BASH_MAX_OUTPUT_LENGTH = "30000";
      # MAX_MCP_OUTPUT_TOKENS = "25000";
      # SLASH_COMMAND_TOOL_CHAR_BUDGET = "16000";
      # BASH_DEFAULT_TIMEOUT_MS = "120000";  # 2 minutes
      # BASH_MAX_TIMEOUT_MS = "600000";      # 10 minutes
    };

    # Permissions from unified ai-assistant-instructions system
    # Uses common/permissions.nix which reads from agentsmd/permissions/
    # Formatted by common/formatters.nix to Claude Code format
    permissions = {
      allow = formatters.claude.formatAllowed permissions;
      deny = formatters.claude.formatDenied permissions;
      ask = formatters.claude.formatAsk permissions;
    };

    # Additional directories accessible to Claude Code without prompts
    additionalDirectories = [
      "~/"
      "~/.claude/"
      "~/.config/"
    ];

    # Sandbox configuration (Dec 2025 feature)
    # Provides filesystem/network isolation when working in untrusted codebases.
    # Currently disabled - enable when reviewing external code or untrusted repos.
    sandbox = {
      enabled = false;
      autoAllowBashIfSandboxed = true; # Safe because sandbox prevents destructive ops
      excludedCommands = [
        "git"
        "nix"
        "darwin-rebuild"
      ];
    };
  };

  # MCP Servers - deployed to ~/.claude.json via home.activation (see claude/settings.nix).
  # Nix is the sole manager of user-scoped MCP servers; manual `claude mcp add --scope user`
  # entries will be overwritten on next darwin-rebuild switch.
  mcpServers = import ./mcp;

  statusLine = {
    enable = true;
    enhanced = {
      # Disabled: upstream repository no longer available (404)
      # Repository: https://github.com/rz1989s/claude-code-statusline
      enable = false;
      # Full config for local terminal
      # configFile = statuslineConfigFull;
      # Mobile config for SSH sessions (single-line, minimal)
      # mobileConfigFile = statuslineConfigMobile;
    };
  };

  # Hooks: Event-driven automation for Claude Code
  # See: https://code.claude.com/docs/en/hooks
  hooks = {
    # Notify on user input needed (Issue #455)
    # Sends Slack notification when Claude needs input via AskUserQuestion
    # Enables mobile/async workflows
    preToolUse = ./claude/hooks/ask-user-notify.sh;

    # Capture last output for statusline display (Issue #479)
    # Writes compact summary of last tool execution to ~/.cache/claude-last-output.txt
    # Can be read by statusline, tmux, or other display tools
    postToolUse = ./claude/hooks/last-output.sh;

  };
}
