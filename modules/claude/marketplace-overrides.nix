# Marketplace Derivation Overrides
#
# Custom derivations that wrap marketplace flake inputs to add local content
# or create synthetic marketplace structure for repos that lack it.
# Consumed by claude-config.nix via the marketplaces flakeInput override mechanism.
{
  pkgs,
  lib,
  marketplaceInputs,
  fabric-src,
  ...
}:

{
  # Synthetic marketplace wrapper for browser-use skills (repo lacks .claude-plugin structure)
  browserUseMarketplace =
    let
      # Pinned to match uv-installed CLI version (modules/default.nix installBrowserUse)
      # renovate: datasource=pypi depName=browser-use
      browserUseVersion = "0.12.6";
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

  # Synthetic marketplace wrapper for Daniel Miessler's Fabric patterns.
  #
  # Wraps a curated subset of fabric patterns (defined in
  # ./fabric-curated-patterns.json) into a Claude Code .claude-plugin/ layout
  # so each pattern appears as a Claude Code skill.
  #
  # The pattern list lives in JSON instead of inline Nix attrs to keep this
  # file lean and let the SKILL.md frontmatter generation stay pure Nix.
  fabricMarketplace =
    let
      curated = builtins.fromJSON (builtins.readFile ./fabric-curated-patterns.json);
      fabricVersion = curated.version;
      curatedPatterns = curated.patterns;

      # Build each SKILL.md as a pure Nix string (frontmatter + upstream system.md).
      mkSkillFile =
        p:
        let
          systemMd = builtins.readFile "${fabric-src}/data/patterns/${p.name}/system.md";
          skillContent = ''
            ---
            name: ${p.name}
            description: ${p.description}
            ---

            ${systemMd}
          '';
        in
        {
          inherit (p) name;
          path = builtins.toFile "SKILL-${p.name}.md" skillContent;
        };

      skillFiles = map mkSkillFile curatedPatterns;

      # One install line per skill — no shell control flow, no loops.
      copySkillCommands = lib.concatMapStringsSep "\n" (sf: ''
        install -D -m 644 ${sf.path} $out/fabric-patterns/skills/${sf.name}/SKILL.md
      '') skillFiles;

      marketplaceJson = builtins.toFile "marketplace.json" (
        builtins.toJSON {
          name = "fabric-patterns";
          metadata = {
            description = "Curated subset of Daniel Miessler's Fabric AI prompt patterns wrapped as Claude Code skills";
            version = fabricVersion;
          };
          owner = {
            name = "Daniel Miessler";
            url = "https://github.com/danielmiessler/fabric";
          };
          plugins = [
            {
              name = "fabric-patterns";
              source = "./fabric-patterns";
              description = "Curated Fabric AI prompt patterns: extraction, analysis, creation, summarization, writing, review.";
              version = fabricVersion;
              author = {
                name = "Daniel Miessler";
              };
            }
          ];
        }
      );

      pluginJson = builtins.toFile "plugin.json" (
        builtins.toJSON {
          name = "fabric-patterns";
          version = fabricVersion;
          description = "Curated Fabric AI prompt patterns wrapped as Claude Code skills.";
          author = {
            name = "Daniel Miessler";
          };
          skills = map (p: "./skills/${p.name}") curatedPatterns;
        }
      );
    in
    pkgs.runCommand "fabric-patterns-marketplace" { } ''
      install -D -m 644 ${marketplaceJson} $out/.claude-plugin/marketplace.json
      install -D -m 644 ${pluginJson} $out/fabric-patterns/.claude-plugin/plugin.json
      ${copySkillCommands}
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
