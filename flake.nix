{
  description = "AI CLI ecosystem for Claude, Gemini, Copilot (Nix flake)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-25.11-darwin";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
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

    # Marketplace Inputs (14 total)
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
  };

  outputs =
    {
      nixpkgs,
      home-manager,
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
      ...
    }:
    let
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
          ;
      };
    in
    {
      # Full AI CLI home-manager module
      homeManagerModules.default = {
        imports = [ ./modules/default.nix ];
        _module.args = {
          inherit
            ai-assistant-instructions
            marketplaceInputs
            claude-code-plugins
            claude-cookbooks
            ;
        };
      };

      # Individual modules for selective import
      homeManagerModules.claude = {
        imports = [ ./modules/claude ];
        _module.args = {
          inherit
            ai-assistant-instructions
            marketplaceInputs
            claude-code-plugins
            claude-cookbooks
            ;
        };
      };

      homeManagerModules.maestro = {
        imports = [ ./modules/maestro ];
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

      # Formatter
      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-tree;
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
    };
}
