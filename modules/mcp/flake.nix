{
  description = "MCP server definitions and pal-mcp-server package for AI CLI tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-25.11-darwin";

    pal-mcp-server = {
      url = "github:BeehiveInnovations/pal-mcp-server";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      pal-mcp-server,
      ...
    }:
    let
      supportedSystems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      lib.mcpServers = import ./default.nix;

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          pal-mcp-server = pkgs.callPackage ./pal-package.nix { inherit pal-mcp-server; };
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
