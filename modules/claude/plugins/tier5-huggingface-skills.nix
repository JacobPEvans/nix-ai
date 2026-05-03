# Marketplace: huggingface-skills
# Source: github.com/huggingface/skills
# Stars (verified 2026-05-02): 10371
# Priority Tier: 5 (Niche — HF Hub operations)
#
# Duplicate Resolution Rule:
#   Variants from this marketplace are SUPERSEDED by ALL higher tiers.
#
# Kept for hf CLI Hub operations (download/upload models, manage repos) —
# user actively does HF model ops in nix-ai (MLX work).

_:

{
  enabledPlugins = {
    "hf-cli@huggingface-skills" = true;
  };
}
