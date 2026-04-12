#!/usr/bin/env bash
# sync-lmarena-ratings.sh
#
# Fetches LMSYS Chatbot Arena leaderboard via HuggingFace datasets-server
# and writes a flat name→Elo lookup file. SOLE source of intelligence
# scoring across all PAL model transforms — no heuristic fallbacks.
#
# Run as a subprocess (never source): bash "${SCRIPTS_DIR}/sync-lmarena-ratings.sh"
# Required env: CURL, JQ, OUTPUT_DIR

set -eu

api="https://datasets-server.huggingface.co/filter?dataset=lmarena-ai%2Fleaderboard-dataset&config=text&split=latest&where=%22category%22%3D%27overall%27&length=100"

mkdir -p "$OUTPUT_DIR"
final="${OUTPUT_DIR}/lmarena-ratings.json"
work=$(mktemp -d)
pages="${work}/pages.jsonl"
staged="${work}/staged.json"

offset=0
while :; do
  page=$("$CURL" -sf --max-time 30 "${api}&offset=${offset}") || { rm -rf "$work"; exit 1; }
  printf '%s\n' "$page" >> "$pages"
  [ "$(printf '%s' "$page" | "$JQ" '.rows | length')" -lt 100 ] && break
  offset=$((offset + 100))
done

"$JQ" -s '[.[].rows[].row | {(.model_name): .rating}] | add // {}' "$pages" > "$staged"

count=$("$JQ" 'length' "$staged")
if [ "$count" -gt 0 ]; then
  mv "$staged" "$final"
  echo "  lmarena-ratings: ${count} models"
else
  echo "  WARN: LMSYS arena returned 0 models — preserving previous ratings file" >&2
fi
rm -rf "$work"
