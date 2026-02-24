#!/bin/bash
# ClamAV Threat Manager - Interactive TUI for managing detected threats.
# Opens without elevated privileges; escalates only for specific actions
# via pkexec and a dedicated helper script (polkit auth_admin_keep policy).

set -eo pipefail

THREATS_LOG="/var/log/clamav/threats.log"
HELPER="/etc/clamav/clamav-log-action.sh"

# --- Colors ---
RED='\033[31m'
BOLD_RED='\033[1;31m'
GREEN='\033[32m'
YELLOW='\033[33m'
CYAN='\033[36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# --- State ---
declare -a THREATS
SELECTED=0

# --- Terminal ---
setup_term() {
    tput smcup
    tput civis
    stty -echo
}

restore_term() {
    tput cnorm 2>/dev/null
    tput rmcup 2>/dev/null
    stty echo 2>/dev/null
}

trap restore_term EXIT

# Temporarily restore terminal for pkexec (polkit agent needs working terminal)
with_normal_term() {
    tput cnorm 2>/dev/null
    stty echo 2>/dev/null
    "$@"
    local rc=$?
    stty -echo 2>/dev/null
    tput civis 2>/dev/null
    return $rc
}

# --- Data ---
load_threats() {
    THREATS=()
    if [[ ! -f "$THREATS_LOG" ]] || [[ ! -s "$THREATS_LOG" ]]; then
        return
    fi
    while IFS= read -r line; do
        [[ -n "$line" ]] && THREATS+=("$line")
    done < "$THREATS_LOG"
}

