# PAL MCP — Curated Gemini & OpenAI Model Definitions (LATEST ONLY)
#
# Static model metadata imported by pal-models.nix and serialized to JSON.
# Update these when new model versions are released.
# OpenRouter models are in pal-model-defs-openrouter.nix.
{
  gemini.models = [
    {
      model_name = "gemini-3.1-pro-preview";
      friendly_name = "Gemini 3.1 Pro Preview";
      aliases = [
        "pro"
        "gemini3"
        "gemini-pro"
        "gemini"
      ];
      intelligence_score = 18;
      description = "Flagship reasoning (1M context) — enhanced SWE, agentic reliability";
      context_window = 1048576;
      max_output_tokens = 65536;
      max_thinking_tokens = 32768;
      supports_extended_thinking = true;
      supports_system_prompts = true;
      supports_streaming = true;
      supports_function_calling = true;
      supports_json_mode = true;
      supports_images = true;
      supports_temperature = true;
      allow_code_generation = true;
      max_image_size_mb = 32.0;
    }
    {
      model_name = "gemini-3-flash-preview";
      friendly_name = "Gemini 3 Flash Preview";
      aliases = [
        "flash"
        "flash3"
        "gemini-flash"
      ];
      intelligence_score = 14;
      description = "Fast frontier-class (1M context) — near-Pro reasoning at Flash cost";
      context_window = 1048576;
      max_output_tokens = 65536;
      max_thinking_tokens = 24576;
      supports_extended_thinking = true;
      supports_system_prompts = true;
      supports_streaming = true;
      supports_function_calling = true;
      supports_json_mode = true;
      supports_images = true;
      supports_temperature = true;
      max_image_size_mb = 20.0;
    }
  ];

  openai.models = [
    {
      model_name = "gpt-5.2";
      friendly_name = "OpenAI (GPT-5.2)";
      aliases = [
        "gpt5.2"
        "gpt-5.2"
        "5.2"
      ];
      intelligence_score = 18;
      description = "GPT-5.2 (400K, 128K out) — Flagship reasoning with vision";
      context_window = 400000;
      max_output_tokens = 128000;
      supports_extended_thinking = true;
      supports_system_prompts = true;
      supports_streaming = true;
      supports_function_calling = true;
      supports_json_mode = true;
      supports_images = true;
      supports_temperature = true;
      max_image_size_mb = 20.0;
      default_reasoning_effort = "medium";
      allow_code_generation = true;
      temperature_constraint = "fixed";
    }
    {
      model_name = "gpt-5.2-pro";
      friendly_name = "OpenAI (GPT-5.2 Pro)";
      aliases = [
        "gpt5.2-pro"
        "gpt5.2pro"
        "gpt5pro"
        "gpt5-pro"
      ];
      intelligence_score = 18;
      description = "GPT-5.2 Pro (400K, 272K out) — Premium reasoning";
      context_window = 400000;
      max_output_tokens = 272000;
      supports_extended_thinking = true;
      supports_system_prompts = true;
      supports_streaming = false;
      supports_function_calling = true;
      supports_json_mode = true;
      supports_images = true;
      supports_temperature = true;
      max_image_size_mb = 20.0;
      use_openai_response_api = true;
      default_reasoning_effort = "high";
      allow_code_generation = true;
      temperature_constraint = "fixed";
    }
    {
      model_name = "gpt-5.1-codex";
      friendly_name = "OpenAI (GPT-5.1 Codex)";
      aliases = [
        "gpt5.1-codex"
        "codex"
        "gpt-5.1-code"
        "codex-5.1"
      ];
      intelligence_score = 19;
      description = "GPT-5.1 Codex (400K, 128K out) — Agentic coding";
      context_window = 400000;
      max_output_tokens = 128000;
      supports_extended_thinking = true;
      supports_system_prompts = true;
      supports_streaming = false;
      supports_function_calling = true;
      supports_json_mode = true;
      supports_images = true;
      supports_temperature = true;
      max_image_size_mb = 20.0;
      use_openai_response_api = true;
      default_reasoning_effort = "high";
      allow_code_generation = true;
      temperature_constraint = "fixed";
    }
    {
      model_name = "gpt-5.1-codex-mini";
      friendly_name = "OpenAI (GPT-5.1 Codex mini)";
      aliases = [
        "gpt5.1-codex-mini"
        "codex-mini"
        "5.1-codex-mini"
      ];
      intelligence_score = 16;
      description = "GPT-5.1 Codex mini (400K, 128K out) — Cost-efficient coding";
      context_window = 400000;
      max_output_tokens = 128000;
      supports_extended_thinking = true;
      supports_system_prompts = true;
      supports_streaming = true;
      supports_function_calling = true;
      supports_json_mode = true;
      supports_images = true;
      supports_temperature = true;
      max_image_size_mb = 20.0;
      allow_code_generation = true;
      temperature_constraint = "fixed";
    }
    {
      model_name = "gpt-5-codex";
      friendly_name = "OpenAI (GPT-5 Codex)";
      aliases = [
        "gpt5-codex"
        "gpt-5-code"
        "gpt5-code"
      ];
      intelligence_score = 17;
      description = "GPT-5 Codex (400K) — Coding and software architecture";
      context_window = 400000;
      max_output_tokens = 128000;
      supports_extended_thinking = true;
      supports_system_prompts = true;
      supports_streaming = true;
      supports_function_calling = true;
      supports_json_mode = true;
      supports_images = true;
      supports_temperature = true;
      max_image_size_mb = 20.0;
      use_openai_response_api = true;
    }
    {
      model_name = "gpt-5";
      friendly_name = "OpenAI (GPT-5)";
      aliases = [ "gpt5" ];
      intelligence_score = 16;
      description = "GPT-5 (400K, 128K out) — Advanced reasoning";
      context_window = 400000;
      max_output_tokens = 128000;
      supports_extended_thinking = true;
      supports_system_prompts = true;
      supports_streaming = false;
      supports_function_calling = true;
      supports_json_mode = true;
      supports_images = true;
      supports_temperature = true;
      max_image_size_mb = 20.0;
      temperature_constraint = "fixed";
    }
    {
      model_name = "gpt-5-mini";
      friendly_name = "OpenAI (GPT-5-mini)";
      aliases = [
        "gpt5-mini"
        "gpt5mini"
        "mini"
      ];
      intelligence_score = 15;
      description = "GPT-5-mini (400K, 128K out) — Efficient reasoning";
      context_window = 400000;
      max_output_tokens = 128000;
      supports_extended_thinking = true;
      supports_system_prompts = true;
      supports_streaming = false;
      supports_function_calling = true;
      supports_json_mode = true;
      supports_images = true;
      supports_temperature = true;
      max_image_size_mb = 20.0;
      temperature_constraint = "fixed";
    }
    {
      model_name = "o4-mini";
      friendly_name = "OpenAI (O4-mini)";
      aliases = [ "o4mini" ];
      intelligence_score = 11;
      description = "O4-mini (200K) — Fast reasoning";
      context_window = 200000;
      supports_extended_thinking = false;
      supports_system_prompts = true;
      supports_streaming = true;
      supports_function_calling = true;
      supports_json_mode = true;
      supports_images = true;
      supports_temperature = false;
      max_image_size_mb = 20.0;
      temperature_constraint = "fixed";
    }
  ];
}
