#!/bin/bash
# Waybar custom module: ClamAV threat status
# Checks /var/log/clamav/threats.log (JSON lines) and outputs JSON for waybar.

THREATS_LOG="/var/log/clamav/threats.log"

if [[ -s "$THREATS_LOG" ]]; then
  COUNT=$(wc -l <"$THREATS_LOG")
  TOOLTIP="$(tail -5 "$THREATS_LOG" | jq -r '"\(.timestamp) \(.virus_name) \(.file_path)"' 2>/dev/null | sed 's/"/\\"/g' | paste -sd '\n')"
  echo "{\"text\": \"󰃤 ${COUNT}!\", \"tooltip\": \"$TOOLTIP\", \"class\": \"threat\"}"
# else
#   echo "{\"text\": \"󱏛\", \"tooltip\": \"No threats detected\", \"class\": \"safe\"}"
fi
