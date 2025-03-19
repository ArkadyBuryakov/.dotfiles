#!/bin/bash

# Reassigns the workspaces to the correct monitor.

for ((i = 1; i <= 10; i++)); do
  hyprctl dispatch moveworkspacetomonitor $i eDP-1
done
for ((i = 11; i <= 20; i++)); do
  hyprctl dispatch moveworkspacetomonitor $i DP-1
done
