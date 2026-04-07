#!/usr/bin/env bash
# Local benchmark-to-PR workflow: run benchmarks, commit results, create PR.
#
# Usage:
#   scripts/benchmarks/run-local.sh                                 # Default model, all suites
#   scripts/benchmarks/run-local.sh --model mlx-community/gemma-4-31b-it-4bit
#   scripts/benchmarks/run-local.sh --suite throughput,ttft
#   scripts/benchmarks/run-local.sh --all-models --suite throughput
#   scripts/benchmarks/run-local.sh --dry-run                       # Validate only, no inference
#   scripts/benchmarks/run-local.sh --no-pr                         # Run benchmarks but skip PR creation

set -euo pipefail

create_pr=true
benchmark_args=()

# Separate our flags from mlx-benchmark pass-through args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-pr)
      create_pr=false
      shift
      ;;
    *)
      benchmark_args+=("$1")
      shift
      ;;
  esac
done

# ──────────────────────────────────────────────────────────────────────
# Run benchmarks
# ──────────────────────────────────────────────────────────────────────
echo "Running benchmarks..."
mlx-benchmark "${benchmark_args[@]}"

# ──────────────────────────────────────────────────────────────────────
# Check for new result files
# ──────────────────────────────────────────────────────────────────────
if ! git diff --name-only --diff-filter=A -- data/benchmarks/ | grep -q '.json$'; then
  echo "No new benchmark results generated — nothing to commit."
  exit 0
fi

if ! $create_pr; then
  echo "Benchmark results written. Skipping PR creation (--no-pr)."
  git diff --stat -- data/benchmarks/ docs/
  exit 0
fi

# ──────────────────────────────────────────────────────────────────────
# Create branch, commit, and PR
# ──────────────────────────────────────────────────────────────────────
date_slug=$(date -u +%Y%m%d-%H%M)
branch="chore/benchmark-results-$date_slug"

echo "Creating branch $branch..."
git checkout -b "$branch"

git add data/benchmarks/*.json docs/mlx-benchmarks.md
git commit -m "chore(benchmarks): add local benchmark results $date_slug

(mlx-benchmark)"

echo "Pushing branch..."
git push -u origin "$branch"

echo "Creating PR..."
gh pr create \
  --title "chore(benchmarks): local benchmark results $date_slug" \
  --body "$(cat <<'EOF'
## Summary

- Local benchmark run via `scripts/benchmarks/run-local.sh`
- Results added to `data/benchmarks/`
- `docs/mlx-benchmarks.md` summary regenerated

## Test plan

- [ ] Verify result JSON files pass schema validation
- [ ] Verify docs summary tables render correctly

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)" \
  --label "type:chore,automation:dependencies"

echo "Done! PR created on branch $branch."
