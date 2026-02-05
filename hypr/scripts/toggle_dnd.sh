#!/bin/bash

current_modes=$(makoctl mode)

if echo "$current_modes" | grep -q "do-not-disturb"; then
  makoctl mode -r do-not-disturb
  notify-send -c system "󰂚  Do not disturb: OFF"
else
  makoctl mode -a do-not-disturb
  notify-send -c system "󰂛  Do not disturb: ON"
fi
