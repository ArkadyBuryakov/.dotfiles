#!/bin/bash

# This script selects 1-10 numbered workspaces for the focused monitor.
# Set swap_monitor to true to change target monitor.

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "Usage: $0 <dispatcher_command> <workspace_number> [swap_monitor_flag:true|false]"
  exit 1
fi

dispatcher="$1"
workspace="$2"
swap_monitor="${3:-false}"
target_monitor=$(hyprctl monitors -j | jq '.[] | select(.focused==true) | .id')

if [ "$swap_monitor" = "true" ]; then
  # Swap the target monitor to the workspace
  target_monitor=$(((target_monitor + 1) % 2))
fi

workspace=$((workspace + target_monitor * 10))

# Build and execute the hyprctl command
hyprctl dispatch $dispatcher $workspace
