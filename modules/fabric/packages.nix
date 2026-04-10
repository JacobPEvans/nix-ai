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
    # and session variables into a single merged key. Example CLI usage:
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
    home = {
      packages = [ fabricPkg ];

      file.".config/fabric/patterns" = {
        source = "${fabric-src}/data/patterns";
      };

      sessionVariables = {
        FABRIC_PATTERNS_DIR = cfg.patternsDir;
        FABRIC_DEFAULT_MODEL = cfg.defaultModel;
      };
    };
  };
}
