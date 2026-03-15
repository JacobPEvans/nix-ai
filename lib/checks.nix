# Nix quality checks - single source of truth for pre-commit and CI
{
  pkgs,
  src,
  home-manager,
  aiModule,
}:
{
  formatting = pkgs.runCommand "check-formatting" { } ''
    cp -r ${src} $TMPDIR/src
    chmod -R u+w $TMPDIR/src
    cd $TMPDIR/src
    ${pkgs.lib.getExe pkgs.nixfmt-tree} --fail-on-change --no-cache --tree-root $TMPDIR/src .
    touch $out
  '';

  statix = pkgs.runCommand "check-statix" { } ''
    cd ${src}
    ${pkgs.lib.getExe pkgs.statix} check .
    touch $out
  '';

  deadnix = pkgs.runCommand "check-deadnix" { } ''
    cd ${src}
    ${pkgs.lib.getExe pkgs.deadnix} -L --fail .
    touch $out
  '';

  # Lint shell scripts with shellcheck
  # Catches common bugs: unquoted variables, undefined vars, useless use of cat, etc.
  # Excludes .git directories and nix store paths
  # --severity=warning: Only fail on warning/error level (not info style suggestions)
  # SC1091: Exclude "not following" errors for external sources (can't resolve in Nix sandbox)
  # Excludes zsh scripts (shellcheck only supports sh/bash/dash/ksh)
  # Uses find with -print0 and xargs -0 for robustness with filenames containing spaces and special characters
  shellcheck = pkgs.runCommand "check-shellcheck" { } ''
    cd ${src}
    find . -name "*.sh" -not -path "./.git/*" -not -path "./result/*" -print0 | \
    xargs -0 bash -c '
      for script in "$@"; do
        # Skip zsh scripts (shellcheck does not support them)
        if head -1 "$script" | grep -q "zsh"; then
          echo "Skipping zsh script: $script"
        else
          echo "Checking $script..."
          ${pkgs.lib.getExe pkgs.shellcheck} --severity=warning --exclude=SC1091 "$script"
        fi
      done
    ' bash
    touch $out
  '';

  # Evaluate the real home-manager module with real inputs to catch import errors
  # This ensures the module can be instantiated without failures
  module-eval =
    let
      hmConfig = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          aiModule
          {
            _module.args.userConfig = {
              ai.claudeSchemaUrl = "https://json.schemastore.org/claude-code-settings.json";
            };
            home = {
              username = "test-user";
              homeDirectory = "/home/test-user";
              stateVersion = "24.11";
            };
          }
        ];
      };
    in
    pkgs.runCommand "check-module-eval" { } ''
      echo ${hmConfig.activationPackage.drvPath} > $out
    '';
}
