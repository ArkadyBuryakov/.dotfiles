#!/bin/bash
# Full-system ClamAV scan using clamdscan.
# Appends any findings as JSON lines to the threats log and notifies the user per threat.
# Inhibits sleep for the duration of the scan.
# Writes a live state file for TUI progress tracking and appends to scan history on exit.

THREATS_LOG="/var/log/clamav/threats.log"
SCAN_LOG="/var/log/clamav/weekly-scan.log"
LAST_SCAN_TS_FILE="/var/log/clamav/last-scan-timestamp"
SCAN_STATE="/var/log/clamav/scan-state.json"
SCAN_HISTORY="/var/log/clamav/scan-history.log"
SCAN_OUTPUT=$(mktemp)
START_EPOCH=$(date +%s)
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
SCAN_COMPLETED=false
MONITOR_PID=""
INHIBIT_PID=""

echo "[$TIMESTAMP] Starting full scan" >> "$SCAN_LOG"

# Build list of top-level dirs, skipping virtual/runtime filesystems
EXCLUSIONS=(/sys /dev /proc /run)
SCAN_DIRS=()
for d in /*; do
    skip=false
    for ex in "${EXCLUSIONS[@]}"; do
        [[ "$d" == "$ex" ]] && { skip=true; break; }
    done
    $skip && continue
    [[ -d "$d" ]] && SCAN_DIRS+=("$d")
done

# Build scope JSON
SCOPE_PATHS=$(printf '%s\n' "${SCAN_DIRS[@]}" | jq -Rn '[inputs]')
SCOPE_EXCL=$(printf '%s\n' "${EXCLUSIONS[@]}" | jq -Rn '[inputs]')

# Write initial state file
jq -cn \
    --argjson pid "$$" \
    --arg start "$TIMESTAMP" \
    --argjson paths "$SCOPE_PATHS" \
    --argjson excl "$SCOPE_EXCL" \
    --arg activity "$TIMESTAMP" \
    '{pid:$pid, start:$start, scope:{paths:$paths, exclusions:$excl}, files_scanned:0, last_activity:$activity}' \
    > "$SCAN_STATE"

# EXIT trap: write history entry and clean up
write_history() {
    # Kill monitor if alive
    if [[ -n "$MONITOR_PID" ]] && kill -0 "$MONITOR_PID" 2>/dev/null; then
        kill "$MONITOR_PID" 2>/dev/null
        wait "$MONITOR_PID" 2>/dev/null || true
    fi

    # Release inhibit lock if held
    if [[ -n "$INHIBIT_PID" ]] && kill -0 "$INHIBIT_PID" 2>/dev/null; then
        kill "$INHIBIT_PID" 2>/dev/null
        wait "$INHIBIT_PID" 2>/dev/null || true
    fi

    local end_ts end_epoch duration_s status threats_found
    end_ts="$(date '+%Y-%m-%d %H:%M:%S')"
    end_epoch=$(date +%s)
    duration_s=$((end_epoch - START_EPOCH))

    # Format duration
    local h=$((duration_s / 3600))
    local m=$(( (duration_s % 3600) / 60 ))
    local s=$((duration_s % 60))
    local duration_fmt=""
    (( h > 0 )) && duration_fmt="${h}h "
    (( m > 0 )) && duration_fmt="${duration_fmt}${m}m "
    duration_fmt="${duration_fmt}${s}s"

    if $SCAN_COMPLETED; then
        status="completed"
    else
        status="interrupted"
    fi

    # Count FOUND lines
    threats_found=$(grep -c 'FOUND$' "$SCAN_OUTPUT" 2>/dev/null) || threats_found=0

    # Append history entry
    jq -cn \
        --arg start "$TIMESTAMP" \
        --arg end "$end_ts" \
        --arg status "$status" \
        --argjson threats "$threats_found" \
        --arg duration "$duration_fmt" \
        --argjson paths "$SCOPE_PATHS" \
        --argjson excl "$SCOPE_EXCL" \
        '{start:$start, end:$end, status:$status, threats_found:$threats, duration:$duration, scope:{paths:$paths, exclusions:$excl}}' \
        >> "$SCAN_HISTORY"

    # Record completion timestamp
    date '+%Y-%m-%d %H:%M:%S' > "$LAST_SCAN_TS_FILE"

    # Clean up
    rm -f "$SCAN_STATE" "$SCAN_STATE.curdir" "$SCAN_OUTPUT"
}

trap write_history EXIT

# Background progress monitor: updates state file every 2s
progress_monitor() {
    while true; do
        sleep 2
        if [[ -f "$SCAN_OUTPUT" ]]; then
            local scanned now_ts curdir
            scanned=$(wc -l < "$SCAN_OUTPUT" 2>/dev/null) || scanned=0
            now_ts="$(date '+%Y-%m-%d %H:%M:%S')"
            curdir=""
            [[ -f "$SCAN_STATE.curdir" ]] && curdir=$(cat "$SCAN_STATE.curdir" 2>/dev/null) || true
            if [[ -f "$SCAN_STATE" ]]; then
                jq -c \
                    --argjson scanned "$scanned" \
                    --arg activity "$now_ts" \
                    --arg curdir "${curdir:-}" \
                    '.files_scanned=$scanned | .last_activity=$activity | .current_dir=$curdir' \
                    "$SCAN_STATE" > "$SCAN_STATE.tmp" 2>/dev/null \
                    && mv "$SCAN_STATE.tmp" "$SCAN_STATE"
            fi
        fi
    done
}

progress_monitor &
MONITOR_PID=$!

# Inhibit sleep for the duration of the scan
systemd-inhibit --what=sleep --who="ClamAV" --why="Full system scan" --mode=block \
    sleep infinity &
INHIBIT_PID=$!

# Scan each top-level directory individually so output flushes between directories,
# giving the progress monitor more accurate file counts.
for dir in "${SCAN_DIRS[@]}"; do
    printf '%s' "$dir" > "$SCAN_STATE.curdir" 2>/dev/null || true
    clamdscan --multiscan --fdpass "$dir" >> "$SCAN_OUTPUT" 2>&1 || true
done

# Release sleep inhibit lock
kill "$INHIBIT_PID" 2>/dev/null
wait "$INHIBIT_PID" 2>/dev/null || true
INHIBIT_PID=""

# Kill monitor
if kill -0 "$MONITOR_PID" 2>/dev/null; then
    kill "$MONITOR_PID" 2>/dev/null
    wait "$MONITOR_PID" 2>/dev/null || true
fi
MONITOR_PID=""

SCAN_COMPLETED=true

echo "[$TIMESTAMP] Full scan finished" >> "$SCAN_LOG"

# Extract FOUND lines and log each as JSON
FOUND_LINES="$(grep 'FOUND$' "$SCAN_OUTPUT")" || true

if [[ -n "$FOUND_LINES" ]]; then
    while IFS= read -r line; do
        # Parse clamdscan output: /path/to/file: VirusName FOUND
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
                -i dialog-warning "Scan: threat found" "$ALERT" 2>/dev/null) || continue
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
