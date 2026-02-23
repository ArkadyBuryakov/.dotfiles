#!/bin/bash
# Waybar custom module: ClamAV threat status
# Checks /var/log/clamav/threats.log and outputs JSON for waybar.

THREATS_LOG="/var/log/clamav/threats.log"

if [[ -s "$THREATS_LOG" ]]; then
    TOOLTIP="$(tail -5 "$THREATS_LOG" | sed 's/"/\\"/g' | paste -sd '\n')"
    echo "{\"text\": \"󰃤\", \"tooltip\": \"$TOOLTIP\", \"class\": \"threat\"}"
else
    echo "{\"text\": \"󱏛\", \"tooltip\": \"No threats detected\", \"class\": \"safe\"}"
fi
