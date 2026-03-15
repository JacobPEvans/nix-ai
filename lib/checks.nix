# Nix quality checks - single source of truth for pre-commit and CI
{
  pkgs,
  src,
  home-manager,
  aiModule,
}:
let
  # Shared test module configuration — used by module-eval and regression checks
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

  shellcheck =
    pkgs.runCommand "check-shellcheck"
      {
        nativeBuildInputs = [ pkgs.shellcheck ];
      }
      ''
        cd ${src}
        bash ${src}/scripts/check-shellcheck.sh
        touch $out
      '';

  # Evaluate the real home-manager module with real inputs to catch import errors
  module-eval = pkgs.runCommand "check-module-eval" { } ''
    echo ${hmConfig.activationPackage.drvPath} > $out
  '';

  # Regression tests (delegated to tests/nix/)
  options-regression = import ../tests/nix/claude-options-regression.nix { inherit pkgs hmConfig; };
  defaults-regression = import ../tests/nix/claude-defaults-regression.nix { inherit pkgs hmConfig; };
  settings-json = import ../tests/nix/claude-settings-json.nix { inherit pkgs src; };
  maestro-script = import ../tests/nix/maestro-script.nix { inherit pkgs src; };
}
