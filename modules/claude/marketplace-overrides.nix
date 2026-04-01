# Marketplace Derivation Overrides
#
# Custom derivations that wrap marketplace flake inputs to add local content
# or create synthetic marketplace structure for repos that lack it.
# Consumed by claude-config.nix via the marketplaces flakeInput override mechanism.
{
  pkgs,
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

}
