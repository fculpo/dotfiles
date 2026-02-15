#!/bin/bash
# Usage: usage.sh <metric>
#   metric: session | weekly | sonnet

METRIC="${1:-session}"
mkdir -p "$HOME/.cache"
CACHE_DIR="$HOME/.cache"
CACHE_FILE="$CACHE_DIR/ccstatusline-usage.json"
LOCK_FILE="$CACHE_DIR/ccstatusline-usage.lock"

make_bar() {
  local pct="$1"
  local width=10
  local filled=$((pct * width / 100))
  local empty=$((width - filled))
  printf "["
  [[ $filled -gt 0 ]] && printf "█%.0s" $(seq 1 "$filled")
  [[ $empty -gt 0 ]] && printf "░%.0s" $(seq 1 "$empty")
  printf "]"
}

# Fetch and cache the full API response (shared across all widgets)
fetch_usage() {
  # Use cached response if < 180 seconds old
  if [[ -f "$CACHE_FILE" ]]; then
    AGE=$(($(date +%s) - $(stat -c '%Y' "$CACHE_FILE")))
    [[ $AGE -lt 180 ]] && return 0
  fi

  # Rate limit: only try API once per 30 seconds
  if [[ -f "$LOCK_FILE" ]]; then
    LOCK_AGE=$(($(date +%s) - $(stat -c '%Y' "$LOCK_FILE")))
    [[ $LOCK_AGE -lt 30 ]] && return 0
  fi
  touch "$LOCK_FILE"

  TOKEN="$(jq -r '.claudeAiOauth.accessToken // empty' ~/.claude/.credentials.json 2>/dev/null)"
  [[ -z "$TOKEN" ]] && return 1

  RESPONSE=$(curl -s --max-time 3 "https://api.anthropic.com/api/oauth/usage" \
    -H "Authorization: Bearer $TOKEN" \
    -H "anthropic-beta: oauth-2025-04-20" 2>/dev/null)

  [[ -z "$RESPONSE" ]] && return 1

  echo "$RESPONSE" > "$CACHE_FILE"
}

fetch_usage

if [[ ! -f "$CACHE_FILE" ]]; then
  echo "[No data]"
  exit 1
fi

DATA=$(cat "$CACHE_FILE")

case "$METRIC" in
  session)
    VAL=$(echo "$DATA" | jq -r '.five_hour.utilization // empty' 2>/dev/null)
    LABEL="5h"
    ;;
  weekly)
    VAL=$(echo "$DATA" | jq -r '.seven_day.utilization // empty' 2>/dev/null)
    LABEL="7d"
    ;;
  sonnet)
    VAL=$(echo "$DATA" | jq -r '.seven_day_sonnet.utilization // empty' 2>/dev/null)
    LABEL="Son"
    ;;
  *)
    echo "[Bad metric]"
    exit 1
    ;;
esac

if [[ -z "$VAL" || "$VAL" == "null" ]]; then
  echo "$LABEL: --"
  exit 0
fi

VAL_INT=${VAL%.*}
BAR=$(make_bar "$VAL_INT")
echo "$LABEL: $BAR ${VAL}%"
