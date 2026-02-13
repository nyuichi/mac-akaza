#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/akaza-repl.sh [OPTIONS]

Options:
  --server PATH    Path to akaza-server binary
  --model PATH     Path to model directory
  -h, --help       Show this help

Commands (in REPL):
  <ひらがな>       Convert and show top candidates separated by |
  :extend N        Extend clause N by one character and reconvert
  :shrink N        Shrink clause N by one character and reconvert
  :json            Show last result as raw JSON
  :quit            Exit
  Ctrl-D           Exit
EOF
}

# Defaults
SERVER=""
MODEL="${HOME}/Library/Input Methods/Akaza.app/Contents/Resources/model"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --server)
      SERVER="$2"
      shift 2
      ;;
    --model)
      MODEL="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# Find server binary
if [[ -z "$SERVER" ]]; then
  if [[ -x "./target/debug/akaza-server" ]]; then
    SERVER="./target/debug/akaza-server"
  elif [[ -x "${HOME}/Library/Input Methods/Akaza.app/Contents/MacOS/akaza-server" ]]; then
    SERVER="${HOME}/Library/Input Methods/Akaza.app/Contents/MacOS/akaza-server"
  else
    echo "Error: akaza-server not found. Use --server to specify the path." >&2
    exit 1
  fi
fi

# Check dependencies
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install with: brew install jq" >&2
  exit 1
fi

# Create fifos for communicating with akaza-server
TMPDIR_REPL=$(mktemp -d)
FIFO_IN="${TMPDIR_REPL}/stdin"
FIFO_OUT="${TMPDIR_REPL}/stdout"
mkfifo "$FIFO_IN" "$FIFO_OUT"

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -rf "$TMPDIR_REPL"
}
trap cleanup EXIT

# Start akaza-server as a long-running process
"$SERVER" "$MODEL" < "$FIFO_IN" > "$FIFO_OUT" 2>/dev/null &
SERVER_PID=$!

# Open file descriptors for read/write
exec 3>"$FIFO_IN"
exec 4<"$FIFO_OUT"

# Send a JSON-RPC request and read one line of response
send_request() {
  local request="$1"
  echo "$request" >&3
  read -r response <&4
  echo "$response"
}

# State
REQUEST_ID=0
LAST_YOMI=""
LAST_RESPONSE=""
LAST_CLAUSES=""  # JSON array of clause yomi strings

# Convert yomi with optional force_ranges
do_convert() {
  local yomi="$1"
  local force_ranges="${2:-}"
  REQUEST_ID=$((REQUEST_ID + 1))

  local request
  if [[ -n "$force_ranges" ]]; then
    request=$(jq -n -c \
      --arg yomi "$yomi" \
      --argjson id "$REQUEST_ID" \
      --argjson ranges "$force_ranges" \
      '{"jsonrpc":"2.0","id":$id,"method":"convert","params":{"yomi":$yomi,"force_ranges":$ranges}}')
  else
    request=$(jq -n -c \
      --arg yomi "$yomi" \
      --argjson id "$REQUEST_ID" \
      '{"jsonrpc":"2.0","id":$id,"method":"convert","params":{"yomi":$yomi}}')
  fi

  LAST_RESPONSE=$(send_request "$request")
  LAST_YOMI="$yomi"

  # Check for error
  if echo "$LAST_RESPONSE" | jq -e '.error' &>/dev/null; then
    echo "Error: $(echo "$LAST_RESPONSE" | jq -r '.error.message // .error')"
    return 1
  fi

  # Extract clause yomi list for extend/shrink
  LAST_CLAUSES=$(echo "$LAST_RESPONSE" | jq -c '[.result[] | .[0].yomi]')

  # Display: top candidate per clause, joined by |
  echo "$LAST_RESPONSE" | jq -r '.result | [.[] | .[0].surface] | join("|")'
}

# Build force_ranges from clause yomi list
build_force_ranges() {
  local clauses_json="$1"
  echo "$clauses_json" | jq -c '
    reduce .[] as $yomi (
      {pos: 0, ranges: []};
      .ranges += [[.pos, .pos + ($yomi | length)]] | .pos += ($yomi | length)
    ) | .ranges'
}

