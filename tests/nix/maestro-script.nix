# Validate the maestro-cli script extraction produces correct output.
# Builds the script via pkgs.replaceVars and verifies content integrity.
{ pkgs, src }:
let
  testScript = pkgs.replaceVars ../../modules/maestro/scripts/maestro-cli.sh {
    maestroApp = "/test/path/to/Maestro";
  };
in
pkgs.runCommand "check-maestro-script" { } ''
  bash ${src}/tests/scripts/validate-maestro-script.sh ${testScript}
  touch $out
''
