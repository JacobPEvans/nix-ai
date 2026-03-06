{
  config,
  lib,
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
  # Start Open WebUI server on login (after Ollama is up)
  launchd.agents.open-webui = {
    enable = true;
    config = {
      Label = "app.open-webui";
      ProgramArguments = [
        "${config.home.homeDirectory}/.local/bin/open-webui"
        "serve"
      ];
      EnvironmentVariables = {
        OLLAMA_BASE_URL = "http://localhost:11434";
      };
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/OpenWebUI/open-webui.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/OpenWebUI/open-webui.error.log";
    };
  };
  # ============================================================================
  # Notes
  # ============================================================================
  # - Web UI accessible at http://localhost:8080
  # - Connects to Ollama at http://localhost:11434
  # - Data stored at ~/.open-webui/ (not managed by Nix)
  # - LaunchAgent starts on login (auto-restart if crashes)
  # - Logs: ~/Library/Logs/OpenWebUI/open-webui.log
  # - Installed via `uv tool install open-webui --python 3.12` in home.activation
  # - Binary at ~/.local/bin/open-webui (uv tool bin directory)
}
