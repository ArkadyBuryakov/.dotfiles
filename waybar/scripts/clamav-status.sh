#!/bin/bash
# Waybar custom module: ClamAV threat status
# Checks /var/log/clamav/threats.log (JSON lines) and outputs JSON for waybar.
# Shows stale warning when last scan is >30 days ago or never run.

THREATS_LOG="/var/log/clamav/threats.log"
LAST_SCAN_TS_FILE="/var/log/clamav/last-scan-timestamp"

if [[ -s "$THREATS_LOG" ]]; then
  COUNT=$(wc -l <"$THREATS_LOG")
  TOOLTIP="$(tail -5 "$THREATS_LOG" | jq -r '"\(.timestamp) \(.virus_name) \(.file_path)"' 2>/dev/null)"
  jq -cn --arg text "󰃤 ${COUNT}!" --arg tooltip "$TOOLTIP" '{"text":$text,"tooltip":$tooltip,"class":"threat"}'
elif [[ ! -f "$LAST_SCAN_TS_FILE" || ! -s "$LAST_SCAN_TS_FILE" ]]; then
  echo "{\"text\": \"󱏛\", \"tooltip\": \"No scan has been run\", \"class\": \"stale\"}"
else
  LAST_SCAN="$(cat "$LAST_SCAN_TS_FILE")"
  LAST_EPOCH=$(date -d "$LAST_SCAN" +%s 2>/dev/null) || LAST_EPOCH=0
  NOW_EPOCH=$(date +%s)
  AGE_DAYS=$(( (NOW_EPOCH - LAST_EPOCH) / 86400 ))
  if (( AGE_DAYS > 30 )); then
    echo "{\"text\": \"󱏛\", \"tooltip\": \"Last scan: ${AGE_DAYS} days ago\", \"class\": \"stale\"}"
  fi
fi
