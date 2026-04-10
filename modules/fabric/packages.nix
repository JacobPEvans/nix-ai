#
# Fabric Module — Package, Patterns, Environment
#
# Exposes the fabric CLI binary, symlinks the 252+ pattern library from the
# fabric-src flake input, and sets session variables.
#
{
  lib,
  fabric-src,
  fabricShared,
  ...
}:
let
  inherit (fabricShared) cfg fabricPkg;
in
{
  config = lib.mkIf cfg.enable {
    # The `home.*` attribute set groups the fabric CLI binary, pattern symlinks,
    # session variables, and custom patterns directory activation into a single
    # merged key. Example CLI usage:
    #   echo "content" | fabric --pattern summarize
    #   fabric -y "https://youtube.com/watch?v=..." --pattern extract_wisdom
    #   git diff | fabric --pattern create_git_diff_commit
    #
    # Patterns are symlinked read-only from the fabric-src flake input to
    # ~/.config/fabric/patterns/. Each pattern directory contains system.md
    # (AI instructions) and user.md (human documentation).
    #
    # Session variables point fabric at the local MLX stack by default; users
    # can override per-invocation with --model or --url flags.
    #
    # When customPatternsDir is set (default ~/.config/fabric/custom-patterns)
    # the directory is created on activation and FABRIC_CUSTOM_PATTERNS_DIR is
    # exported so users can drop their own patterns alongside the read-only ones.
    home = {
      packages = [ fabricPkg ];

      file.".config/fabric/patterns" = {
        source = "${fabric-src}/data/patterns";
      };

      sessionVariables = {
        FABRIC_PATTERNS_DIR = cfg.patternsDir;
        FABRIC_DEFAULT_MODEL = cfg.defaultModel;
      }
      // lib.optionalAttrs (cfg.customPatternsDir != null) {
        FABRIC_CUSTOM_PATTERNS_DIR = cfg.customPatternsDir;
      };

      activation = lib.optionalAttrs (cfg.customPatternsDir != null) {
        fabricCustomPatternsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD mkdir -p ${cfg.customPatternsDir}
        '';
      };
    };
  };
}