extract_filepath() {
    local line="$1"
    # Format: [TIMESTAMP] FOUND: VirusName in /path/to/file
    if [[ "$line" =~ \]\ FOUND:\ .+\ in\ (.+)$ ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    # Format: [TIMESTAMP] /path/to/file: VirusName FOUND
    elif [[ "$line" =~ \]\ (.+):\ .+\ FOUND$ ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    fi
}

# --- Drawing ---
draw() {
    local cols rows count
    cols=$(tput cols)
    rows=$(tput lines)
    count=${#THREATS[@]}

    tput clear

    # Title
    printf " ${BOLD}ClamAV Threat Manager${RESET}"
    if (( count > 0 )); then
        local suffix=""
        if (( count != 1 )); then suffix="s"; fi
        printf "  ${DIM}(%d threat%s)${RESET}" "$count" "$suffix"
    fi
    printf '\n\n'

    if (( count == 0 )); then
        printf " ${GREEN}No threats detected.${RESET}\n\n"
        printf " ${DIM}[${RESET}${CYAN}q${RESET}${DIM}]${RESET} Quit\n"
        return
    fi

    # Scrollable threat list
    local max_width=$((cols - 5))
    local max_visible=$((rows - 6))
    local visible_start=0

    if (( max_visible < 1 )); then max_visible=1; fi

    if (( SELECTED >= visible_start + max_visible )); then
        visible_start=$((SELECTED - max_visible + 1))
    fi

    local i display
    for (( i = visible_start; i < count && i < visible_start + max_visible; i++ )); do
        display="${THREATS[$i]}"
        if (( ${#display} > max_width )); then
            display="${display:0:$((max_width - 1))}…"
        fi
        if (( i == SELECTED )); then
            printf " ${BOLD_RED}▸ %s${RESET}\n" "$display"
        else
            printf "   ${DIM}%s${RESET}\n" "$display"
        fi
    done

    # Keybindings bar
    tput cup $((rows - 2)) 0
    printf " ${DIM}[${RESET}${CYAN}d${RESET}${DIM}]${RESET} Delete  "
    printf "${DIM}[${RESET}${CYAN}i${RESET}${DIM}]${RESET} Ignore  "
    printf "${DIM}[${RESET}${CYAN}D${RESET}${DIM}]${RESET} Delete all  "
    printf "${DIM}[${RESET}${CYAN}I${RESET}${DIM}]${RESET} Ignore all  "
    printf "${DIM}[${RESET}${CYAN}q${RESET}${DIM}]${RESET} Quit"
}

# --- Input ---
read_key() {
    local key
    IFS= read -rsn1 key
    if [[ "$key" == $'\x1b' ]]; then
        read -rsn2 -t 0.01 key || true
        case "$key" in
            '[A') printf 'up' ;;
            '[B') printf 'down' ;;
        esac
    else
        printf '%s' "$key"
    fi
}

confirm() {
    local msg="$1" rows
    rows=$(tput lines)
    tput cup $((rows - 2)) 0
    tput el
    printf " ${YELLOW}%s${RESET} ${DIM}[y/N]${RESET} " "$msg"
    local answer
    IFS= read -rsn1 answer
    [[ "$answer" == "y" || "$answer" == "Y" ]]
}

show_status() {
    local msg="$1" color="${2:-$GREEN}" rows
    rows=$(tput lines)
    tput cup $((rows - 2)) 0
    tput el
    printf " ${color}%s${RESET}" "$msg"
    sleep 0.8
}

clamp_selected() {
    if (( ${#THREATS[@]} == 0 )); then
        SELECTED=0
    elif (( SELECTED >= ${#THREATS[@]} )); then
        SELECTED=$(( ${#THREATS[@]} - 1 ))
    fi
}

# --- Actions ---
do_delete() {
    local idx="$1"
    local entry="${THREATS[$idx]}"
    local filepath
    filepath=$(extract_filepath "$entry")

    if [[ -z "$filepath" ]]; then
        show_status "Could not parse file path from log entry." "$RED"
        return
    fi

    if ! confirm "Delete ${filepath}?"; then
        return
    fi

    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"

    with_normal_term pkexec "$HELPER" delete-threat "$filepath"
    with_normal_term pkexec "$HELPER" log-action "$ts - DELETED - $entry"
    with_normal_term pkexec "$HELPER" remove-entry "$entry"

    load_threats
    clamp_selected
    show_status "Deleted." "$GREEN"
}

do_ignore() {
    local idx="$1"
    local entry="${THREATS[$idx]}"

    if ! confirm "Ignore this threat?"; then
        return
    fi

    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"

    with_normal_term pkexec "$HELPER" log-action "$ts - IGNORED - $entry"
    with_normal_term pkexec "$HELPER" remove-entry "$entry"

    load_threats
    clamp_selected
    show_status "Ignored." "$GREEN"
}

do_delete_all() {
    local count=${#THREATS[@]}

    if ! confirm "Delete ALL ${count} threat file(s)?"; then
        return
    fi

    local ts i filepath entry
    ts="$(date '+%Y-%m-%d %H:%M:%S')"

    for (( i = count - 1; i >= 0; i-- )); do
        entry="${THREATS[$i]}"
        filepath=$(extract_filepath "$entry")
        if [[ -n "$filepath" ]]; then
            with_normal_term pkexec "$HELPER" delete-threat "$filepath"
        fi
        with_normal_term pkexec "$HELPER" log-action "$ts - DELETED - $entry"
        with_normal_term pkexec "$HELPER" remove-entry "$entry"
    done

    load_threats
    SELECTED=0
    show_status "All threats deleted." "$GREEN"
}

do_ignore_all() {
    local count=${#THREATS[@]}

    if ! confirm "Ignore ALL ${count} threat(s)?"; then
        return
    fi

    local ts i entry
    ts="$(date '+%Y-%m-%d %H:%M:%S')"

    for (( i = count - 1; i >= 0; i-- )); do
        entry="${THREATS[$i]}"
        with_normal_term pkexec "$HELPER" log-action "$ts - IGNORED - $entry"
        with_normal_term pkexec "$HELPER" remove-entry "$entry"
    done

    load_threats
    SELECTED=0
    show_status "All threats ignored." "$GREEN"
}

# --- Main ---
if [[ -f "$THREATS_LOG" && ! -r "$THREATS_LOG" ]]; then
    printf 'Cannot read %s\n' "$THREATS_LOG" >&2
    exit 1
fi

setup_term
load_threats

while true; do
    draw

    key=$(read_key)

    case "$key" in
        q) break ;;
        up|k)
            if (( SELECTED > 0 )); then
                (( SELECTED-- ))
            fi
            ;;
        down|j)
            if (( SELECTED < ${#THREATS[@]} - 1 )); then
                (( SELECTED++ ))
            fi
            ;;
        d)
            if (( ${#THREATS[@]} > 0 )); then
                do_delete "$SELECTED"
            fi
            ;;
        i)
            if (( ${#THREATS[@]} > 0 )); then
                do_ignore "$SELECTED"
            fi
            ;;
        D)
            if (( ${#THREATS[@]} > 0 )); then
                do_delete_all
            fi
            ;;
        I)
            if (( ${#THREATS[@]} > 0 )); then
                do_ignore_all
            fi
            ;;
    esac
done
