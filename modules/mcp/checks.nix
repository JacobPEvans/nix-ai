# PAL MCP package + script checks
#
# Runs at `nix flake check` time inside the MCP sub-flake. Validates that:
#   - pal-mcp-server builds and produces an executable binary
#   - sync-pal-cloud-models.sh passes shellcheck
#
# Exposed via `checks.<sys>.*` from `./flake.nix`. The home-manager module
# evaluation tests for nix-ai live in `nix-ai/lib/checks/` (consumer-side).
{ pkgs, pal-mcp-server }:
let
  palPkg = pkgs.callPackage ./pal-package.nix { inherit pal-mcp-server; };
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
        shellcheck --severity=warning --exclude=SC1091 ${./scripts/sync-pal-cloud-models.sh}
        echo "PAL cloud sync: shellcheck passed"
        touch $out
      '';
}
