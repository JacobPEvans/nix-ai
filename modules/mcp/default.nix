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
  # Official MCP server via bunx (fast, auto-installs)
  official = name: {
    command = "bunx";
    args = [ "@modelcontextprotocol/server-${name}" ];
  };

in
{
  # ================================================================
  # Official Anthropic MCP Servers (via bunx)
  # ================================================================

  everything = official "everything";
  fetch = official "fetch";
  filesystem = official "filesystem";
  git = official "git";
  memory = official "memory";
  sequentialthinking = official "sequentialthinking";
  time = official "time";
  docker = official "docker";
  exa = official "exa";
  firecrawl = official "firecrawl";
  cloudflare = official "cloudflare";
  aws = official "aws-kb-retrieval";

  # ================================================================
  # Native nixpkgs packages (binary name, resolved via PATH)
  # ================================================================

  # Terraform - terraform-mcp-server from nixpkgs
  terraform = {
    command = "terraform-mcp-server";
  };

  # GitHub - github-mcp-server from nixpkgs
  # Requires: GITHUB_PERSONAL_ACCESS_TOKEN env var
  github = {
    command = "github-mcp-server";
  };

  # ================================================================
  # Third-party npm packages (via bunx)
  # ================================================================

  # Context7 - Library documentation lookup
  context7 = {
    command = "bunx";
    args = [ "@context7/mcp-server" ];
  };

  # ================================================================
  # PAL MCP - Multi-model orchestration
  # ================================================================
  # Provider Abstraction Layer for routing tasks to different AI models
  # Tools (all enabled): chat, thinkdeep, planner, codereview, precommit, debug,
  #   apilookup, challenge, clink, consensus, analyze, refactor, testgen, secaudit,
  #   docgen, tracer
  # See: https://github.com/BeehiveInnovations/pal-mcp-server
  #
  # API keys injected via Doppler (doppler-mcp wrapper, at least one required):
  #   - GEMINI_API_KEY (Google Gemini)
  #   - OPENROUTER_API_KEY (OpenRouter - unified model access)
  #   - OLLAMA_HOST (local Ollama server URL)
  #
  # Non-secret config is set in env below (belongs in Nix, not Doppler).

  # TODO: Pin to a specific commit once the project publishes tagged releases.
  # Pulling from HEAD on every invocation means a compromised upstream can execute
  # arbitrary code with access to AI provider API keys and other secrets.
  #
  # Wrapped with doppler-mcp to inject Doppler secrets at subprocess launch time.
  # Secrets are never written to ~/.claude.json or any file Claude Code can read.
  pal = {
    command = "doppler-mcp";
    args = [
      "uvx"
      "--from"
      "git+https://github.com/BeehiveInnovations/pal-mcp-server.git"
      "pal-mcp-server"
    ];
    env = {
      # Enable ALL PAL tools (default disables: analyze,refactor,testgen,secaudit,docgen,tracer)
      DISABLED_TOOLS = "";
      # Conversation limits
      CONVERSATION_TIMEOUT_HOURS = "6";
      MAX_CONVERSATION_TURNS = "50";
      LOG_LEVEL = "INFO";
    };
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

  postgresql = official "postgres" // {
    disabled = true;
  };
  sqlite = official "sqlite" // {
    disabled = true;
  };

  # ================================================================
  # Additional (disabled - specialized use cases)
  # ================================================================

  brave-search = official "brave-search" // {
    disabled = true;
  };
  gdrive = official "gdrive" // {
    disabled = true;
  };
  google-maps = official "google-maps" // {
    disabled = true;
  };
  puppeteer = official "puppeteer" // {
    disabled = true;
  };
  slack = official "slack" // {
    disabled = true;
  };
  sentry = official "sentry" // {
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
