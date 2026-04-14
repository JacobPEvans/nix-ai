# mcp-proxy — HTTP bridge for stdio MCP servers
#
# Wraps any stdio MCP server as a streamable HTTP endpoint.
# Used by pal-launchd.nix to serve PAL over HTTP so Claude Code
# can connect without the stdio spawn-timeout race condition.
#
# Endpoint: /mcp (streamable HTTP, MCP 2025-03 spec)
# Endpoint: /sse (SSE transport, legacy)
#
# Usage: mcp-proxy --port 3001 -- pal-mcp-server
# See: https://github.com/sparfenyuk/mcp-proxy
{ python3Packages, fetchPypi }:

let
  # renovate: datasource=pypi depName=mcp-proxy
  version = "0.11.0";
in
python3Packages.buildPythonApplication {
  pname = "mcp-proxy";
  inherit version;

  src = fetchPypi {
    pname = "mcp_proxy";
    inherit version;
    hash = "sha256-NCTssfV/gXRiXd/w3xW1NKCHGdh89fnWorHgON5pafE=";
  };

  pyproject = true;

  build-system = with python3Packages; [
    setuptools
  ];

  dependencies = with python3Packages; [
    httpx-auth
    mcp
    uvicorn
  ];

  # No live-server tests in Nix build.
  doCheck = false;
}
