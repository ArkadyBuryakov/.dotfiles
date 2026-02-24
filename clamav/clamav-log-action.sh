#!/bin/bash
# Privileged helper for ClamAV Threat Manager.
# Performs validated operations on clamav log files and threat files.
# Invoked via pkexec from the threat-manager TUI.
#
# Commands:
#   remove-entry <line>    - Remove exact line from threats.log
#   delete-threat <path>   - Delete a file referenced in threats.log (+ quarantine copy)
#   log-action <entry>     - Append entry to actions.log
#   finalize-scan          - Finalize a stale scan state file (silently killed scan)

set -euo pipefail

THREATS_LOG="/var/log/clamav/threats.log"
ACTIONS_LOG="/var/log/clamav/actions.log"
SCAN_STATE="/var/log/clamav/scan-state.json"
SCAN_HISTORY="/var/log/clamav/scan-history.log"

case "${1:-}" in
    remove-entry)
        [[ -z "${2:-}" ]] && { echo "ERROR: No entry specified" >&2; exit 1; }
        LINE="$2"
        # Already gone — treat as success
        if ! grep -qFx -- "$LINE" "$THREATS_LOG" 2>/dev/null; then
            exit 0
        fi
        grep -vFx -- "$LINE" "$THREATS_LOG" > "$THREATS_LOG.tmp" || true
        mv -- "$THREATS_LOG.tmp" "$THREATS_LOG"
        chown clamav:clamav "$THREATS_LOG"
        chmod 644 "$THREATS_LOG"
        ;;

    delete-threat)
        [[ -z "${2:-}" ]] && { echo "ERROR: No file specified" >&2; exit 1; }
        FILE="$2"
        # Only allow deletion of files actually referenced in the threats log (JSON format)
        if ! jq -e --arg fp "$FILE" 'select(.file_path == $fp)' "$THREATS_LOG" >/dev/null 2>&1; then
            echo "ERROR: File not referenced in threats log" >&2
            exit 1
        fi
        rm -f -- "$FILE" 2>/dev/null || true
        # Also remove quarantine copy if clamonacc moved it
        BASENAME="$(basename -- "$FILE")"
        rm -f -- "/root/quarantine/$BASENAME" 2>/dev/null || true
        ;;

    log-action)
        [[ -z "${2:-}" ]] && { echo "ERROR: No entry specified" >&2; exit 1; }
        echo "$2" >> "$ACTIONS_LOG"
        chown clamav:clamav "$ACTIONS_LOG"
        chmod 644 "$ACTIONS_LOG"
        ;;

    stop-scan)
        # Kill a running scan by PID from state file.
        if [[ ! -f "$SCAN_STATE" ]] || [[ ! -s "$SCAN_STATE" ]]; then
            exit 0
        fi
        PID=$(jq -r '.pid' "$SCAN_STATE" 2>/dev/null) || exit 0
        if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then
            kill -- -"$PID" 2>/dev/null || kill "$PID" 2>/dev/null || true
        fi
        ;;

    finalize-scan)
        # Finalize a stale scan state file left behind by a silently killed scan.
        # Reads state, writes "killed" history entry, removes state file.
        if [[ ! -f "$SCAN_STATE" ]]; then
            echo "ERROR: No scan state file found" >&2
            exit 1
        fi

        # Read fields from state file
        START=$(jq -r '.start' "$SCAN_STATE")
        LAST_ACTIVITY=$(jq -r '.last_activity' "$SCAN_STATE")
        SCOPE_PATHS=$(jq -c '.scope.paths' "$SCAN_STATE")
        SCOPE_EXCL=$(jq -c '.scope.exclusions' "$SCAN_STATE")
        FILES_SCANNED=$(jq -r '.files_scanned' "$SCAN_STATE")

        # Compute duration from start to last_activity
        START_EPOCH=$(date -d "$START" +%s 2>/dev/null) || START_EPOCH=0
        END_EPOCH=$(date -d "$LAST_ACTIVITY" +%s 2>/dev/null) || END_EPOCH=$(date +%s)
        DURATION_S=$((END_EPOCH - START_EPOCH))
        (( DURATION_S < 0 )) && DURATION_S=0

        H=$((DURATION_S / 3600))
        M=$(( (DURATION_S % 3600) / 60 ))
        S=$((DURATION_S % 60))
        DURATION_FMT=""
        (( H > 0 )) && DURATION_FMT="${H}h "
        (( M > 0 )) && DURATION_FMT="${DURATION_FMT}${M}m "
        DURATION_FMT="${DURATION_FMT}${S}s"

        # Write history entry with status "killed"
        jq -cn \
            --arg start "$START" \
            --arg end "$LAST_ACTIVITY" \
            --arg status "killed" \
            --argjson threats 0 \
            --arg duration "$DURATION_FMT" \
            --argjson paths "$SCOPE_PATHS" \
            --argjson excl "$SCOPE_EXCL" \
            '{start:$start, end:$end, status:$status, threats_found:$threats, duration:$duration, scope:{paths:$paths, exclusions:$excl}}' \
            >> "$SCAN_HISTORY"

        # Remove stale state file
        rm -f "$SCAN_STATE"
        ;;

    *)
        echo "Usage: $0 {remove-entry|delete-threat|log-action|stop-scan|finalize-scan} <argument>" >&2
        exit 1
        ;;
esac
