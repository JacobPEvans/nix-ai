# MCP Servers Configuration
#
# Simple, portable MCP server definitions using standard commands.
# Uses bunx for npm packages (faster than npx, auto-installs).
# Uses binary names for nixpkgs packages (resolved via PATH).
#
# Official MCP Servers: https://github.com/modelcontextprotocol/servers
#
# Note: Servers requiring API keys read them from environment variables.
# Use your secrets manager (Doppler, Keychain, etc.) to inject env vars.

let
  # Official MCP server via bunx — pinned versions for Renovate tracking.
  # Servers NOT FOUND on npm are archived upstream (github.com/modelcontextprotocol/servers-archived).
  # Archived servers use the unpinned helper until replacements are identified.
  official = name: version: {
    command = "bunx";
    args = [ "@modelcontextprotocol/server-${name}@${version}" ];
  };
  # Archived/unpinned — packages no longer published to npm.
  # TODO: audit each against MCP Registry for current replacements
  archived = name: {
    command = "bunx";
    args = [ "@modelcontextprotocol/server-${name}" ];
  };

in
{
  # ================================================================
  # Official Anthropic MCP Servers (via bunx)
  # ================================================================

  everything = official "everything" "2026.1.26";
  fetch = archived "fetch";
  filesystem = official "filesystem" "2026.1.14";
  git = archived "git";
  memory = official "memory" "2026.1.26";
  sequentialthinking = archived "sequentialthinking"; # npm name is "sequential-thinking"
  time = archived "time";
  docker = archived "docker";
  exa = archived "exa" // {
    disabled = true;
  }; # Requires: EXA_API_KEY
  firecrawl = archived "firecrawl" // {
    disabled = true;
  }; # Requires: FIRECRAWL_API_KEY
  cloudflare = archived "cloudflare" // {
    disabled = true;
  }; # Requires: CLOUDFLARE_API_TOKEN
  aws = official "aws-kb-retrieval" "0.6.2"; # Requires: AWS credentials (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION)

  # ================================================================
  # Native nixpkgs packages (binary name, resolved via PATH)
  # ================================================================

  # Terraform - terraform-mcp-server from nixpkgs
  terraform = {
    command = "terraform-mcp-server";
  };

  # GitHub - github-mcp-server from nixpkgs
  # Requires: GITHUB_PERSONAL_ACCESS_TOKEN env var (not yet in Doppler)
  github = {
    command = "github-mcp-server";
    disabled = true;
  };

  # ================================================================
  # Third-party npm packages (via bunx)
  # ================================================================

  # Context7 - provided by context7@claude-plugins-official plugin (see plugins/external.nix).
  # Do NOT define here — the plugin manages its own MCP server lifecycle.

  # ================================================================
  # PAL MCP - Multi-model orchestration
  # ================================================================
  # Provider Abstraction Layer for routing tasks to different AI models
  # Tools (all enabled): chat, thinkdeep, planner, codereview, precommit, debug,
  #   apilookup, challenge, clink, consensus, analyze, refactor, testgen, secaudit,
  #   docgen, tracer
  # See: https://github.com/BeehiveInnovations/pal-mcp-server
  #
  # API keys injected via Doppler (doppler-mcp wrapper):
  #   - GEMINI_API_KEY (Google Gemini — pro, flash models)
  #   - OPENAI_API_KEY (OpenAI — reasoning and chat/codex models)
  #   - OPENROUTER_API_KEY (OpenRouter — unified multi-model access)
  #
  # Non-secret config is set in env below (belongs in Nix, not Doppler).

  # Built as a Nix derivation (modules/mcp/pal-package.nix), installed to PATH.
  # Wrapped with doppler-mcp to inject Doppler secrets at subprocess launch time.
  # Secrets are never written to ~/.claude.json or any file Claude Code can read.
  pal = {
    command = "doppler-mcp";
    args = [ "pal-mcp-server" ];
    env = {
      # Enable ALL PAL tools (default disables: analyze,refactor,testgen,secaudit,docgen,tracer)
      DISABLED_TOOLS = "";
      # 'auto' = PAL picks best available model per-task based on configured API keys.
      # Falls back across providers: OpenAI -> Gemini -> OpenRouter -> MLX.
      # Run PAL's `listmodels` tool for current aliases and providers.
      DEFAULT_MODEL = "auto";
      # Custom API endpoint — MLX inference server (vllm-mlx on port 11434)
      CUSTOM_API_URL = "http://127.0.0.1:11434/v1";
      # MLX timeout tuning (PAL reads from providers/openai_compatible.py)
      CUSTOM_CONNECT_TIMEOUT = "30"; # 30s for localhost MLX (catches stalled server)
      CUSTOM_READ_TIMEOUT = "300"; # 5min for large model inference
      # Conversation limits
      CONVERSATION_TIMEOUT_HOURS = "6";
      MAX_CONVERSATION_TURNS = "50";
      LOG_LEVEL = "INFO";
    };
  };

  # ================================================================
  # HuggingFace MCP - Model/dataset/paper search and documentation
  # ================================================================
  # Community stdio package: https://github.com/shreyaskarnik/huggingface-mcp-server
  # Tools: search models/datasets/spaces/papers, get info, compare models
  # Requires: HF_TOKEN env var (from macOS Keychain via nix-darwin shell init)
  huggingface = {
    command = "uvx";
    args = [
      "--from"
      "huggingface-mcp-server==0.1.0"
      "--with"
      "huggingface-hub==1.10.1"
      "huggingface-mcp-server"
    ];
  };

  # ================================================================
  # Obsidian - NOT IMPLEMENTED
  # ================================================================
  # Decision: Not moving forward with REST API approach since official Obsidian CLI will be released soon.
  # Using Claude Skills plugins for Obsidian integration instead (see plugins/community.nix).
  #
  # If revisited in the future:
  # - Use `uvx mcp-obsidian` (PyPI package)
  # - Requires Obsidian REST API plugin: https://github.com/coddingtonbear/obsidian-local-rest-api
  # - IMPORTANT: Inject OBSIDIAN_API_KEY via secrets manager at runtime (never in Nix store)
  # - Non-secret defaults: OBSIDIAN_HOST=127.0.0.1, OBSIDIAN_PORT=27124

  # ================================================================
  # Database (disabled by default)
  # ================================================================

  postgresql = official "postgres" "0.6.2" // {
    disabled = true;
  };
  sqlite = archived "sqlite" // {
    disabled = true;
  };

  # ================================================================
  # Additional (disabled - specialized use cases)
  # ================================================================

  brave-search = official "brave-search" "0.6.2" // {
    disabled = true;
  };
  # Google Workspace - Gmail, Drive, Calendar integration
  # Source: https://github.com/taylorwilsdon/google_workspace_mcp
  # Requires: GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET env vars (via Doppler)
  # Auth: One-time OAuth browser flow, tokens stored locally
  # Selective tool loading: --tools limits which Google services are exposed
  google-workspace = {
    command = "doppler-mcp";
    args = [
      "uvx"
      "--from"
      "google-workspace-mcp==2.0.1"
      "workspace-mcp"
      "--tools"
      "gmail"
      "drive"
      "calendar"
    ];
  };
  google-maps = official "google-maps" "0.6.2" // {
    disabled = true;
  };
  puppeteer = official "puppeteer" "2025.5.12" // {
    disabled = true;
  };
  slack = official "slack" "2025.4.25" // {
    disabled = true;
  };
  sentry = archived "sentry" // {
    disabled = true;
  };

  # ================================================================
  # Cribl MCP - OrbStack kubernetes-monitoring stack
  # ================================================================
  # Cribl MCP server running in OrbStack k8s cluster (NodePort :30030).
  # Connection will fail when OrbStack k8s is not running — this is expected.
  # See: ~/git/kubernetes-monitoring for the stack configuration.
  # Cribl uses streamable HTTP transport (not SSE).
  # Claude Code supports this natively with type = "http" — no mcp-remote proxy needed.
  # See: https://docs.cribl.io/copilot/cribl-mcp-server/
  cribl = {
    type = "http";
    url = "http://localhost:30030/mcp";
  };
}