echo "akaza REPL (type :quit or Ctrl-D to exit)"
echo "server: $SERVER"
echo "model: $MODEL"
echo ""

while true; do
  if ! read -r -p "akaza> " line; then
    echo ""
    break
  fi

  # Skip empty lines
  [[ -z "$line" ]] && continue

  case "$line" in
    :quit|:exit|:q)
      break
      ;;
    :json)
      if [[ -z "$LAST_RESPONSE" ]]; then
        echo "No previous result."
      else
        echo "$LAST_RESPONSE" | jq '.result'
      fi
      ;;
    :extend\ *)
      if [[ -z "$LAST_CLAUSES" ]]; then
        echo "No previous result. Convert something first."
        continue
      fi
      clause_idx=${line#:extend }
      clause_idx=$(echo "$clause_idx" | tr -d ' ')

      num_clauses=$(echo "$LAST_CLAUSES" | jq 'length')
      if [[ "$clause_idx" -ge "$num_clauses" ]] || [[ "$clause_idx" -lt 0 ]]; then
        echo "Invalid clause index. Valid range: 0-$((num_clauses - 1))"
        continue
      fi

      next_idx=$((clause_idx + 1))
      if [[ "$next_idx" -ge "$num_clauses" ]]; then
        echo "Cannot extend: no next clause to take from."
        continue
      fi

      # Move one character from next clause to current clause
      LAST_CLAUSES=$(echo "$LAST_CLAUSES" | jq -c --argjson i "$clause_idx" '
        .[$i] as $cur | .[$i+1] as $nxt |
        if ($nxt | length) <= 1 then
          # Merge the next clause entirely into current
          .[$i] = ($cur + $nxt) | del(.[$i+1])
        else
          ($nxt | split("") | .[0:1] | join("")) as $ch |
          .[$i] = ($cur + $ch) |
          .[$i+1] = ($nxt | split("") | .[1:] | join(""))
        end
      ')

      force_ranges=$(build_force_ranges "$LAST_CLAUSES")
      do_convert "$LAST_YOMI" "$force_ranges"
      ;;
    :shrink\ *)
      if [[ -z "$LAST_CLAUSES" ]]; then
        echo "No previous result. Convert something first."
        continue
      fi
      clause_idx=${line#:shrink }
      clause_idx=$(echo "$clause_idx" | tr -d ' ')

      num_clauses=$(echo "$LAST_CLAUSES" | jq 'length')
      if [[ "$clause_idx" -ge "$num_clauses" ]] || [[ "$clause_idx" -lt 0 ]]; then
        echo "Invalid clause index. Valid range: 0-$((num_clauses - 1))"
        continue
      fi

      cur_len=$(echo "$LAST_CLAUSES" | jq -r --argjson i "$clause_idx" '.[$i] | length')
      if [[ "$cur_len" -le 1 ]]; then
        echo "Cannot shrink: clause is already 1 character."
        continue
      fi

      next_idx=$((clause_idx + 1))
      # Move last character of current clause to next clause (or create new clause)
      LAST_CLAUSES=$(echo "$LAST_CLAUSES" | jq -c --argjson i "$clause_idx" --argjson nxt "$next_idx" --argjson total "$num_clauses" '
        .[$i] as $cur |
        ($cur | split("") | .[-1:] | join("")) as $ch |
        .[$i] = ($cur | split("") | .[:-1] | join("")) |
        if $nxt < $total then
          .[$nxt] = ($ch + .[$nxt])
        else
          . + [$ch]
        end
      ')

      force_ranges=$(build_force_ranges "$LAST_CLAUSES")
      do_convert "$LAST_YOMI" "$force_ranges"
      ;;
    :*)
      echo "Unknown command: $line"
      echo "Available: :extend N, :shrink N, :json, :quit"
      ;;
    *)
      do_convert "$line"
      ;;
  esac
done
