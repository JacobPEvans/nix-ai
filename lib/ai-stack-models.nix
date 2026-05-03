# AI Stack — Role Registry (thin reader)
#
# Reads the canonical capability-class → physical model ID map from
# vars/ai-stack.nix. The var file holds all cross-repo runtime data
# (models, endpoints, nodeports); this helper just exposes the models
# block in the shape consumers and the lib.aiStackModels flake output
# already expect.
#
# Do NOT add data here. New model entries go in vars/ai-stack.nix.
#
# Flake-output usage from external consumers (read-only):
#   inputs.nix-ai.lib.aiStackModels
#
# Non-Nix consumers (orbstack-kubernetes, ansible, shell scripts) should
# read ~/.config/ai-stack/registry.json instead — that file is written
# from the same var file by home-manager activation.
(import ../vars/ai-stack.nix).models
