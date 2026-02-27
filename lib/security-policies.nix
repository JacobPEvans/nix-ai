# Security Policies
#
# Documents security requirements that apply across all systems.
# These are POLICIES (what we want), not configs (how to achieve it).
#
# Implementation:
# - Git: home-manager programs.git.signing.signByDefault
#
# This file serves as:
# 1. Single source of truth for security requirements
# 2. Documentation for auditing
# 3. Values that can be imported where needed

{
  # ==========================================================================
  # Git Security
  # ==========================================================================
  git = {
    # All commits must be cryptographically signed
    requireSignedCommits = true;

    # All tags must be cryptographically signed
    requireSignedTags = true;

    # Verify object integrity on transfer operations
    fsckObjects = true;
  };
}
