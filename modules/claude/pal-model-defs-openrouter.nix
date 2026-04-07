# PAL MCP — Curated OpenRouter Model Definitions (LATEST ONLY)
#
# Static model metadata imported by pal-models.nix and serialized to JSON.
# Update these when new model versions are released.
# Gemini and OpenAI models are in pal-model-defs.nix.
{
  models = [
    # Anthropic — latest only
    {
      model_name = "anthropic/claude-opus-4.6";
      aliases = [
        "opus"
        "opus4.6"
        "claude-opus"
      ];
      context_window = 1000000;
      max_output_tokens = 128000;
      supports_extended_thinking = true;
      supports_json_mode = false;
      supports_function_calling = false;
      supports_images = true;
      max_image_size_mb = 5.0;
      description = "Claude Opus 4.6 — strongest model for coding and long-running tasks";
      intelligence_score = 19;
    }
    {
      model_name = "anthropic/claude-sonnet-4.6";
      aliases = [
        "sonnet"
        "sonnet4.6"
      ];
      context_window = 1000000;
      max_output_tokens = 128000;
      supports_extended_thinking = true;
      supports_json_mode = false;
      supports_function_calling = false;
      supports_images = true;
      max_image_size_mb = 5.0;
      description = "Claude Sonnet 4.6 — frontier coding, agents, and professional work";
      intelligence_score = 15;
    }
    # Google — latest only
    {
      model_name = "google/gemini-3.1-pro-preview";
      aliases = [
        "gemini-pro"
        "gemini3"
        "pro-openrouter"
      ];
      context_window = 1048576;
      max_output_tokens = 65536;
      supports_extended_thinking = true;
      supports_json_mode = true;
      supports_function_calling = true;
      supports_images = true;
      max_image_size_mb = 20.0;
      allow_code_generation = true;
      description = "Gemini 3.1 Pro via OpenRouter — flagship reasoning with vision";
      intelligence_score = 18;
    }
    {
      model_name = "google/gemini-3-flash-preview";
      aliases = [
        "flash-openrouter"
        "gemini-flash-openrouter"
      ];
      context_window = 1048576;
      max_output_tokens = 65536;
      supports_extended_thinking = true;
      supports_json_mode = true;
      supports_function_calling = true;
      supports_images = true;
      max_image_size_mb = 15.0;
      description = "Gemini 3 Flash via OpenRouter — near-Pro at Flash cost";
      intelligence_score = 14;
    }
    # OpenAI — latest only
    {
      model_name = "openai/gpt-5.2";
      aliases = [ "gpt5.2-openrouter" ];
      context_window = 400000;
      max_output_tokens = 128000;
      supports_extended_thinking = true;
      supports_json_mode = true;
      supports_function_calling = true;
      supports_images = true;
      max_image_size_mb = 20.0;
      supports_temperature = true;
      temperature_constraint = "fixed";
      default_reasoning_effort = "medium";
      allow_code_generation = true;
      description = "GPT-5.2 via OpenRouter — flagship reasoning with vision";
      intelligence_score = 18;
    }
    {
      model_name = "openai/gpt-5.2-pro";
      aliases = [ "gpt5.2-pro-openrouter" ];
      context_window = 400000;
      max_output_tokens = 272000;
      supports_extended_thinking = true;
      supports_json_mode = true;
      supports_function_calling = true;
      supports_images = true;
      max_image_size_mb = 20.0;
      supports_temperature = false;
      temperature_constraint = "fixed";
      use_openai_response_api = true;
      default_reasoning_effort = "high";
      allow_code_generation = true;
      description = "GPT-5.2 Pro via OpenRouter — premium reasoning";
      intelligence_score = 18;
    }
    {
      model_name = "openai/gpt-5.1-codex";
      aliases = [ "codex-openrouter" ];
      context_window = 400000;
      max_output_tokens = 128000;
      supports_extended_thinking = true;
      supports_json_mode = true;
      supports_function_calling = true;
      supports_images = true;
      max_image_size_mb = 20.0;
      supports_temperature = true;
      temperature_constraint = "fixed";
      use_openai_response_api = true;
      default_reasoning_effort = "high";
      allow_code_generation = true;
      description = "GPT-5.1 Codex via OpenRouter — agentic coding";
      intelligence_score = 19;
    }
    {
      model_name = "openai/o4-mini";
      aliases = [
        "o4-mini-openrouter"
        "o4mini-openrouter"
      ];
      context_window = 200000;
      max_output_tokens = 100000;
      supports_extended_thinking = false;
      supports_json_mode = true;
      supports_function_calling = true;
      supports_images = true;
      max_image_size_mb = 20.0;
      supports_temperature = false;
      temperature_constraint = "fixed";
      description = "O4-mini via OpenRouter — fast reasoning with vision";
      intelligence_score = 11;
    }
    # DeepSeek
    {
      model_name = "deepseek/deepseek-r1-0528";
      aliases = [
        "deepseek-r1"
        "deepseek"
        "r1"
      ];
      context_window = 65536;
      max_output_tokens = 32768;
      supports_extended_thinking = true;
      supports_json_mode = true;
      supports_function_calling = false;
      supports_images = false;
      max_image_size_mb = 0.0;
      description = "DeepSeek R1 — advanced reasoning (text-only)";
      intelligence_score = 15;
    }
    # X.AI — latest only
    {
      model_name = "x-ai/grok-4";
      aliases = [
        "grok-4"
        "grok4"
        "grok"
      ];
      context_window = 256000;
      max_output_tokens = 256000;
      supports_extended_thinking = true;
      supports_json_mode = true;
      supports_function_calling = true;
      supports_images = true;
      max_image_size_mb = 20.0;
      supports_temperature = true;
      temperature_constraint = "range";
      description = "Grok 4 via OpenRouter — vision and advanced reasoning";
      intelligence_score = 15;
    }
    {
      model_name = "x-ai/grok-4.1-fast";
      aliases = [
        "grok-4.1-fast"
        "grok-fast"
      ];
      context_window = 2000000;
      max_output_tokens = 2000000;
      supports_extended_thinking = true;
      supports_json_mode = true;
      supports_function_calling = true;
      supports_images = true;
      max_image_size_mb = 20.0;
      supports_temperature = true;
      temperature_constraint = "range";
      description = "Grok 4.1 Fast via OpenRouter (2M context) — fast reasoning";
      intelligence_score = 15;
    }
  ];
}
