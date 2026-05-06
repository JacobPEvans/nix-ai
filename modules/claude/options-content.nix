# Claude Code Module — Content discovery options
#
# How Claude Code finds plugins, commands, agents, skills, and rules.
# Supports three sources: marketplace plugins (via flake inputs), Nix store
# components (fromFlakeInputs), and ad-hoc local paths (local).
{ lib, ... }:
let
  inherit (import ./options-types.nix { inherit lib; }) marketplaceModule componentModule;
in
{
  options.programs.claude = {
    plugins = {
      marketplaces = lib.mkOption {
        type = lib.types.attrsOf marketplaceModule;
        default = { };
      };
      enabled = lib.mkOption {
        type = lib.types.attrsOf lib.types.bool;
        default = { };
      };
      allowRuntimeInstall = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
    };

    commands = {
      fromFlakeInputs = lib.mkOption {
        type = lib.types.listOf componentModule;
        default = [ ];
      };
      local = lib.mkOption {
        type = lib.types.attrsOf lib.types.path;
        default = { };
      };
      fromLiveRepo = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
      };
      liveRepoCommands = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
    };

    agents = {
      fromFlakeInputs = lib.mkOption {
        type = lib.types.listOf componentModule;
        default = [ ];
      };
      local = lib.mkOption {
        type = lib.types.attrsOf lib.types.path;
        default = { };
      };
    };

    skills = {
      fromFlakeInputs = lib.mkOption {
        type = lib.types.listOf componentModule;
        default = [ ];
      };
      local = lib.mkOption {
        type = lib.types.attrsOf lib.types.path;
        default = { };
      };
    };

    # Global rules (loaded every session regardless of project)
    rules = {
      fromFlakeInputs = lib.mkOption {
        type = lib.types.listOf componentModule;
        default = [ ];
      };
      local = lib.mkOption {
        type = lib.types.attrsOf lib.types.path;
        default = { };
      };
    };
  };
}
