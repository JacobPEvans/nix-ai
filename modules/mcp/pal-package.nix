# PAL MCP Server — Nix Python Package
#
# Builds pal-mcp-server from the pinned flake input instead of relying on
# uvx at runtime. This eliminates:
#   - git cloning on every cold start
#   - setuptools_scm permission errors from the read-only Nix store
#   - uvx cache corruption from previous failed builds
#
# The SETUPTOOLS_SCM_PRETEND_VERSION env var tells setuptools_scm to skip
# git operations (version is hardcoded), so no write access to source is needed.
#
# Usage: pkgs.callPackage ./pal-package.nix { inherit pal-mcp-server; }
{ python3Packages, pal-mcp-server }:

python3Packages.buildPythonApplication {
  pname = "pal-mcp-server";
  version = "9.8.2";
  src = pal-mcp-server;
  pyproject = true;

  build-system = with python3Packages; [
    setuptools
    setuptools-scm
    wheel
  ];

  dependencies = with python3Packages; [
    mcp
    google-genai
    openai
    pydantic
    python-dotenv
  ];

  # Prevents setuptools_scm from running git to detect version.
  # Without this, it would try to write pal_mcp_server.egg-info to the source
  # directory, which fails because the Nix store is read-only.
  env.SETUPTOOLS_SCM_PRETEND_VERSION = "9.8.2";

  # Tests require live API keys (Gemini, OpenRouter, Ollama) — skip in Nix build.
  doCheck = false;
}
