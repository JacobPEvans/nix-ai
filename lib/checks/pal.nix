# PAL MCP package build-time checks
{ pkgs, pal-mcp-server }:
let
  palPkg = pkgs.callPackage ../../modules/mcp/pal-package.nix { inherit pal-mcp-server; };
in
{
  # Verify pal-mcp-server builds and produces an executable binary.
  # Catches broken upstream deps, missing Python packages, or build regressions.
  pal-package = pkgs.runCommand "check-pal-package" { } ''
    test -x ${palPkg}/bin/pal-mcp-server || {
      echo "FAIL: pal-mcp-server binary not found or not executable"
      exit 1
    }
    echo "PAL package: binary exists and is executable"
    touch $out
  '';

  # Shellcheck the cloud model sync script.
  # Catches quoting issues, undefined variables, and POSIX compliance problems.
  pal-cloud-sync-shellcheck =
    pkgs.runCommand "check-pal-cloud-sync"
      {
        nativeBuildInputs = [ pkgs.shellcheck ];
      }
      ''
        shellcheck ${../../modules/mcp/scripts/sync-pal-cloud-models.sh}
        echo "PAL cloud sync: shellcheck passed"
        touch $out
      '';
}
