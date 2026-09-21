#!/bin/bash

# Start (or restart) waybar with one bar per connected monitor.
#
# The bar layout cannot be static: which output is the primary (workspaces 1-9,
# labelled by name) and which is the secondary (workspaces 11-19, labelled 1-9)
# depends on the machine and on what is plugged in. hypr/conf/roles.lua resolves
# the roles and passes them here; either may be empty. Everything except the
# output-to-role wiring still comes from ~/.config/waybar/common.jsonc.
#
# Also used on monitor hotplug: waybar's ext/workspaces module keeps stale
# workspace buttons when workspaces switch groups (e.g. 11-19 stay on the
# primary bar after the secondary reconnects); a fresh instance binds the
# protocol anew and renders the compositor's actual state.
# Debounced via flock: hotplug can fire several events in quick succession.
# waybar is spawned with the lock fd closed (9>&-), otherwise it inherits it
# and holds the lock for its whole lifetime, blocking every later restart.

set -uo pipefail

PRIMARY="${1:-}"
SECONDARY="${2:-}"

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
CONFIG="$RUNTIME_DIR/waybar-config.jsonc"

exec 9>"$RUNTIME_DIR/waybar-restart.lock"
flock -n 9 || exit 0

sleep 1 # let Hyprland finish moving workspaces to their bound monitors

INCLUDE='"include": "~/.config/waybar/common.jsonc"'

bars=()
[[ -n "$PRIMARY" ]] && bars+=("{ \"output\": [\"$PRIMARY\"], $INCLUDE }")
if [[ -n "$SECONDARY" ]]; then
  bars+=("$(
    cat <<JSON
{
  "output": ["$SECONDARY"],
  $INCLUDE,
  "ext/workspaces": {
    "format": "{icon}",
    "format-icons": {
      "11": "1", "12": "2", "13": "3", "14": "4", "15": "5",
      "16": "6", "17": "7", "18": "8", "19": "9"
    }
  }
}
JSON
  )")
fi

# Anything without a role still gets a bar, so no screen is ever left bare.
excludes=()
[[ -n "$PRIMARY" ]] && excludes+=("\"!$PRIMARY\"")
[[ -n "$SECONDARY" ]] && excludes+=("\"!$SECONDARY\"")
outputs="$(printf '%s, ' "${excludes[@]+"${excludes[@]}"}")\"*\""
bars+=("{ \"output\": [$outputs], $INCLUDE }")

printf '[\n%s\n]\n' "$(printf '%s,\n' "${bars[@]}" | head -c -2)" >"$CONFIG"

pkill -x waybar
for _ in {1..20}; do
  pgrep -x waybar >/dev/null || break
  sleep 0.1
done

waybar -c "$CONFIG" -s ~/.config/waybar/style.css &>/dev/null 9>&- &
disown
