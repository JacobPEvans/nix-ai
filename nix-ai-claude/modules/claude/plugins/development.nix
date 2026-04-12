# Development Plugins - Terraform/Nix/Python/Shell + selected marketplace plugins

{
  lib,
  jacobpevans-cc-plugins,
  ...
}:

let
  # ============================================================================
  # JacobPEvans Personal Plugins - Auto-discovered from flake input
  # ============================================================================
  # Plugins from `jacobpevans-cc-plugins` are discovered and enabled automatically.
  # The list of plugins is determined by the repository contents at flake update time.
  jacobpevansPlugins =
    let
      entries = builtins.readDir jacobpevans-cc-plugins;
      # Plugin directories: exclude dotfiles, regular files, and known non-plugin dirs
      nonPluginDirs = [
        "docs"
        "schemas"
        ".claude-plugin"
        ".github"
        "scripts"
        "tests"
      ];
      isPluginDir =
        name: type:
        type == "directory"
        && !(lib.hasPrefix "." name)
        && !(builtins.elem name nonPluginDirs)
        && builtins.pathExists "${jacobpevans-cc-plugins}/${name}/.claude-plugin/plugin.json";
      pluginNames = builtins.attrNames (lib.filterAttrs isPluginDir entries);
    in
    lib.genAttrs (map (name: "${name}@jacobpevans-cc-plugins") pluginNames) (_: true);
in
{
  enabledPlugins = jacobpevansPlugins // {
    # ========================================================================
    # Claude Code Workflows - Core Development Tools
    # ========================================================================

    # Backend (Python, Shell)
    "backend-development@claude-code-workflows" = true;

    # Testing
    "unit-testing@claude-code-workflows" = true;
    "tdd-workflows@claude-code-workflows" = true;

    # Code Quality
    "code-refactoring@claude-code-workflows" = true;
    "codebase-cleanup@claude-code-workflows" = true;

    # Agent Orchestration (user requested)
    "agent-orchestration@claude-code-workflows" = true;

    # Observability - Keep distributed-tracing and slo-implementation, exclude prometheus/grafana
    "observability-monitoring@claude-code-workflows" = true;

    # Python Development (Django/FastAPI with 5 specialized skills)
    "python-development@claude-code-workflows" = true;

    # Full-Stack Orchestration (multi-agent workflows coordinating 7+ agents)
    "full-stack-orchestration@claude-code-workflows" = true;

    # Developer Essentials (common dev tools and utilities)
    "developer-essentials@claude-code-workflows" = true;

    # Performance Testing & Review (analysis and test coverage review)
    "performance-testing-review@claude-code-workflows" = true;

    # ========================================================================
    # Note: Claude Code Workflows plugins contain multiple skills
    # ========================================================================
    # We enable the plugin (e.g., backend-development), which loads all its skills.
    # Skills within plugins (like cqrs-implementation, event-store-design) cannot be
    # individually disabled - they come with the parent plugin.

    # ========================================================================
    # Claude Skills Marketplace - Individual Plugins
    # ========================================================================
    # Claude Skills has individual plugins (not suites)

    # API Design & Implementation
    "api-design-principles@claude-skills" = true;
    "rest-api-design@claude-skills" = true;
    "graphql-implementation@claude-skills" = true;
    "websocket-implementation@claude-skills" = true;

    # Testing
    "playwright@claude-skills" = true;
    "vitest-testing@claude-skills" = true;
    "jest-generator@claude-skills" = true;

    # Security
    "vulnerability-scanning@claude-skills" = true;
    "csrf-protection@claude-skills" = true;
    "xss-prevention@claude-skills" = true;

    # Data & Recommendations
    "recommendation-engine@claude-skills" = true;
    "sql-query-optimization@claude-skills" = true;

    # Authentication
    "better-auth@claude-skills" = true;
    "oauth-implementation@claude-skills" = true;
  };
}
