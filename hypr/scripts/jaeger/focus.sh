#!/bin/bash

# jaeger: navigate to an agent — switch hyprland workspace, focus the kitty
# os window, select its tab and activate the kitty window running the agent.
#
# Usage: focus.sh <kitty_pid> <kitty_window_id> [hypr_address]

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <kitty_pid> <kitty_window_id> [hypr_address]"
  exit 1
fi

kitty_pid="$1"
win_id="$2"
hypr_address="$3"

# Get to the right workspace first (handles special workspaces deterministically)
if [ -n "$hypr_address" ]; then
  hyprctl dispatch focuswindow "address:$hypr_address" >/dev/null
fi

# Focus the exact kitty window: selects tab + window and activates the os
# window; focus_on_activate makes hyprland follow if the address above was
# a different os window of the same kitty instance.
kitten @ --to "unix:@mykitty-$kitty_pid" focus-window --match "id:$win_id"
