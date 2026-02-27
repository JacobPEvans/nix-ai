# Claude Code Components
#
# Manages commands, agents, and skills from various sources:
# - Flake inputs (immutable, from Nix store)
# - Local files (direct symlinks)
# - Live repos (mkOutOfStoreSymlink for updates without rebuild)
{ config, lib, ... }:

let
  cfg = config.programs.claude;

  # Helper to create file entries from component list
  # Uses force = true to overwrite any existing files (git provides version control)
  mkComponentFiles =
    type: components:
    builtins.listToAttrs (
      map (c: {
        name = ".claude/${type}s/${c.name}.md";
        value = {
          inherit (c) source;
          force = true;
        };
      }) components
    );

  # Helper for live repo symlinks (if ever needed for writable repos)
  # Note: Returns empty set when repo is null. Called with cfg.commands.fromLiveRepo
  # which is null by default - all content comes from Nix store (flake inputs)
  # Uses force = true to overwrite any existing files
  mkLiveRepoSymlinks =
    type: repo: names:
    if repo == null then
      { }
    else
      builtins.listToAttrs (
        map (name: {
          name = ".claude/${type}s/${name}.md";
          value = {
            source = config.lib.file.mkOutOfStoreSymlink "${repo}/.claude/${type}s/${name}.md";
            force = true;
          };
        }) names
      );

  # Helper for local file symlinks
  # Uses force = true to overwrite any existing files
  mkLocalSymlinks =
    type: locals:
    lib.mapAttrs' (
      name: path:
      lib.nameValuePair ".claude/${type}s/${name}.md" {
        source = path;
        force = true;
      }
    ) locals;

in
{
  config = lib.mkIf cfg.enable {
    home.file =
      # Commands
      mkComponentFiles "command" cfg.commands.fromFlakeInputs
      // mkLocalSymlinks "command" cfg.commands.local
      // mkLiveRepoSymlinks "command" cfg.commands.fromLiveRepo cfg.commands.liveRepoCommands
      # Agents
      // mkComponentFiles "agent" cfg.agents.fromFlakeInputs
      // mkLocalSymlinks "agent" cfg.agents.local
      # Skills
      // mkComponentFiles "skill" cfg.skills.fromFlakeInputs
      // mkLocalSymlinks "skill" cfg.skills.local;
  };
}
