# Claude Code Plugins Configuration
#
# Manages official Anthropic plugins and commands from:
# - anthropics/claude-code (plugin marketplace)
# - anthropics/claude-cookbooks (commands and agents)
#
# Strategy:
# 1. Configure plugin marketplaces and enabled plugins (modular structure)
# 2. Copy useful commands/agents from claude-cookbooks to ~/.claude/
#
# Plugin Configuration:
# - Marketplaces and plugins are defined in modules/home-manager/ai-cli/claude/plugins/
# - Organized by category: official, community, infrastructure, development, business
# - See claude/plugins/default.nix for the complete structure
#
# Migration Notes:
# - Removed: "review-pr-ci" - replaced by code-review plugin (/code-review)

{
  lib,
  marketplaceInputs,
  claude-cookbooks,
  ...
}:

let
  # Import modular plugin configuration
  pluginModules = import ./claude/plugins/default.nix {
    inherit lib marketplaceInputs;
  };

  # Commands from claude-cookbooks to install globally
  # These are copied directly to ~/.claude/commands/
  cookbookCommands = [
    "review-issue" # GitHub issue review
    "notebook-review" # Jupyter notebook review
    "model-check" # Model validation
    "link-review" # Link verification
  ];

  # Agents from claude-cookbooks to install globally
  # These are copied to ~/.claude/agents/
  cookbookAgents = [
    "code-reviewer" # Senior code review agent
  ];
in
{
  # Plugin marketplace and enabled plugins configuration
  # Merged into settings.json by claude.nix
  pluginConfig = {
    inherit (pluginModules) marketplaces enabledPlugins;
  };

  # Home-manager file entries for commands and agents
  # These copy files from the claude-cookbooks repo to ~/.claude/
  #
  # Helper function to reduce duplication
  # Creates file entries for a given type (command/agent) from a list of names
  files =
    let
      mkCookbookFileEntries =
        type: names:
        builtins.listToAttrs (
          map (name: {
            name = ".claude/${type}s/${name}.md";
            value = {
              source = "${claude-cookbooks}/.claude/${type}s/${name}.md";
            };
          }) names
        );
    in
    mkCookbookFileEntries "command" cookbookCommands // mkCookbookFileEntries "agent" cookbookAgents;
}
