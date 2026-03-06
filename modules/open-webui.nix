{
  config,
  pkgs,
  ...
}:
#
# Open WebUI Configuration Module
#
# Manages the Open WebUI service for interacting with Ollama and other
# OpenAI-compatible backends via a web browser.
#
# NOTE: open-webui is installed via `uv tool install` (not nixpkgs) because:
#   - stable nixpkgs: open-webui → pgvector → postgresql-test-hook (badPlatforms = darwin)
#   - unstable nixpkgs: open-webui has unfree license blocked by default allowUnfree
#   The uv-installed binary lands at ~/.local/bin/open-webui
#
# Web UI: http://localhost:8080
# Backend: http://localhost:11434 (Ollama)
#
{
  # ============================================================================
  # LaunchAgent for Auto-Start
  # ============================================================================
  # Start Open WebUI server on login
  launchd.agents.open-webui = {
    enable = true;
    config = {
      Label = "app.open-webui";
      Program = toString (
        pkgs.writeShellScript "start-open-webui" ''
          if [ -x "${config.home.homeDirectory}/.local/bin/open-webui" ]; then
            exec "${config.home.homeDirectory}/.local/bin/open-webui" serve
          fi
        ''
      );
      EnvironmentVariables = {
        OLLAMA_BASE_URL = "http://localhost:11434";
      };
      RunAtLoad = true;
      KeepAlive = {
        SuccessfulExit = false;
      };
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/OpenWebUI/open-webui.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/OpenWebUI/open-webui.error.log";
    };
  };

  # Ensure log directory exists — launchd does not create parent dirs for
  # StandardOutPath/StandardErrorPath, so the agent silently fails without this.
  home.file."Library/Logs/OpenWebUI/.keep" = {
    text = "";
  };

  # ============================================================================
  # Notes
  # ============================================================================
  # - Web UI accessible at http://localhost:8080
  # - Connects to Ollama at http://localhost:11434
  # - Data stored at ~/.open-webui/ (not managed by Nix)
  # - LaunchAgent starts on login (restarts on crash; exits cleanly if binary missing)
  # - Logs: ~/Library/Logs/OpenWebUI/open-webui.log
  # - Installed via `uv tool install open-webui --python 3.12` in home.activation
  # - Binary at ~/.local/bin/open-webui (uv default tool bin directory, UV_TOOL_BIN_DIR)
  # - WEBUI_SECRET_KEY is not set — Open WebUI generates a random key on each startup.
  #   This means browser sessions are invalidated on every restart/crash. To persist
  #   sessions across restarts, set WEBUI_SECRET_KEY to a stable value in
  #   EnvironmentVariables (e.g., loaded from a secrets manager like Bitwarden SM).
}
