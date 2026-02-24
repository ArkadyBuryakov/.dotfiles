#!/bin/bash
# Privileged helper for ClamAV Threat Manager.
# Performs validated operations on clamav log files and threat files.
# Invoked via pkexec from the threat-manager TUI.
#
# Commands:
#   remove-entry <line>   - Remove exact line from threats.log
#   delete-threat <path>  - Delete a file referenced in threats.log (+ quarantine copy)
#   log-action <entry>    - Append entry to actions.log

set -euo pipefail

THREATS_LOG="/var/log/clamav/threats.log"
ACTIONS_LOG="/var/log/clamav/actions.log"

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
        # Only allow deletion of files actually referenced in the threats log
        if ! grep -qF -- "$FILE" "$THREATS_LOG" 2>/dev/null; then
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

    *)
        echo "Usage: $0 {remove-entry|delete-threat|log-action} <argument>" >&2
        exit 1
        ;;
esac
