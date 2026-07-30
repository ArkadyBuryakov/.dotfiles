#!/bin/bash

# jaeger: navigate to the Nth agent (1-based, same order as the panel).
#
# Usage: goto.sh <index>
#
# Uses the list cached by scan.sh (refreshed every 1.5s while the panel
# runs); rescans if the cache is stale or missing.

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <index>"
  exit 1
fi

DIR=$(dirname "$(readlink -f "$0")")
STATUS_DIR="${XDG_RUNTIME_DIR:-/tmp}/jaeger"
CACHE="$STATUS_DIR/agents.json"

agents=""
if [ -f "$CACHE" ] && [ $(($(date +%s) - $(stat -c %Y "$CACHE"))) -le 5 ]; then
  agents=$(cat "$CACHE")
else
  agents=$("$DIR/scan.sh")
fi

read -r kitty_pid win_id addr < <(jq -r --argjson i "$(($1 - 1))" \
  '.[$i] // empty | "\(.kitty_pid) \(.kitty_win_id) \(.hypr_address)"' <<<"$agents")

[ -z "$kitty_pid" ] && exit 0
exec "$DIR/focus.sh" "$kitty_pid" "$win_id" "$addr"
