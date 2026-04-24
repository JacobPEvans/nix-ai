# Agent Skills Configuration Module
#
# Declarative configuration for shared cross-tool skills.
# Discovers plugin skills and deploys them to ~/.agents/skills.
{ lib, marketplaceInputs, ... }:

let
  # Discovers SKILL.md files from plugin repos.
  # Pattern: <plugin>/skills/<skill-name>/SKILL.md
  discoverSkills =
    input:
    let
      topDirs = lib.filterAttrs (_: type: type == "directory") (builtins.readDir input);
      pluginSkills =
        pluginName:
        let
          skillsPath = "${input}/${pluginName}/skills";
          hasSkills = builtins.pathExists skillsPath;
          skillDirs =
            if hasSkills then
              lib.filterAttrs (_: type: type == "directory") (builtins.readDir skillsPath)
            else
              { };
        in
        lib.mapAttrsToList
          (skillName: _: {
            name = skillName;
            source = "${skillsPath}/${skillName}/SKILL.md";
          })
          (
            lib.filterAttrs (skillName: _: builtins.pathExists "${skillsPath}/${skillName}/SKILL.md") skillDirs
          );
    in
    lib.concatMap pluginSkills (builtins.attrNames topDirs);

  # Skills from JacobPEvans/claude-code-plugins (tool-agnostic markdown)
  sharedSkills = discoverSkills marketplaceInputs.jacobpevans-cc-plugins;
in
{
  imports = [
    ./options.nix
    ./components.nix

    # Legacy option paths (kept for compatibility during migration).
    (lib.mkRenamedOptionModule
      [
        "programs"
        "codex"
        "skills"
        "fromFlakeInputs"
      ]
      [
        "programs"
        "agentSkills"
        "fromFlakeInputs"
      ]
    )
    (lib.mkRenamedOptionModule
      [
        "programs"
        "codex"
        "skills"
        "local"
      ]
      [
        "programs"
        "agentSkills"
        "local"
      ]
    )
    (lib.mkRenamedOptionModule
      [
        "programs"
        "gemini"
        "skills"
        "fromFlakeInputs"
      ]
      [
        "programs"
        "agentSkills"
        "fromFlakeInputs"
      ]
    )
    (lib.mkRenamedOptionModule
      [
        "programs"
        "gemini"
        "skills"
        "local"
      ]
      [
        "programs"
        "agentSkills"
        "local"
      ]
    )
  ];

  config = {
    programs.agentSkills = {
      enable = lib.mkDefault true;
      fromFlakeInputs = lib.mkDefault sharedSkills;
    };
  };
}
