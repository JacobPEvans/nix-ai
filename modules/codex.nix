{
  pkgs,
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

  # Mirror upstream home-manager programs.codex path logic so rules/config.toml stay co-located.
  # If upstream changes its path calculation, update here too.
  packageVersion = if cfg.package != null then lib.getVersion cfg.package else "0.2.0";
  isTomlConfig = lib.versionAtLeast packageVersion "0.2.0";
  useXdgDirectories = config.home.preferXdgDirectories && isTomlConfig;
  xdgConfigHome = lib.removePrefix "${homeDir}/" config.xdg.configHome;
  configDir = if useXdgDirectories then "${xdgConfigHome}/codex" else ".codex";

  writableRoots = [
    "${homeDir}/.codex"
  ]
  ++ lib.optional useXdgDirectories "${config.xdg.configHome}/codex";

  trustedProjects = lib.unique (
    (permissions.directories.development or [ ]) ++ (permissions.directories.config or [ ])
  );

  excludedMcpServers = [
    "cloudflare"
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

  # Nix-managed defaults for config.toml.
  # NOTE: config.toml is NOT managed as a read-only symlink. Codex writes to this file
  # at runtime (project trust levels, approval policy changes). Instead we use an
  # activation script that deep-merges these defaults with existing runtime state,
  # preserving Codex's runtime writes across rebuilds. Same pattern as Claude's
  # settings.json and Gemini's settings.json.
  configAttrs = {
    approval_policy = "untrusted";
    personality = "pragmatic";
    project_doc_fallback_filenames = [
      "AGENTS.md"
      "CLAUDE.md"
      "GEMINI.md"
    ];
    projects = lib.listToAttrs (
      map (path: {
        name = path;
        value.trust_level = "trusted";
      }) trustedProjects
    );
    sandbox_mode = "workspace-write";
    sandbox_workspace_write = {
      network_access = false;
      writable_roots = writableRoots;
    };
    mcp_servers = mcpServers;
  };

  configJson = pkgs.writeText "codex-config.json" (builtins.toJSON configAttrs);
  configToml = pkgs.runCommand "codex-config.toml" { nativeBuildInputs = [ pkgs.yj ]; } ''
    yj -jt < ${configJson} > $out
  '';

in
{
  config = lib.mkIf cfg.enable {
    programs = {
      codex = {
        # nix-darwin installs Codex via Homebrew for stable TCC paths.
        package = lib.mkDefault null;
        custom-instructions = lib.mkDefault (builtins.readFile "${ai-assistant-instructions}/AGENTS.md");
        # config.toml is managed via home.activation below — do NOT set settings here.
        # The upstream home-manager module writes settings via home.file (read-only symlink),
        # which breaks Codex's runtime writes. We handle config.toml generation ourselves.
      };
    };

    home = {
      activation.codexConfigMerge = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        export PATH="${pkgs.jq}/bin:${pkgs.yj}/bin:$PATH"
        $DRY_RUN_CMD ${./scripts/merge-toml-settings.sh} \
          "${configToml}" \
          "${homeDir}/.codex/config.toml"
      '';

      file."${configDir}/rules/default.rules".text = formatters.codex.formatRulesFile permissions;
    };
  };
}
