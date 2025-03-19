#!/bin/bash

monitors_count=$(hyprctl monitors -j | jq '. | length')
if [[ $monitors_count -gt 1 ]]; then
  hyprctl keyword monitor "eDP-1, disable"
fi
