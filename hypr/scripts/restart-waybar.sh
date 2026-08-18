#!/bin/bash

# Restart waybar after monitor hotplug. Its ext/workspaces module keeps
# stale workspace buttons when workspaces switch groups (e.g. 11-19 stay
# on the eDP-1 bar after DP-1 reconnects); a fresh instance binds the
# protocol anew and renders the compositor's actual state.
# Debounced via flock: hotplug can fire several events in quick succession.

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/waybar-restart.lock"
flock -n 9 || exit 0

sleep 1 # let Hyprland finish moving workspaces to their bound monitors

pkill -x waybar
for _ in {1..20}; do
  pgrep -x waybar >/dev/null || break
  sleep 0.1
done

waybar &>/dev/null &
disown
