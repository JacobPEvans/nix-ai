# Codex Components
#
# Manages skills deployment for Codex CLI.
# Skills are deployed to both ~/.codex/skills/ and ~/.agents/skills/ (cross-tool alias).
{ config, lib, ... }:

let
  cfg = config.programs.codex;

  # Helper to create file entries from skill list
  mkSkillFiles =
    components:
    builtins.listToAttrs (
      lib.concatMap (c: [
        {
          name = ".codex/skills/${c.name}/SKILL.md";
          value = {
            inherit (c) source;
            force = true;
          };
        }
        {
          name = ".agents/skills/${c.name}/SKILL.md";
          value = {
            inherit (c) source;
            force = true;
          };
        }
      ]) components
    );

  # Helper for local skill symlinks
  mkLocalSkills =
    locals:
    lib.concatMapAttrs (name: path: {
      ".codex/skills/${name}/SKILL.md" = {
        source = path;
        force = true;
      };
      ".agents/skills/${name}/SKILL.md" = {
        source = path;
        force = true;
      };
    }) locals;
in
{
  config = lib.mkIf cfg.enable {
    home.file = mkSkillFiles cfg.skills.fromFlakeInputs // mkLocalSkills cfg.skills.local;
  };
}
