# Claude Code Module — Status line + feature-flag options
#
# statusLine: optional CLI status line script.
# features: opt-in flags including the marketplace plugin schema version
# and an experimental escape hatch for future toggles.
{ lib, ... }:
{
  options.programs.claude = {
    statusLine = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      script = lib.mkOption {
        type = lib.types.nullOr lib.types.lines;
        default = null;
      };
    };

    features = {
      pluginSchemaVersion = lib.mkOption {
        type = lib.types.int;
        default = 1;
      };
      experimental = lib.mkOption {
        type = lib.types.attrsOf lib.types.bool;
        default = { };
      };
    };
  };
}
