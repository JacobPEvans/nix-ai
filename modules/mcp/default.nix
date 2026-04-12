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
  # bunx helper — command only, args set inline per server so Renovate's
  # regex manager can match literal "@scope/pkg@version" strings in the source.
  bunx = args: {
    command = "bunx";
    inherit args;
  };
in
{
  # ================================================================
  # Official Anthropic MCP Servers (via bunx)
  # ================================================================
  # Versions pinned as literal strings for Renovate regex tracking.
  # Archived servers (no longer on npm) are unpinned until replacements identified.

  everything = bunx [ "@modelcontextprotocol/server-everything@2026.1.26" ];
  fetch = bunx [ "@modelcontextprotocol/server-fetch" ]; # archived
  filesystem = bunx [ "@modelcontextprotocol/server-filesystem@2026.1.14" ];
  git = bunx [ "@modelcontextprotocol/server-git" ]; # archived
  memory = bunx [ "@modelcontextprotocol/server-memory@2026.1.26" ];
  sequentialthinking = bunx [ "@modelcontextprotocol/server-sequential-thinking" ]; # archived
  time = bunx [ "@modelcontextprotocol/server-time" ]; # archived
  docker = bunx [ "@modelcontextprotocol/server-docker" ]; # archived
  exa = bunx [ "@modelcontextprotocol/server-exa" ] // {
    disabled = true;
  }; # archived; Requires: EXA_API_KEY
  firecrawl = bunx [ "@modelcontextprotocol/server-firecrawl" ] // {
    disabled = true;
  }; # archived; Requires: FIRECRAWL_API_KEY
  cloudflare = bunx [ "@modelcontextprotocol/server-cloudflare" ] // {
    disabled = true;
  }; # archived; Requires: CLOUDFLARE_API_TOKEN
  aws = bunx [ "@modelcontextprotocol/server-aws-kb-retrieval@0.6.2" ]; # Requires: AWS credentials

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
      # Disable PAL tools that have native Claude Code / Bifrost equivalents,
      # plus drop `version` (no functional value). Only `clink` (parallel
      # multi-model) and `consensus` (multi-model voting) remain enabled —
      # neither has a Bifrost equivalent, and the canonical
      # `modules/claude/rules/pal-mcp-policy.md` rule scopes PAL's
      # availability-check protocol to exactly those two tools. The
      # audit matrix that decided this split was posted as a comment on
      # JacobPEvans/nix-ai#450.
      DISABLED_TOOLS = builtins.concatStringsSep "," [
        "chat"
        "thinkdeep"
        "planner"
        "listmodels"
        "codereview"
        "precommit"
        "debug"
        "analyze"
        "tracer"
        "refactor"
        "testgen"
        "secaudit"
        "docgen"
        "apilookup"
        "challenge"
        "version"
      ];
      # 'auto' = PAL picks a model alias per-task; Bifrost then routes the
      # resulting request to the right provider based on the model name.
      # `listmodels` is disabled (see above) — query available models via
      # `curl http://localhost:30080/v1/models` instead.
      DEFAULT_MODEL = "auto";
      # Route PAL through Bifrost AI gateway (localhost:30080) instead of
      # vllm-mlx directly. Bifrost fans out to OpenAI/Gemini/OpenRouter/MLX
      # based on model name. Tracked: JacobPEvans/nix-ai#450
      CUSTOM_API_URL = "http://localhost:30080/v1";
      # OpenAI-compatible client timeouts — applies to whichever backend
      # CUSTOM_API_URL points at (Bifrost in this config).
      CUSTOM_CONNECT_TIMEOUT = "30"; # 30s connect — catches stalled upstream
      CUSTOM_READ_TIMEOUT = "300"; # 5min read — accommodates large model inference
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
  # Obsidian - Integrated via Claude Code Plugin (not MCP)
  # ================================================================
  # The official Obsidian CLI (v1.8+, ships in Obsidian.app) provides 80+
  # commands. Integration uses the kepano/obsidian-skills Claude Code plugin
  # which teaches Claude to invoke the CLI via Bash (auto-approved in
  # ai-assistant-instructions permissions). No MCP server needed — the skill
  # provides equivalent structured access without an additional layer.
  #
  # If MCP is desired later: bunx [ "mcp-obsidian-cli@1.2.0" ] (stonematt)

  # ================================================================
  # Codex CLI — OpenAI coding agent MCP server
  # ================================================================
  # Native `codex mcp-server` (stdio). Structured MCP tool access to Codex.
  # The codex@openai-codex plugin provides skill-based /codex commands.
  # Installed via Homebrew cask (see nix-darwin modules/darwin/homebrew.nix).
  codex = {
    command = "codex";
    args = [ "mcp-server" ];
  };

  # ================================================================
  # Database (disabled by default)
  # ================================================================

  postgresql = bunx [ "@modelcontextprotocol/server-postgres@0.6.2" ] // {
    disabled = true;
  };
  sqlite = bunx [ "@modelcontextprotocol/server-sqlite" ] // {
    disabled = true;
  }; # archived

  # ================================================================
  # Additional (disabled - specialized use cases)
  # ================================================================

  brave-search = bunx [ "@modelcontextprotocol/server-brave-search@0.6.2" ] // {
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
  google-maps = bunx [ "@modelcontextprotocol/server-google-maps@0.6.2" ] // {
    disabled = true;
  };
  puppeteer = bunx [ "@modelcontextprotocol/server-puppeteer@2025.5.12" ] // {
    disabled = true;
  };
  slack = bunx [ "@modelcontextprotocol/server-slack@2025.4.25" ] // {
    disabled = true;
  };
  sentry = bunx [ "@modelcontextprotocol/server-sentry" ] // {
    disabled = true;
  }; # archived

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

  # ================================================================
  # Bifrost AI Gateway - OrbStack kubernetes monitoring stack
  # ================================================================
  # Bifrost AI gateway running in OrbStack k8s cluster (NodePort :30080).
  # Multi-provider routing: OpenAI, Anthropic, Gemini, OpenRouter, local MLX.
  # OpenAI-compatible API at /v1, MCP server at /mcp.
  # Connection will fail when OrbStack k8s is not running — this is expected.
  # Provider API keys are managed by the Doppler K8s Operator inside the cluster
  # (no doppler-mcp wrapper needed — secrets never reach the MCP client process).
  #
  # Diagnostics use native tools — no custom CLI exists or is needed:
  #   claude mcp list | grep bifrost          # MCP connection state
  #   make -C ~/git/orbstack-kubernetes/main status      # pod / service / sts state
  #   make -C ~/git/orbstack-kubernetes/main test-smoke  # asserts /health, /v1/models, NodePort
  #
  # See: https://github.com/maximhq/bifrost
  bifrost = {
    type = "http";
    url = "http://localhost:30080/mcp";
  };
}
