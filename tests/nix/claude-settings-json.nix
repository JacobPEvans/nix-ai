# Validate the pure settings JSON generator (lib/claude-settings.nix).
# Verifies structure, required keys, types, and value correctness.
{ pkgs, src }:
let
  ciSettings = import ../../lib/claude-settings.nix {
    inherit (pkgs) lib;
    homeDir = "/home/test-user";
    schemaUrl = "https://json.schemastore.org/claude-code-settings.json";
    permissions = {
      allow = [
        "Read"
        "Write"
      ];
      deny = [ "Bash(rm -rf /)" ];
      ask = [ ];
    };
    plugins = {
      marketplaces = { };
      enabledPlugins = { };
    };
  };
in
pkgs.runCommand "check-settings-json"
  {
    nativeBuildInputs = [ pkgs.jq ];
    passAsFile = [ "json" ];
    json = builtins.toJSON ciSettings;
  }
  ''
    bash ${src}/tests/scripts/validate-settings-json.sh "$jsonPath"
    touch $out
  ''
