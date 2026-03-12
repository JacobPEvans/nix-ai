{
  description = "Apple MLX Local Inference Server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs =
          with pkgs;
          [
            python314
            uv
          ]
          ++ (with pkgs.darwin.apple_sdk.frameworks; [
            Metal
            Accelerate
            CoreGraphics
            CoreVideo
          ]);

        HF_HOME = "/Volumes/HuggingFace";

        shellHook = ''
          if [ ! -d ".venv" ]; then
            echo "-> Creating MLX venv with Python 3.14..."
            uv venv .venv --python 3.14
            source .venv/bin/activate
            uv sync
          else
            source .venv/bin/activate
          fi
          echo "MLX environment ready ($(python3 --version))"
        '';
      };
    };
}
