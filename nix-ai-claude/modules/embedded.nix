{
  config,
  pkgs,
  lib,
  ai-assistant-instructions,
  marketplaceInputs,
  claude-cookbooks,
  fabric-src,
  userConfig ? {
    ai.claudeSchemaUrl = "https://json.schemastore.org/claude-code-settings.json";
  },
  ...
}:

let
  claudeConfig = import ./claude-config.nix {
    inherit
      config
      pkgs
      lib
      ai-assistant-instructions
      marketplaceInputs
      claude-cookbooks
      fabric-src
      ;
  };
in
{
  imports = [ ./claude ];

  config = {
    home.activation.validateClaudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${./scripts/validate-claude-settings.sh} \
        "${config.home.homeDirectory}/.claude/settings.json" \
        "${userConfig.ai.claudeSchemaUrl}"
    '';

    programs = {
      claude = claudeConfig;
      claudeStatusline.enable = false;
      claudeStatuslineDaniel3303.enable = true;
    };
  };
}
