# External Third-Party Plugins
#
# These are officially listed third-party MCP integrations distributed via
# the claude-plugins-official marketplace (anthropics/claude-plugins-official).
#
# Format: "plugin-name@claude-plugins-official"
#
# All external plugins are listed here for visibility.
# Enable as needed - most require authentication setup.
#
# Source: https://github.com/anthropics/claude-plugins-official/tree/main/external_plugins

_:

{
  enabledPlugins = {
    # =========================================================================
    # Project Management
    # =========================================================================

    # Asana - task and project management
    # Requires: Asana API token
    "asana@claude-plugins-official" = false;

    # Linear - issue tracking and project management
    # Requires: Linear API key
    "linear@claude-plugins-official" = false;

    # =========================================================================
    # Version Control & Code
    # =========================================================================

    # GitHub - repository management, issues, PRs
    # Requires: GITHUB_PERSONAL_ACCESS_TOKEN env var
    # Use gh CLI instead (more reliable)
    "github@claude-plugins-official" = true;

    # GitLab - repository management, issues, merge requests
    # Requires: GitLab API token
    "gitlab@claude-plugins-official" = false;

    # Greptile - AI-powered codebase search
    # Requires: Greptile API key
    "greptile@claude-plugins-official" = true;

    # =========================================================================
    # Documentation & Context
    # =========================================================================

    # Context7 - up-to-date library documentation lookup
    # Requires: CONTEXT7_API_KEY env var (optional, for higher rate limits)
    "context7@claude-plugins-official" = true;

    # =========================================================================
    # Backend & Infrastructure
    # =========================================================================

    # Firebase - Google Firebase platform integration
    # Requires: Firebase credentials
    "firebase@claude-plugins-official" = false;

    # Supabase - open source Firebase alternative
    # Requires: Supabase API key
    "supabase@claude-plugins-official" = false;

    # Stripe - payment processing integration
    # Requires: Stripe API key
    "stripe@claude-plugins-official" = false;

    # =========================================================================
    # Testing & Automation
    # =========================================================================

    # Playwright - browser automation and testing
    # Requires: Playwright installed
    "playwright@claude-plugins-official" = true;

    # =========================================================================
    # Frameworks
    # =========================================================================

    # Laravel Boost - Laravel PHP framework integration
    # Requires: Laravel project
    "laravel-boost@claude-plugins-official" = false;

    # =========================================================================
    # Communication
    # =========================================================================

    # Slack - team communication integration
    # Requires: Slack OAuth authentication
    "slack@claude-plugins-official" = true;

    # =========================================================================
    # Other
    # =========================================================================

    # Serena - AI memory and context management
    # Requires: Serena API key
    "serena@claude-plugins-official" = false;
  };
}
