#!/bin/bash
# Triggered by clamd VirusEvent on malware detection.
# Logs the threat and sends a desktop notification to all active sessions.

THREATS_LOG="/var/log/clamav/threats.log"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# Append to dedicated threats log
echo "[$TIMESTAMP] FOUND: $CLAM_VIRUSEVENT_VIRUSNAME in $CLAM_VIRUSEVENT_FILENAME" >> "$THREATS_LOG"

# Send notification to all logged-in user sessions
ALERT="$CLAM_VIRUSEVENT_VIRUSNAME in $CLAM_VIRUSEVENT_FILENAME"

for ADDRESS in /run/user/*; do
    USERID="${ADDRESS#/run/user/}"
    /usr/bin/sudo -u "#$USERID" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=$ADDRESS/bus" \
        /usr/bin/notify-send -u critical -c security -t 600000 \
        -i dialog-warning "Virus detected!" "$ALERT"
done
