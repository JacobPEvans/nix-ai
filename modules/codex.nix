{
  config,
  lib,
  ai-assistant-instructions,
  ...
}:

let
  cfg = config.programs.codex;
  homeDir = config.home.homeDirectory;

  aiCommon = import ./common {
    inherit lib config ai-assistant-instructions;
  };
  inherit (aiCommon) permissions formatters;

  packageVersion = if cfg.package != null then lib.getVersion cfg.package else "0.2.0";
  isTomlConfig = lib.versionAtLeast packageVersion "0.2.0";
  useXdgDirectories = config.home.preferXdgDirectories && isTomlConfig;
  xdgConfigHome = lib.removePrefix homeDir config.xdg.configHome;
  configDir = if useXdgDirectories then "${xdgConfigHome}/codex" else ".codex";

  writableRoots = lib.unique (
    [ "${homeDir}/.codex" ] ++ lib.optional useXdgDirectories "${config.xdg.configHome}/codex"
  );

  trustedProjects = lib.unique (
    (permissions.directories.development or [ ])
    ++ lib.filter (path: path == "${homeDir}/.config/nix") (permissions.directories.config or [ ])
  );

  excludedMcpServers = [
    "cloudflare"
    "codex"
    "cribl"
    "docker"
    "everything"
    "exa"
    "fetch"
    "filesystem"
    "firecrawl"
    "git"
    "github"
    "terraform"
  ];

  normalizeMcpServer =
    server:
    let
      allowedKeys =
        if server ? url then
          [
            "bearer_token_env_var"
            "disabled_tools"
            "enabled_tools"
            "env_http_headers"
            "http_headers"
            "oauth_resource"
            "required"
            "scopes"
            "startup_timeout_sec"
            "tool_timeout_sec"
            "url"
          ]
        else
          [
            "args"
            "command"
            "cwd"
            "disabled_tools"
            "enabled_tools"
            "env"
            "env_vars"
            "required"
            "startup_timeout_sec"
            "tool_timeout_sec"
          ];
    in
    lib.filterAttrs (name: value: lib.elem name allowedKeys && value != null) server;

  mcpServers =
    let
      sharedServers = import ./mcp;
    in
    lib.mapAttrs' (name: server: lib.nameValuePair name (normalizeMcpServer server)) (
      lib.filterAttrs (
        name: server: !(server.disabled or false) && !(lib.elem name excludedMcpServers)
      ) sharedServers
    );

in
{
  config = lib.mkIf cfg.enable {
    programs = {
      codex = {
        # nix-darwin installs Codex via Homebrew for stable TCC paths.
        package = lib.mkDefault null;
        custom-instructions = lib.mkDefault (builtins.readFile "${ai-assistant-instructions}/AGENTS.md");
        settings = {
          approval_policy = lib.mkDefault "untrusted";
          personality = lib.mkDefault "pragmatic";
          project_doc_fallback_filenames = lib.mkDefault [
            "AGENTS.md"
            "CLAUDE.md"
            "GEMINI.md"
          ];
          projects = lib.mkDefault (
            lib.listToAttrs (
              map (path: {
                name = path;
                value.trust_level = "trusted";
              }) trustedProjects
            )
          );
          sandbox_mode = lib.mkDefault "workspace-write";
          sandbox_workspace_write = {
            network_access = lib.mkDefault false;
            writable_roots = lib.mkDefault writableRoots;
          };
          mcp_servers = lib.mkDefault mcpServers;
        };
      };
    };

    home.file."${configDir}/rules/default.rules".text = formatters.codex.formatRulesFile permissions;
  };
}
