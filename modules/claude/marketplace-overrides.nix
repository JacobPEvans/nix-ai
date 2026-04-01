# Marketplace Derivation Overrides
#
# Custom derivations that wrap marketplace flake inputs to add local content
# or create synthetic marketplace structure for repos that lack it.
# Consumed by claude-config.nix via the marketplaces flakeInput override mechanism.
{
  pkgs,
  lib,
  marketplaceInputs,
  ...
}:

{
  # Synthetic marketplace wrapper for browser-use skills (repo lacks .claude-plugin structure)
  browserUseMarketplace =
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
  jacobpevansMarketplace =
    let
      src = marketplaceInputs.jacobpevans-cc-plugins;
      entries = builtins.readDir src;

      # Discovery filter matching plugins/development.nix + pathExists guard.
      # nonPluginDirs is kept for fast-path (avoids stat calls) and consistency
      # with development.nix which uses the same list.
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

      # Read plugin metadata from each plugin.json (defaults for robustness)
      readPluginMeta =
        name:
        let
          meta = builtins.fromJSON (builtins.readFile "${src}/${name}/.claude-plugin/plugin.json");
        in
        {
          inherit name;
          description = meta.description or "";
          version = meta.version or "0.0.1";
          author = meta.author or { name = "Unknown"; };
          source = "./${name}";
        };

      # Preserve all upstream marketplace metadata, only replace plugins array
      existingManifest = builtins.fromJSON (builtins.readFile "${src}/.claude-plugin/marketplace.json");
      manifest = existingManifest // {
        plugins = map readPluginMeta pluginDirNames;
      };

      manifestJson = builtins.toFile "marketplace.json" (builtins.toJSON manifest);
    in
    pkgs.runCommand "jacobpevans-cc-plugins-patched" { } ''
      mkdir -p $out/.claude-plugin

      # Symlink all entries except .claude-plugin (guard against empty glob)
      for f in ${src}/* ${src}/.[!.]*; do
        [ -e "$f" ] || continue
        name=$(basename "$f")
        [ "$name" = ".claude-plugin" ] && continue
        ln -s "$f" "$out/$name"
      done

      # Preserve upstream .claude-plugin contents, only replace marketplace.json
      for f in ${src}/.claude-plugin/*; do
        [ -e "$f" ] || continue
        name=$(basename "$f")
        [ "$name" = "marketplace.json" ] && continue
        ln -s "$f" "$out/.claude-plugin/$name"
      done

      # Generated marketplace.json replaces the manual one
      cp ${manifestJson} $out/.claude-plugin/marketplace.json
    '';
}
