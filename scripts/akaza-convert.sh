#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/akaza-convert.sh [OPTIONS] "よみがな"
  echo "よみがな" | ./scripts/akaza-convert.sh [OPTIONS]

Options:
  --json                 Output raw JSON response
  --force-ranges JSON    Specify force_ranges (e.g. '[[0,9],[9,12]]')
  --server PATH          Path to akaza-server binary
  --model PATH           Path to model directory
  -h, --help             Show this help
EOF
}

# Defaults
JSON_OUTPUT=false
FORCE_RANGES=""
SERVER=""
MODEL="${HOME}/Library/Input Methods/Akaza.app/Contents/Resources/model"

# Parse arguments
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      JSON_OUTPUT=true
      shift
      ;;
    --force-ranges)
      FORCE_RANGES="$2"
      shift 2
      ;;
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
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      POSITIONAL+=("$1")
      shift
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

# Get input: from argument or stdin
if [[ ${#POSITIONAL[@]} -gt 0 ]]; then
  YOMI="${POSITIONAL[0]}"
elif [[ ! -t 0 ]]; then
  read -r YOMI
else
  echo "Error: No input provided. Pass yomi as argument or via stdin." >&2
  usage >&2
  exit 1
fi

if [[ -z "$YOMI" ]]; then
  echo "Error: Empty input." >&2
  exit 1
fi

# Build JSON-RPC request
if [[ -n "$FORCE_RANGES" ]]; then
  REQUEST=$(jq -n -c \
    --arg yomi "$YOMI" \
    --argjson ranges "$FORCE_RANGES" \
    '{"jsonrpc":"2.0","id":1,"method":"convert","params":{"yomi":$yomi,"force_ranges":$ranges}}')
else
  REQUEST=$(jq -n -c \
    --arg yomi "$YOMI" \
    '{"jsonrpc":"2.0","id":1,"method":"convert","params":{"yomi":$yomi}}')
fi

# Start akaza-server, send request, read response
RESPONSE=$( echo "$REQUEST" | "$SERVER" "$MODEL" 2>/dev/null | head -1 )

if [[ -z "$RESPONSE" ]]; then
  echo "Error: No response from akaza-server." >&2
  exit 1
fi

# Check for JSON-RPC error
if echo "$RESPONSE" | jq -e '.error' &>/dev/null; then
  echo "Error from server:" >&2
  echo "$RESPONSE" | jq '.error' >&2
  exit 1
fi

# Output
if [[ "$JSON_OUTPUT" == true ]]; then
  echo "$RESPONSE" | jq '.result'
else
  echo "$RESPONSE" | jq -r '.result | [.[] | .[0].surface] | join("|")'
fi
