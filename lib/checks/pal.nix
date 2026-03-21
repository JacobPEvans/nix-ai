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
}
