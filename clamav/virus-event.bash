#!/bin/bash
# Triggered by clamd VirusEvent on malware detection.
# Logs the threat as a JSON line and sends a desktop notification to all active sessions.

THREATS_LOG="/var/log/clamav/threats.log"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

VIRUS_NAME="$CLAM_VIRUSEVENT_VIRUSNAME"
FILE_PATH="$CLAM_VIRUSEVENT_FILENAME"

# Excluded paths — skip logging and notifications for known false positives
EXCLUDED_PATHS=(
    "/home/*/.cache/mozilla"
    "/home/*/.cache/zen"
    "/home/*/.config/libreoffice"
    "/usr/lib/libreoffice"
    "/usr/share/libreoffice"
)

for pattern in "${EXCLUDED_PATHS[@]}"; do
    # shellcheck disable=SC2254
    [[ "$FILE_PATH" == $pattern* ]] && exit 0
done

# Send notification to all logged-in user sessions, capturing notification IDs
ALERT="$VIRUS_NAME in $FILE_PATH"
NOTIFICATION_IDS=()

for ADDRESS in /run/user/*; do
    USERID="${ADDRESS#/run/user/}"
    NID=$(/usr/bin/sudo -u "#$USERID" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=$ADDRESS/bus" \
        /usr/bin/notify-send -u critical -c security -t 600000 -p \
        -i dialog-warning "Virus detected!" "$ALERT" 2>/dev/null) || continue
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
