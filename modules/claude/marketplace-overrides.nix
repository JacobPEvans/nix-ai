# Marketplace Override Derivations
#
# Derivations that wrap flake inputs to fix or enhance marketplace structure.
# Imported by claude-config.nix — each derivation is used as a flakeInput override.
{
  pkgs,
  lib,
  marketplaceInputs,
}:

{
  # Synthetic marketplace wrapper for browser-use skills (repo lacks .claude-plugin structure)
  browserUse =
    let
      # Pinned to match uv-installed CLI version (modules/default.nix installBrowserUse)
      browserUseVersion = "0.12.5";
      manifestJson = builtins.toFile "marketplace.json" (
        builtins.toJSON {
          name = "browser-use-skills";
          metadata = {
            description = "Browser automation skills from browser-use";
            version = browserUseVersion;
          };
          owner = {
            name = "Browser Use";
            url = "https://browser-use.com";
          };
          plugins = [
            {
              name = "browser-use";
              source = "./browser-use";
              description = "Browser automation via browser-use CLI and Python library";
              version = browserUseVersion;
              author = {
                name = "Browser Use";
              };
            }
          ];
        }
      );
      # Per-plugin manifest (Claude Code requires .claude-plugin/plugin.json in each plugin dir)
      pluginJson = builtins.toFile "plugin.json" (
        builtins.toJSON {
          name = "browser-use";
          version = browserUseVersion;
          description = "Browser automation via browser-use CLI and Python library";
          author = {
            name = "Browser Use";
          };
          skills = [
            "./skills/browser-use"
            "./skills/cloud"
            "./skills/open-source"
            "./skills/remote-browser"
          ];
        }
      );
    in
    pkgs.runCommand "browser-use-marketplace" { } ''
      mkdir -p $out/.claude-plugin $out/browser-use/.claude-plugin
      cp ${manifestJson} $out/.claude-plugin/marketplace.json
      cp ${pluginJson} $out/browser-use/.claude-plugin/plugin.json
      ln -s ${marketplaceInputs.browser-use-skills}/skills $out/browser-use/skills
    '';

  # Auto-generated marketplace manifest for jacobpevans-cc-plugins
  # Ensures every plugin directory is registered — eliminates manual marketplace.json maintenance.
  jacobpevans =
    let
      src = marketplaceInputs.jacobpevans-cc-plugins;
      entries = builtins.readDir src;

      # Same discovery filter as plugins/development.nix
      nonPluginDirs = [
        "docs"
        "schemas"
        ".claude-plugin"
        ".github"
        "scripts"
        "tests"
      ];
      isPluginDir =
        name: type:
        type == "directory"
        && !(lib.hasPrefix "." name)
        && !(builtins.elem name nonPluginDirs)
        && builtins.pathExists "${src}/${name}/.claude-plugin/plugin.json";
      pluginDirNames = builtins.attrNames (lib.filterAttrs isPluginDir entries);

      # Read plugin metadata from each plugin.json
      readPluginMeta =
        name:
        let
          meta = builtins.fromJSON (builtins.readFile "${src}/${name}/.claude-plugin/plugin.json");
        in
        {
          inherit name;
          inherit (meta) description version author;
          source = "./${name}";
        };

      # Preserve marketplace-level metadata from upstream, replace plugins array
      existingManifest = builtins.fromJSON (builtins.readFile "${src}/.claude-plugin/marketplace.json");
      manifest = {
        inherit (existingManifest) name owner metadata;
        plugins = map readPluginMeta pluginDirNames;
      };

      manifestJson = builtins.toFile "marketplace.json" (builtins.toJSON manifest);
    in
    pkgs.runCommand "jacobpevans-cc-plugins-patched" { } ''
      mkdir -p $out/.claude-plugin

      # Symlink all top-level entries except .claude-plugin
      for f in ${src}/*; do
        [ "$(basename "$f")" = ".claude-plugin" ] && continue
        ln -s "$f" "$out/$(basename "$f")"
      done

      # Symlink hidden entries except .claude-plugin
      for f in ${src}/.[!.]*; do
        [ "$(basename "$f")" = ".claude-plugin" ] && continue
        ln -s "$f" "$out/$(basename "$f")"
      done

      # Generated marketplace.json replaces the manual one
      cp ${manifestJson} $out/.claude-plugin/marketplace.json
    '';
}
