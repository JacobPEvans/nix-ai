# Claude Code Statusline Package Builder
#
# Shared derivation for building claude-code-statusline from source.
# Used by both the legacy statusline module and theme-specific modules.
{ lib, pkgs }:

{
  # Build claude-code-statusline package from source
  mkStatuslinePackage =
    source:
    pkgs.stdenvNoCC.mkDerivation {
      pname = "claude-code-statusline";
      version = "2.1.0";
      src = source;

      nativeBuildInputs = [ pkgs.makeWrapper ];
      # Note: Script uses macOS stat command (BSD stat), not GNU stat from coreutils.
      # This means the package currently only supports macOS/Darwin platforms.
      # Linux support would require either adding coreutils or updating the script
      # to detect and use the appropriate stat variant.
      buildInputs = [
        pkgs.bash
        pkgs.jq
        pkgs.git
      ];

      installPhase = ''
        runHook preInstall
        mkdir -p $out/share/claude-code-statusline $out/bin

        # Copy all source files (statusline.sh, lib/, examples/)
        cp -r . $out/share/claude-code-statusline/

        # Create wrapper - add bash/jq/git/bun (for ccusage via bunx)
        # The statusline script uses 'bunx ccusage' for cost tracking
        makeWrapper $out/share/claude-code-statusline/statusline.sh $out/bin/claude-code-statusline \
          --prefix PATH : ${
            lib.makeBinPath [
              pkgs.bash
              pkgs.jq
              pkgs.git
              pkgs.bun
            ]
          } \
          --set STATUSLINE_HOME $out/share/claude-code-statusline

        chmod +x $out/bin/claude-code-statusline
        runHook postInstall
      '';

      meta = {
        description = "Configurable statusline for Claude Code with git and cost tracking";
        homepage = "https://github.com/rz1989s/claude-code-statusline";
        license = lib.licenses.mit;
        # This package only supports macOS/Darwin due to dependency on BSD stat command.
        # The script uses `stat -f "%m"` which is BSD syntax; GNU stat uses `stat -c "%Y"`.
        # Linux support would require updating the script to detect and use the correct variant.
        platforms = lib.platforms.darwin;
        mainProgram = "claude-code-statusline";
      };
    };
}
