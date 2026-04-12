{ lib, ... }:

{
  options.programs.mlx = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Minimal MLX compatibility surface for Claude PAL integration.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "MLX API host used by Claude PAL model sync.";
    };

    port = lib.mkOption {
      type = lib.types.int;
      default = 11434;
      description = "MLX API port used by Claude PAL model sync.";
    };

    defaultModel = lib.mkOption {
      type = lib.types.str;
      default = "mlx-community/Qwen3.5-122B-A10B-4bit";
      description = "Default MLX model name exposed to Claude PAL integration.";
    };
  };
}
