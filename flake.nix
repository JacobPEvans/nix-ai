{
  description = "AI CLI ecosystem for Claude, Gemini, Copilot (Nix flake)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-25.11-darwin";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Official Anthropic repositories
    claude-code-plugins = {
      url = "github:anthropics/claude-code";
      flake = false;
    };

    claude-cookbooks = {
      url = "github:anthropics/claude-cookbooks";
      flake = false;
    };

    # AI Assistant Instructions - source of truth for AI agent configuration
    ai-assistant-instructions = {
      url = "github:JacobPEvans/ai-assistant-instructions";
      flake = false;
    };

    # Marketplace Inputs
    anthropic-agent-skills = {
      url = "github:anthropics/skills";
      flake = false;
    };
    bills-claude-skills = {
      url = "github:BillChirico/bills-claude-skills";
      flake = false;
    };
    cc-dev-tools = {
      url = "github:Lucklyric/cc-dev-tools";
      flake = false;
    };
    cc-marketplace = {
      url = "github:ananddtyagi/cc-marketplace";
      flake = false;
    };
    claude-code-plugins-plus = {
      url = "github:jeremylongshore/claude-code-plugins-plus";
      flake = false;
    };
    claude-code-workflows = {
      url = "github:wshobson/agents";
      flake = false;
    };
    claude-plugins-official = {
      url = "github:anthropics/claude-plugins-official";
      flake = false;
    };
    claude-skills = {
      url = "github:secondsky/claude-skills";
      flake = false;
    };
    jacobpevans-cc-plugins = {
      url = "github:JacobPEvans/claude-code-plugins";
      flake = false;
    };
    lunar-claude = {
      url = "github:basher83/lunar-claude";
      flake = false;
    };
    obsidian-skills = {
      url = "github:kepano/obsidian-skills";
      flake = false;
    };
    axton-obsidian-visual-skills = {
      url = "github:axtonliu/axton-obsidian-visual-skills";
      flake = false;
    };
    superpowers-marketplace = {
      url = "github:obra/superpowers-marketplace";
      flake = false;
    };
    wakatime = {
      url = "github:wakatime/claude-code-wakatime";
      flake = false;
    };
    bitwarden-marketplace = {
      url = "github:bitwarden/ai-plugins";
      flake = false;
    };

    # PAL MCP server - pinned for supply-chain safety; auto-bumped by deps-update-flake.yml
    pal-mcp-server = {
      url = "github:BeehiveInnovations/pal-mcp-server";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      devenv,
      claude-code-plugins,
      claude-cookbooks,
      ai-assistant-instructions,
      anthropic-agent-skills,
      bills-claude-skills,
      cc-dev-tools,
      cc-marketplace,
      claude-code-plugins-plus,
      claude-code-workflows,
      claude-plugins-official,
      claude-skills,
      jacobpevans-cc-plugins,
      lunar-claude,
      obsidian-skills,
      axton-obsidian-visual-skills,
      superpowers-marketplace,
      wakatime,
      bitwarden-marketplace,
      pal-mcp-server,
      ...
    }@inputs:
    let
      supportedSystems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      marketplaceInputs = {
        inherit
          anthropic-agent-skills
          bills-claude-skills
          cc-dev-tools
          cc-marketplace
          claude-code-plugins-plus
          claude-code-workflows
          claude-plugins-official
          claude-skills
          jacobpevans-cc-plugins
          lunar-claude
          obsidian-skills
          axton-obsidian-visual-skills
          superpowers-marketplace
          wakatime
          bitwarden-marketplace
          ;
      };
    in
    {
      # Home-manager modules
      homeManagerModules = {
        # Full AI CLI module
        default = {
          imports = [ ./modules/default.nix ];
          _module.args = {
            inherit
              ai-assistant-instructions
              marketplaceInputs
              claude-code-plugins
              claude-cookbooks
              pal-mcp-server
              ;
          };
        };

        # Individual modules for selective import
        claude = {
          imports = [ ./modules/claude ];
          _module.args = {
            inherit
              ai-assistant-instructions
              marketplaceInputs
              claude-code-plugins
              claude-cookbooks
              pal-mcp-server
              ;
          };
        };

        maestro = {
          imports = [ ./modules/maestro ];
        };
      };

      # CI-friendly outputs
      lib = {
        ci = {
          claudeSettingsJson =
            let
              aiCommon = import ./modules/common {
                inherit ai-assistant-instructions;
                inherit (nixpkgs) lib;
                config = {
                  home.homeDirectory = "/home/user";
                };
              };
              inherit (aiCommon) permissions formatters;
            in
            builtins.toJSON (
              import ./lib/claude-settings.nix {
                inherit (nixpkgs) lib;
                homeDir = "/home/user";
                schemaUrl = "https://json.schemastore.org/claude-code-settings.json";
                permissions = {
                  allow = formatters.claude.formatAllowed permissions;
                  deny = formatters.claude.formatDenied permissions;
                  ask = [ ];
                };
                plugins =
                  (import ./modules/claude-plugins.nix {
                    inherit (nixpkgs) lib;
                    inherit marketplaceInputs claude-cookbooks;
                  }).pluginConfig;
              }
            );
        };

        # Expose lib functions
        claude-settings = import ./lib/claude-settings.nix;
        claude-registry = import ./lib/claude-registry.nix;
        security-policies = import ./lib/security-policies.nix;
        versions = import ./lib/versions.nix;
      };

      # Quality checks (formatting, linting, dead code, shellcheck, module-eval)
      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        import ./lib/checks.nix {
          inherit pkgs home-manager;
          src = ./.;
          aiModule = self.homeManagerModules.default;
        }
      );

      # Expose custom packages for nix-update automation
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          gh-aw = pkgs.callPackage ./modules/gh-extensions/gh-aw.nix { };
          pal-mcp-server = pkgs.callPackage ./modules/mcp/pal-package.nix { inherit pal-mcp-server; };
        }
      );

      # Named devenv shells — reference via: nix develop ~/git/nix-ai/main#<name>
      # To add a new shell: add a new key to the attrset below.
      #
      # devenv.root uses builtins.getEnv "PWD" so devenv writes .devenv/ state
      # to the real filesystem instead of the read-only Nix store copy.
      # Requires --impure (pass via .envrc or `nix develop --impure`).
      # Falls back to store path for pure evaluation (nix flake check).
      devShells =
        let
          # Runtime PWD — not system-specific; empty under pure eval → falls back to store path
          pwd = builtins.getEnv "PWD";
          # Guard: only use PWD when it looks like the flake root (has flake.nix)
          pwdIsFlakeRoot = pwd != "" && builtins.pathExists (pwd + "/flake.nix");
          # Guard: only use PWD for mlx-server when it contains pyproject.toml
          pwdIsMlxRoot = pwd != "" && builtins.pathExists (pwd + "/pyproject.toml");
          # Guard: only use PWD for orchestrator when its pyproject.toml has the orchestrator project name
          pwdIsOrchestratorRoot =
            pwd != ""
            && builtins.pathExists (pwd + "/pyproject.toml")
            &&
              builtins.match ".*name = \"orchestrator\".*" (builtins.readFile (pwd + "/pyproject.toml")) != null;
        in
        forAllSystems (
          system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
          in
          {
            # AI Python development: LangChain, LangGraph, OpenTelemetry
            ai-dev = devenv.lib.mkShell {
              inherit inputs pkgs;
              modules = [
                {
                  devenv.root = if pwdIsFlakeRoot then pwd else toString ./.;
                  languages.python = {
                    enable = true;
                    package = pkgs.python314;
                    venv.enable = true;
                    venv.requirements = ''
                      langchain
                      langchain-core
                      langchain-openai
                      langgraph
                      opentelemetry-api
                      opentelemetry-sdk
                      opentelemetry-exporter-otlp
                      opentelemetry-instrumentation
                    '';
                  };
                }
              ];
            };
          }
          // {
            # Skill orchestration: LangGraph, LlamaIndex, embeddings
            orchestrator = devenv.lib.mkShell {
              inherit inputs pkgs;
              modules = [
                {
                  devenv.root = if pwdIsOrchestratorRoot then pwd else toString ./orchestrator;
                  languages.python = {
                    enable = true;
                    version = "3.14";
                    uv = {
                      enable = true;
                      sync.enable = true;
                    };
                  };
                  enterShell = ''
                    echo "Orchestrator environment ready ($(python3 --version))"
                  '';
                }
              ];
            };
          }
          # mlx-server is Apple Silicon only — MLX ships aarch64 wheels only
          // nixpkgs.lib.optionalAttrs (system == "aarch64-darwin") {
            mlx-server = devenv.lib.mkShell {
              inherit inputs pkgs;
              modules = [
                {
                  # Reads pyproject.toml / uv.lock from ./mlx-server/
                  # PWD is mlx-server/ when nix-direnv evaluates the .envrc there;
                  # guard against arbitrary caller directories with pyproject.toml check.
                  devenv.root = if pwdIsMlxRoot then pwd else toString ./mlx-server;
                  languages.python = {
                    enable = true;
                    package = pkgs.python314;
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
          }
        );

      # Formatter
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
