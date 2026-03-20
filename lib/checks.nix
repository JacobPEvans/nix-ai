# Nix quality checks - thin aggregator
# Individual check groups live in lib/checks/{lint,claude,mlx}.nix
{
  pkgs,
  src,
  home-manager,
  aiModule,
}:
let
  # Shared test module configuration — used by claude and mlx regression checks
  hmConfig = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      aiModule
      {
        _module.args.userConfig = {
          ai.claudeSchemaUrl = "https://json.schemastore.org/claude-code-settings.json";
        };
        home = {
          username = "test-user";
          homeDirectory = "/home/test-user";
          stateVersion = "25.11";
        };
      }
    ];
  };
in
(import ./checks/lint.nix { inherit pkgs src; })
// (import ./checks/claude.nix { inherit pkgs hmConfig; })
// (import ./checks/mlx.nix { inherit pkgs hmConfig; })
