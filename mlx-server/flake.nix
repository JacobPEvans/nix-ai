{
  description = "Apple MLX Local Inference Server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs =
    {
      self,
      nixpkgs,
      devenv,
      ...
    }@inputs:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      devShells.${system}.default = devenv.lib.mkShell {
        inherit inputs pkgs;
        modules = [
          {
            # Required for pure evaluation (nix flake check)
            devenv.root = toString ./.;
            languages.python = {
              enable = true;
              version = "3.14";
              uv = {
                enable = true;
                sync.enable = true;
              };
            };

            enterShell = ''
              # Set HF_HOME: use external volume if mounted, otherwise fall back
              if [ -d "/Volumes/HuggingFace" ] && [ -w "/Volumes/HuggingFace" ]; then
                export HF_HOME="/Volumes/HuggingFace"
              else
                export HF_HOME="''${XDG_CACHE_HOME:-''${HOME}/.cache}/huggingface"
                mkdir -p "''${HF_HOME}"
              fi
              echo "MLX environment ready ($(python3 --version))"
            '';
          }
        ];
      };
    };
}
