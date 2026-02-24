#!/bin/bash
# Weekly full-system ClamAV scan.
# Appends any findings as JSON lines to the threats log and notifies the user per threat.

THREATS_LOG="/var/log/clamav/threats.log"
SCAN_LOG="/var/log/clamav/weekly-scan.log"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

echo "[$TIMESTAMP] Starting weekly full scan" >> "$SCAN_LOG"

# Run full scan, excluding virtual/runtime filesystems
RESULTS="$(clamscan --recursive --infected \
    --exclude-dir='^/sys' \
    --exclude-dir='^/dev' \
    --exclude-dir='^/proc' \
    --exclude-dir='^/run' \
    / 2>&1)"

echo "$RESULTS" >> "$SCAN_LOG"
echo "[$TIMESTAMP] Weekly scan finished" >> "$SCAN_LOG"

# Extract FOUND lines and log each as JSON
FOUND_LINES="$(echo "$RESULTS" | grep 'FOUND$')"

if [[ -n "$FOUND_LINES" ]]; then
    while IFS= read -r line; do
        # Parse clamscan output: /path/to/file: VirusName FOUND
        FILE_PATH="${line%%:*}"
        REMAINDER="${line#*: }"
        VIRUS_NAME="${REMAINDER% FOUND}"

        # Send per-threat notification to all active sessions, capturing IDs
        ALERT="$VIRUS_NAME in $FILE_PATH"
        NOTIFICATION_IDS=()

        for ADDRESS in /run/user/*; do
            USERID="${ADDRESS#/run/user/}"
            NID=$(/usr/bin/sudo -u "#$USERID" \
                DBUS_SESSION_BUS_ADDRESS="unix:path=$ADDRESS/bus" \
                /usr/bin/notify-send -u critical -c security -t 600000 -p \
                -i dialog-warning "Weekly scan: threat found" "$ALERT" 2>/dev/null) || continue
            [[ -n "$NID" ]] && NOTIFICATION_IDS+=("$NID")
        done

        # Build JSON array of notification IDs
        NID_JSON=$(printf '%s\n' "${NOTIFICATION_IDS[@]}" | jq -Rn '[inputs | select(length > 0) | tonumber]')

        # Write JSON line to threats log
        jq -cn \
            --arg ts "$TIMESTAMP" \
            --arg vn "$VIRUS_NAME" \
            --arg fp "$FILE_PATH" \
            --argjson nids "$NID_JSON" \
            '{timestamp:$ts, virus_name:$vn, file_path:$fp, notification_ids:$nids}' \
            >> "$THREATS_LOG"
    done <<< "$FOUND_LINES"
fi
