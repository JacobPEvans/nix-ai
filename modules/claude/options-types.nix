# Claude Code Module — Reusable submodule types
#
# Returns a plain attrset of types so each option file can `inherit` only
# what it needs without re-declaring the same submodule structure.
{ lib }:
{
  marketplaceModule = lib.types.submodule {
    options = {
      source = lib.mkOption {
        type = lib.types.submodule {
          options = {
            type = lib.mkOption {
              type = lib.types.enum [
                "git"
                "github"
                "local"
              ];
              default = "git";
            };
            url = lib.mkOption { type = lib.types.str; };
          };
        };
      };
      flakeInput = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Flake input for Nix-managed (immutable) plugins";
      };
      overlayFiles = lib.mkOption {
        type = lib.types.attrsOf lib.types.path;
        default = { };
        description = "Files to overlay onto the marketplace (dest path relative to marketplace root → source file)";
      };
    };
  };

  componentModule = lib.types.submodule {
    options = {
      name = lib.mkOption { type = lib.types.str; };
      source = lib.mkOption { type = lib.types.path; };
    };
  };

  mcpServerModule = lib.types.submodule {
    options = {
      type = lib.mkOption {
        type = lib.types.enum [
          "stdio"
          "sse"
          "http"
        ];
        default = "stdio";
      };
      command = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      env = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
      };
      url = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      headers = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
      };
      disabled = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };
  };

  hookType = lib.types.nullOr (lib.types.either lib.types.path lib.types.lines);
}
