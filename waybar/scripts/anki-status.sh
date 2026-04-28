#!/bin/bash
# Waybar custom module: Anki due card count
# Uses apy to sync and query. Syncs only when Anki GUI is not running (DB lock).

# Sync with AnkiWeb if Anki is not running
if ! pgrep -x anki > /dev/null 2>&1; then
    apy sync > /dev/null 2>&1
fi

# Parse due count from apy info Sum line
DUE=$(apy info 2>/dev/null | grep '^Sum' | awk '{print $(NF-3)}')

if [[ -n "$DUE" && "$DUE" -gt 0 ]] 2>/dev/null; then
    jq -cn --arg text "󱝁 $DUE due" --arg tooltip "$DUE cards due for review" \
        '{"text":$text,"tooltip":$tooltip,"class":"due"}'
fi
