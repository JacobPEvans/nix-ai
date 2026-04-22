# Agent Skills Components
#
# Manages shared skill deployment to ~/.agents/skills.
{ config, lib, ... }:

let
  cfg = config.programs.agentSkills;

  mkSkillFiles =
    components:
    builtins.listToAttrs (
      map (c: {
        name = ".agents/skills/${c.name}/SKILL.md";
        value = {
          inherit (c) source;
          force = true;
        };
      }) components
    );

  mkLocalSkills =
    locals:
    lib.concatMapAttrs (name: path: {
      ".agents/skills/${name}/SKILL.md" = {
        source = path;
        force = true;
      };
    }) locals;
in
{
  config = lib.mkIf cfg.enable {
    home.file = {
      ".agents/.keep".text = ''
        # Managed by Nix - programs.agentSkills module
      '';
    }
    // mkSkillFiles cfg.fromFlakeInputs
    // mkLocalSkills cfg.local;
  };
}
