#
# Qwen Code Module — Settings Generation
#
# Writes ~/.qwen/settings.json. Schema documented at
# https://github.com/QwenLM/qwen-code (look for the configuration table).
# Key blocks:
#   - modelProviders[]    Each provider declares baseUrl, protocol, model
#                         list, and the env var that holds the API key.
#   - env                 Fallback API-key store (lowest priority; we
#                         leave empty and prefer .env files for secrets).
#   - security.auth       The active provider type (openai for our local
#                         llama-swap routing).
#   - model.name          Default model on startup.
#
# We declare a single `mlx-local-llama-swap` provider that points at the
# local llama-swap and lists every capability-class alias from the
# registry. Users can layer additional providers via
# programs.qwen-code.extraSettings.modelProviders.
#
{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.programs.qwen-code;
  inherit (config.services.aiStack) models;

  isBifrost = cfg.routing == "bifrost";
  endpointBase = if isBifrost then "http://localhost:30080/v1" else "http://127.0.0.1:11434/v1";
  providerKey = if isBifrost then "bifrost" else "mlx-local-llama-swap";

  # llama-swap routes capability-class aliases (default, coding, ...);
  # Bifrost requires the mlx-local/ prefix on physical IDs. Generate the
  # provider's model list to match the routing target.
  modelEntries =
    if isBifrost then
      lib.mapAttrsToList (role: physical: {
        name = "mlx-local/${physical}";
        inherit (cfg) routing;
        description = "${role} → ${physical} via Bifrost";
      }) models
    else
      lib.mapAttrsToList (role: physical: {
        name = role;
        description = "${role} → ${physical} via llama-swap";
      }) models;

  defaultModelName =
    let
      r = cfg.model;
    in
    if isBifrost then "mlx-local/${models.${r} or r}" else r;

  baseSettings = {
    modelProviders = [
      {
        name = providerKey;
        protocol = "openai";
        baseUrl = endpointBase;
        # llama-swap and Bifrost authenticate upstream; the local hop is
        # open. envKey points at a name that won't be set, so qwen-code
        # falls through to the literal "dummy" in env below.
        envKey = "QWEN_LOCAL_DUMMY_KEY";
        models = modelEntries;
      }
    ];

    env = {
      QWEN_LOCAL_DUMMY_KEY = "dummy";
    };

    security.auth.selectedType = "openai";

    model.name = defaultModelName;
  };

  # Deep merge user extras over our base. attrsets.recursiveUpdate is the
  # standard merge for layered settings.
  finalSettings = lib.recursiveUpdate baseSettings cfg.extraSettings;

  settingsJson = pkgs.writeText "qwen-settings.json" (builtins.toJSON finalSettings);
in
{
  config = lib.mkIf cfg.enable {
    home.file.".qwen/settings.json".source = settingsJson;
    # History dir keep-file; qwen-code writes session state here.
    home.file.".qwen/.history-keep" = {
      target = ".qwen/history/.keep";
      text = "# Managed by Nix - programs.qwen-code\n";
    };
  };
}
