#!/bin/bash
# Weekly full-system ClamAV scan.
# Appends any findings to the threats log and notifies the user.

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

# Extract FOUND lines and append to threats log
FOUND_LINES="$(echo "$RESULTS" | grep 'FOUND$')"

if [[ -n "$FOUND_LINES" ]]; then
    while IFS= read -r line; do
        echo "[$TIMESTAMP] $line" >> "$THREATS_LOG"
    done <<< "$FOUND_LINES"

    COUNT="$(echo "$FOUND_LINES" | wc -l)"

    # Notify all active sessions
    for ADDRESS in /run/user/*; do
        USERID="${ADDRESS#/run/user/}"
        /usr/bin/sudo -u "#$USERID" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=$ADDRESS/bus" \
            /usr/bin/notify-send -u critical -c security -t 600000 \
            -i dialog-warning "Weekly scan: $COUNT threat(s) found" \
            "Check threats log for details"
    done
fi
