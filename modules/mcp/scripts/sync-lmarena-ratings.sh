# sync-lmarena-ratings.sh
#
# Fetches LMSYS Chatbot Arena leaderboard via HuggingFace datasets-server
# and writes a flat name→Elo lookup file. SOLE source of intelligence
# scoring across all PAL model transforms — no heuristic fallbacks.
#
# Required env: CURL, JQ, OUTPUT_DIR

API="https://datasets-server.huggingface.co/filter?dataset=lmarena-ai%2Fleaderboard-dataset&config=text&split=latest&where=%22category%22%3D%27overall%27&length=100"

mkdir -p "$OUTPUT_DIR"
out="${OUTPUT_DIR}/lmarena-ratings.json"
tmp=$(mktemp) && trap 'rm -f "$tmp"' EXIT

offset=0
while :; do
  page=$("$CURL" -sf --max-time 30 "${API}&offset=${offset}") || break
  echo "$page" >> "$tmp"
  [ "$(echo "$page" | "$JQ" '.rows | length')" -lt 100 ] && break
  offset=$((offset + 100))
done

"$JQ" -s '[.[].rows[].row | {(.model_name): .rating}] | add' "$tmp" > "$out"
echo "  lmarena-ratings: $("$JQ" 'length' "$out") models"
