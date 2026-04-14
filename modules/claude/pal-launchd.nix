# PAL MCP — Persistent HTTP Server (LaunchAgent)
#
# Runs mcp-proxy + pal-mcp-server as a macOS LaunchAgent, exposing PAL
# over streamable HTTP on 127.0.0.1:3001. Claude Code connects via
# `type = "http"` MCP registration (see modules/mcp/default.nix).
#
# This eliminates the stdio spawn-timeout race condition: previously,
# Claude Code spawned doppler-mcp pal-mcp-server as a stdio process, but
# the Doppler API round-trip to inject secrets often exceeded Claude Code's
# connection timeout when ~17 MCP servers started simultaneously at launch.
# With a persistent server, Claude Code simply HTTP-connects to an already-
# running process.
#
# Secret injection: doppler run injects API keys at LaunchAgent startup.
# Non-secret config (DISABLED_TOOLS, DEFAULT_MODEL, etc.) comes from
# config.programs.claude.mcpServers.pal.env, which merges the static env
# block in mcp/default.nix with the dynamic vars from pal-models.nix.
#
# Log files: ~/Library/Logs/pal-mcp/pal-mcp.{log,error.log}
# Port: 3001 (see port table in CLAUDE.md)
{
  config,
  lib,
  pkgs,
  pal-mcp-server,
  ...
}:

let
  cfg = config.programs.claude;
  homeDir = config.home.homeDirectory;

  palPkg = pkgs.callPackage ../mcp/pal-package.nix { inherit pal-mcp-server; };
  mcpProxyPkg = pkgs.callPackage ../mcp/mcp-proxy-package.nix { inherit (pkgs) fetchPypi; };

  # Fallback cache path for Doppler secrets (used when Doppler API is unreachable).
  # Populated on first successful doppler run; used automatically by --fallback flag.
  fallbackPath = "${homeDir}/.local/state/doppler-mcp-fallback.enc";

  # Merge of static env (DISABLED_TOOLS, DEFAULT_MODEL, etc.) from mcp/default.nix
  # and dynamic env (CUSTOM_MODELS_CONFIG_PATH, CUSTOM_MODEL_NAME, etc.) from
  # pal-models.nix. Both feed into programs.claude.mcpServers.pal.env — Nix module
  # system merges them via the attrsOf type. For HTTP servers, settings.nix ignores
  # the env block in ~/.claude/settings.json, but the LaunchAgent still needs it.
  palEnv = cfg.mcpServers.pal.env;
in
{
  config = lib.mkIf cfg.enable {
    launchd.agents.pal-mcp = {
      enable = true;
      config = {
        Label = "dev.pal-mcp.server";
        # Invocation: doppler run (secret injection) → mcp-proxy (HTTP wrapper) → pal-mcp-server (stdio)
        # doppler exports secrets into the child's environment; mcp-proxy inherits them and
        # passes them down to the pal-mcp-server subprocess it spawns.
        ProgramArguments = [
          "${pkgs.doppler}/bin/doppler"
          "run"
          "--project"
          "ai-ci-automation"
          "--config"
          "prd"
          "--fallback"
          fallbackPath
          "--"
          (lib.getExe mcpProxyPkg)
          "--port"
          "3001"
          "--"
          (lib.getExe palPkg)
        ];
        RunAtLoad = true;
        KeepAlive = true;
        # 30s throttle prevents rapid crash-restart loops (e.g. Doppler auth failure).
        ThrottleInterval = 30;
        ProcessType = "Background";
        # Non-secret config merged from mcp/default.nix + pal-models.nix.
        # Doppler adds API keys on top of these at startup.
        EnvironmentVariables = palEnv;
        StandardOutPath = "${homeDir}/Library/Logs/pal-mcp/pal-mcp.log";
        StandardErrorPath = "${homeDir}/Library/Logs/pal-mcp/pal-mcp.error.log";
      };
    };

    home.file.".config/newsyslog.d/pal-mcp.conf".text = ''
      # logfilename                                                    [owner:group]  mode  count  size  when  flags
      ${homeDir}/Library/Logs/pal-mcp/pal-mcp.error.log              :              644   3      10240 *     J
      ${homeDir}/Library/Logs/pal-mcp/pal-mcp.log                    :              644   3      10240 *     J
    '';

    launchd.agents.pal-mcp-logrotate = {
      enable = true;
      config = {
        Label = "dev.pal-mcp.logrotate";
        ProgramArguments = [
          "/usr/sbin/newsyslog"
          "-f"
          "${homeDir}/.config/newsyslog.d/pal-mcp.conf"
        ];
        StartCalendarInterval = [ { Minute = 0; } ]; # hourly
      };
    };
  };
}
