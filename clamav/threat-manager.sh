#!/bin/bash
# ClamAV Threat Manager - Interactive TUI for managing detected threats.
# Opens without elevated privileges; escalates only for specific actions
# via pkexec and a dedicated helper script (polkit auth_admin_keep policy).
#
# Two pages: Threats (manage found threats) and Scan (start/stop full scan).
# Threat log format: JSON lines (one JSON object per line).

set -eo pipefail

THREATS_LOG="/var/log/clamav/threats.log"
HELPER="/etc/clamav/clamav-log-action.sh"
SCAN_SCRIPT="/etc/clamav/scan-weekly.sh"
LAST_SCAN_TS_FILE="/var/log/clamav/last-scan-timestamp"
SCAN_STATE="/var/log/clamav/scan-state.json"
SCAN_HISTORY="/var/log/clamav/scan-history.log"

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
declare -a HISTORY_ENTRIES
SELECTED=0
HISTORY_SCROLL=0
PAGE="scan"   # "threats" or "scan"
SCAN_PID=""
SCAN_START_EPOCH=""
TREE_VIEW=0                # 0 = flat list (default), 1 = tree view
declare -A DIR_EXPANDED    # dir_path -> "1" if expanded
declare -a VISIBLE_ITEMS   # "virtual:IDX", "dir:IDX", or "file:TIDX:DEPTH"
declare -a DIR_ORDER       # ordered unique directory paths
declare -A DIR_THREATS     # dir_path -> space-separated indices into THREATS[]
declare -a TREE_NODES      # "depth|type|path|label" — hierarchical tree
declare -a TREE_COUNTS     # threat count per tree node

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

cleanup() {
    # Don't kill root-owned scans on TUI exit — they continue in background
    # and get adopted on next launch via detect_running_scan.
    restore_term
}

trap cleanup EXIT

# Temporarily restore terminal for pkexec (polkit agent needs working terminal)
with_normal_term() {
    tput cnorm 2>/dev/null
    stty echo 2>/dev/null
    "$@"
    local rc=$?
    kitten @ focus-window 2>/dev/null || true
    stty -echo 2>/dev/null
    tput civis 2>/dev/null
    return $rc
}

# --- Data ---
load_threats() {
    THREATS=()
    if [[ -f "$THREATS_LOG" ]] && [[ -s "$THREATS_LOG" ]]; then
        mapfile -t THREATS < "$THREATS_LOG"
    fi
    build_tree
}

build_tree() {
    DIR_ORDER=()
    DIR_THREATS=()
    TREE_NODES=()
    TREE_COUNTS=()
    VISIBLE_ITEMS=()

    if (( ${#THREATS[@]} == 0 )); then
        return
    fi

    # Group threats by parent directory
    local -A seen_dirs
    local i filepath dirpath
    for (( i = 0; i < ${#THREATS[@]}; i++ )); do
        filepath=$(extract_filepath "${THREATS[$i]}")
        dirpath=$(dirname "$filepath")
        if [[ -z "${seen_dirs[$dirpath]+x}" ]]; then
            DIR_ORDER+=("$dirpath")
            seen_dirs[$dirpath]=1
            DIR_THREATS[$dirpath]="$i"
        else
            DIR_THREATS[$dirpath]="${DIR_THREATS[$dirpath]} $i"
        fi
    done

    # Sort directories
    local -a sorted_dirs
    mapfile -t sorted_dirs < <(printf '%s\n' "${DIR_ORDER[@]}" | sort)

    # Build raw tree by walking sorted paths and emitting trie nodes
    local -a prev_parts=()
    local j common
    for dirpath in "${sorted_dirs[@]}"; do
        local -a parts=()
        IFS='/' read -ra _raw <<< "$dirpath"
        for _p in "${_raw[@]}"; do
            [[ -n "$_p" ]] && parts+=("$_p")
        done
        if (( ${#parts[@]} == 0 )); then
            parts=("/")
        fi

        # Common prefix length with previous path
        common=0
        for (( j = 0; j < ${#prev_parts[@]} && j < ${#parts[@]}; j++ )); do
            if [[ "${parts[$j]}" == "${prev_parts[$j]}" ]]; then
                common=$((common + 1))
            else
                break
            fi
        done

        # Emit virtual nodes for new intermediate components
        for (( j = common; j < ${#parts[@]} - 1; j++ )); do
            local partial=""
            local k
            for (( k = 0; k <= j; k++ )); do
                partial+="/${parts[$k]}"
            done
            TREE_NODES+=("${j}|virtual|${partial}|${parts[$j]}")
        done

        # Emit leaf dir node
        local leaf_depth=$(( ${#parts[@]} - 1 ))
        TREE_NODES+=("${leaf_depth}|dir|${dirpath}|${parts[${#parts[@]}-1]}")

        prev_parts=("${parts[@]}")
    done

    _compress_tree_nodes
    _compute_tree_counts
    _build_visible
}

_compress_tree_nodes() {
    local changed=1
    while (( changed )); do
        changed=0
        local -a new_nodes=()
        local i=0 n=${#TREE_NODES[@]}

        while (( i < n )); do
            local depth type path label
            IFS='|' read -r depth type path label <<< "${TREE_NODES[$i]}"

            if [[ "$type" == "virtual" ]]; then
                # Count direct children at depth+1 within this subtree
                local child_count=0 subtree_end=$((i + 1))
                local j jdepth
                for (( j = i + 1; j < n; j++ )); do
                    IFS='|' read -r jdepth _ _ _ <<< "${TREE_NODES[$j]}"
                    if (( jdepth <= depth )); then break; fi
                    if (( jdepth == depth + 1 )); then child_count=$((child_count + 1)); fi
                    subtree_end=$((j + 1))
                done

                if (( child_count == 1 )); then
                    # Merge with single child: update child label/depth, shift descendants
                    local cdepth ctype cpath clabel
                    IFS='|' read -r cdepth ctype cpath clabel <<< "${TREE_NODES[$((i+1))]}"
                    TREE_NODES[$((i+1))]="${depth}|${ctype}|${cpath}|${label}/${clabel}"

                    for (( j = i + 2; j < subtree_end; j++ )); do
                        local jrest
                        IFS='|' read -r jdepth jrest <<< "${TREE_NODES[$j]}"
                        TREE_NODES[$j]="$((jdepth - 1))|${jrest}"
                    done

                    changed=1
                    i=$((i + 1))
                    continue
                fi
            fi

            new_nodes+=("${TREE_NODES[$i]}")
            i=$((i + 1))
        done

        TREE_NODES=("${new_nodes[@]}")
    done
}

_compute_tree_counts() {
    TREE_COUNTS=()
    local i n=${#TREE_NODES[@]}

    for (( i = 0; i < n; i++ )); do
        local depth type path
        IFS='|' read -r depth type path _ <<< "${TREE_NODES[$i]}"

        if [[ "$type" == "dir" ]]; then
            local indices=(${DIR_THREATS[$path]})
            TREE_COUNTS[$i]=${#indices[@]}
        else
            # Virtual: sum all descendant dir threat counts
            local total=0 j jdepth jtype jpath
            for (( j = i + 1; j < n; j++ )); do
                IFS='|' read -r jdepth jtype jpath _ <<< "${TREE_NODES[$j]}"
                if (( jdepth <= depth )); then break; fi
                if [[ "$jtype" == "dir" ]]; then
                    local idxs=(${DIR_THREATS[$jpath]})
                    total=$((total + ${#idxs[@]}))
                fi
            done
            TREE_COUNTS[$i]=$total
        fi
    done
}

_build_visible() {
    VISIBLE_ITEMS=()
    local skip_depth=-1
    local i n=${#TREE_NODES[@]}

    for (( i = 0; i < n; i++ )); do
        local depth type path
        IFS='|' read -r depth type path _ <<< "${TREE_NODES[$i]}"

        if (( skip_depth >= 0 )); then
            if (( depth > skip_depth )); then
                continue
            fi
            skip_depth=-1
        fi

        if [[ "$type" == "virtual" ]]; then
            VISIBLE_ITEMS+=("virtual:${i}")
            if [[ "${DIR_EXPANDED[$path]}" != "1" ]]; then
                skip_depth=$depth
            fi
        else
            VISIBLE_ITEMS+=("dir:${i}")
            if [[ "${DIR_EXPANDED[$path]}" == "1" ]]; then
                local indices=(${DIR_THREATS[$path]})
                local j
                for j in "${indices[@]}"; do
                    VISIBLE_ITEMS+=("file:${j}:${depth}")
                done
            fi
        fi
    done
}

load_scan_history() {
    HISTORY_ENTRIES=()
    if [[ ! -f "$SCAN_HISTORY" ]] || [[ ! -s "$SCAN_HISTORY" ]]; then
        return
    fi
    local tmp_entries
    mapfile -t tmp_entries < "$SCAN_HISTORY"
    # Reverse order: newest first
    local i
    for (( i = ${#tmp_entries[@]} - 1; i >= 0; i-- )); do
        HISTORY_ENTRIES+=("${tmp_entries[$i]}")
    done
}

detect_running_scan() {
    if [[ ! -f "$SCAN_STATE" ]] || [[ ! -s "$SCAN_STATE" ]]; then
        return
    fi
    local pid
    pid=$(jq -r '.pid // empty' "$SCAN_STATE" 2>/dev/null) || return
    [[ -z "$pid" ]] && return
    # Use /proc check — kill -0 would fail on root-owned scan process
    if [[ -n "$pid" ]] && [[ -d "/proc/$pid" ]]; then
        # Process alive — adopt it (store state-file PID for display only;
        # we can't signal it directly since it's root-owned)
        SCAN_PID="$pid"
        local start_ts
        start_ts=$(jq -r '.start' "$SCAN_STATE" 2>/dev/null) || return
        SCAN_START_EPOCH=$(date -d "$start_ts" +%s 2>/dev/null) || SCAN_START_EPOCH=$(date +%s)
    else
        # Process dead — stale state, finalize as killed
        with_normal_term pkexec "$HELPER" finalize-scan
        load_scan_history
    fi
}

format_threat() {
    local json="$1"
    jq -r '"[\(.timestamp)] \(.virus_name) \u2192 \(.file_path)"' <<< "$json"
}

format_threat_short() {
    local json="$1"
    jq -r '"[\(.timestamp)] \(.virus_name) \u2192 \(.file_path | split("/") | last)"' <<< "$json"
}

extract_filepath() {
    local json="$1"
    jq -r '.file_path' <<< "$json"
}

extract_notification_ids() {
    local json="$1"
    jq -r '.notification_ids[]?' <<< "$json"
}

dismiss_notifications() {
    local json="$1"
    local nid
    while IFS= read -r nid; do
        [[ -n "$nid" ]] && makoctl dismiss -n "$nid" 2>/dev/null || true
    done < <(extract_notification_ids "$json")
}

# --- Scan helpers ---
# Check if a process is alive. Uses /proc to work across user boundaries
# (scan runs as root, TUI runs unprivileged).
is_scan_alive() {
    [[ -n "$SCAN_PID" ]] && [[ -d "/proc/$SCAN_PID" ]]
}

format_elapsed() {
    local secs="$1"
    local h=$((secs / 3600))
    local m=$(( (secs % 3600) / 60 ))
    local s=$((secs % 60))
    if (( h > 0 )); then
        printf '%dh %dm %ds' "$h" "$m" "$s"
    elif (( m > 0 )); then
        printf '%dm %ds' "$m" "$s"
    else
        printf '%ds' "$s"
    fi
}

get_last_scan_time() {
    if [[ -f "$LAST_SCAN_TS_FILE" && -s "$LAST_SCAN_TS_FILE" ]]; then
        cat "$LAST_SCAN_TS_FILE"
    else
        printf 'never'
    fi
}

check_scan_status() {
    if [[ -n "$SCAN_PID" ]] && ! is_scan_alive; then
        wait "$SCAN_PID" 2>/dev/null || true
        SCAN_PID=""
        SCAN_START_EPOCH=""
        # Wait briefly for the scan's EXIT trap to clean up state file
        if [[ -f "$SCAN_STATE" ]]; then
            sleep 0.5
        fi
        load_threats
        clamp_selected
        load_scan_history
    fi
}

start_scan() {
    # Launch in its own process group so we can kill the entire tree
    # (pkexec → systemd-inhibit → clamdscan) with a single signal.
    tput cnorm 2>/dev/null
    stty echo 2>/dev/null
    setsid pkexec "$SCAN_SCRIPT" &
    SCAN_PID=$!
    kitten @ focus-window 2>/dev/null || true
    stty -echo 2>/dev/null
    tput civis 2>/dev/null
    SCAN_START_EPOCH=$(date +%s)
}

stop_scan() {
    if is_scan_alive; then
        # Scan runs as root — must kill via privileged helper
        with_normal_term pkexec "$HELPER" stop-scan
        wait "$SCAN_PID" 2>/dev/null || true
    fi
    SCAN_PID=""
    SCAN_START_EPOCH=""
}

# --- Drawing ---
draw_header() {
    local cols count
    cols=$(tput cols)
    count=${#THREATS[@]}

    printf " ${BOLD}ClamAV Threat Manager${RESET}  "

    # Tab bar
    if [[ "$PAGE" == "threats" ]]; then
        printf "${BOLD}[Threats]${RESET} ${DIM}Scan${RESET}"
    else
        printf "${DIM}Threats${RESET} ${BOLD}[Scan]${RESET}"
    fi

    # Threat count badge
    if (( count > 0 )); then
        printf "  ${BOLD_RED}%d!${RESET}" "$count"
    fi
    printf '\n\n'
}

draw_threats_flat() {
    local cols rows count
    cols=$(tput cols)
    rows=$(tput lines)
    count=${#THREATS[@]}

    if (( count == 0 )); then
        printf " ${GREEN}No threats detected.${RESET}\n"
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
        display=$(format_threat "${THREATS[$i]}")
        if (( ${#display} > max_width )); then
            display="${display:0:$((max_width - 1))}…"
        fi
        if (( i == SELECTED )); then
            printf " ${BOLD_RED}▸ %s${RESET}\n" "$display"
        else
            printf "   ${DIM}%s${RESET}\n" "$display"
        fi
    done
}

draw_threats_tree() {
    local cols rows vis_count
    cols=$(tput cols)
    rows=$(tput lines)
    vis_count=${#VISIBLE_ITEMS[@]}

    if (( vis_count == 0 )); then
        printf " ${GREEN}No threats detected.${RESET}\n"
        return
    fi

    local max_width=$((cols - 4))
    local max_visible=$((rows - 6))
    local visible_start=0

    if (( max_visible < 1 )); then max_visible=1; fi

    if (( SELECTED >= visible_start + max_visible )); then
        visible_start=$((SELECTED - max_visible + 1))
    fi

    local i
    for (( i = visible_start; i < vis_count && i < visible_start + max_visible; i++ )); do
        local item="${VISIBLE_ITEMS[$i]}"
        local vtype="${item%%:*}"
        local vrest="${item#*:}"

        if [[ "$vtype" == "virtual" || "$vtype" == "dir" ]]; then
            local tree_idx="$vrest"
            local ndepth ntype npath nlabel
            IFS='|' read -r ndepth ntype npath nlabel <<< "${TREE_NODES[$tree_idx]}"
            local count="${TREE_COUNTS[$tree_idx]}"

            local arrow="▶"
            [[ "${DIR_EXPANDED[$npath]}" == "1" ]] && arrow="▼"

            local display_label="$nlabel"
            if (( ndepth == 0 )) && [[ "$npath" == /* ]]; then
                display_label="/${nlabel}"
            fi

            local indent=""
            local d; for (( d = 0; d < ndepth; d++ )); do indent+="  "; done

            local line="${indent}${arrow} ${display_label}  (${count})"
            if (( ${#line} > max_width )); then
                line="${line:0:$((max_width - 1))}…"
            fi

            if (( i == SELECTED )); then
                printf " ${BOLD_RED}▸ %s${RESET}\n" "$line"
            else
                printf "   ${YELLOW}%s${RESET}\n" "$line"
            fi
        else
            # file entry: "file:THREAT_IDX:DEPTH"
            local threat_idx="${vrest%%:*}"
            local file_depth="${vrest##*:}"

            local display
            display=$(format_threat_short "${THREATS[$threat_idx]}")

            local indent=""
            local d; for (( d = 0; d <= file_depth; d++ )); do indent+="  "; done

            local line="${indent}${display}"
            if (( ${#line} > max_width )); then
                line="${line:0:$((max_width - 1))}…"
            fi

            if (( i == SELECTED )); then
                printf " ${BOLD_RED}▸ %s${RESET}\n" "$line"
            else
                printf "   ${DIM}%s${RESET}\n" "$line"
            fi
        fi
    done
}

draw_threats_page() {
    if (( TREE_VIEW )); then
        draw_threats_tree
    else
        draw_threats_flat
    fi
}

draw_scan_page() {
    local last_scan rows
    last_scan=$(get_last_scan_time)
    rows=$(tput lines)

    if is_scan_alive; then
        # Scan running
        local now elapsed_s elapsed_fmt
        now=$(date +%s)
        elapsed_s=$((now - SCAN_START_EPOCH))
        elapsed_fmt=$(format_elapsed "$elapsed_s")

        printf " ${BOLD}Scan running${RESET}  ${DIM}elapsed${RESET} ${CYAN}%s${RESET}\n" "$elapsed_fmt"

        # Progress from state file
        if [[ -f "$SCAN_STATE" ]] && [[ -s "$SCAN_STATE" ]]; then
            local scanned activity current_dir
            current_dir=$(jq -r '.current_dir // empty' "$SCAN_STATE" 2>/dev/null) || true
            if [[ -n "${current_dir:-}" ]]; then
                printf " ${DIM}Scanning:${RESET} %s\n" "$current_dir"
            fi
            scanned=$(jq -r '.files_scanned // 0' "$SCAN_STATE" 2>/dev/null) || true
            scanned=${scanned:-0}
            printf " ${DIM}Scanned:${RESET} %d files\n" "$scanned"
            activity=$(jq -r '.last_activity // ""' "$SCAN_STATE" 2>/dev/null) || true
            activity=${activity:-}
            if [[ -n "$activity" ]]; then
                printf " ${DIM}Last activity:${RESET} %s\n" "$activity"
            fi
        fi

        printf "\n ${DIM}Last scan:${RESET} %s\n" "$last_scan"
    else
        # Idle
        printf " ${DIM}Last scan:${RESET} %s\n\n" "$last_scan"

        # Stale warning
        if [[ "$last_scan" == "never" ]]; then
            printf " ${YELLOW}No scan has been run yet.${RESET}\n"
        else
            local ts_epoch now_epoch age_days
            ts_epoch=$(date -d "$last_scan" +%s 2>/dev/null) || ts_epoch=0
            now_epoch=$(date +%s)
            age_days=$(( (now_epoch - ts_epoch) / 86400 ))
            if (( age_days > 30 )); then
                printf " ${YELLOW}Last scan was %d days ago.${RESET}\n" "$age_days"
            fi
        fi
    fi

    # History section
    local count=${#HISTORY_ENTRIES[@]}
    printf "\n ${DIM}─── History ───${RESET}\n"
    if (( count == 0 )); then
        printf " ${DIM}No scan history.${RESET}\n"
        return
    fi

    # Scrollable list
    local cols max_visible visible_start i
    cols=$(tput cols)
    max_visible=$((rows - 14))
    (( max_visible < 1 )) && max_visible=1

    visible_start=0
    if (( HISTORY_SCROLL >= max_visible )); then
        visible_start=$((HISTORY_SCROLL - max_visible + 1))
    fi

    for (( i = visible_start; i < count && i < visible_start + max_visible; i++ )); do
        local entry="${HISTORY_ENTRIES[$i]}"
        local h_start h_status h_duration h_threats display status_color
        h_start=$(jq -r '.start // "?"' <<< "$entry" 2>/dev/null) || h_start="?"
        h_status=$(jq -r '.status // "?"' <<< "$entry" 2>/dev/null) || h_status="?"
        h_duration=$(jq -r '.duration // "?"' <<< "$entry" 2>/dev/null) || h_duration="?"
        h_threats=$(jq -r '.threats_found // 0' <<< "$entry" 2>/dev/null) || h_threats=0

        case "$h_status" in
            completed)   status_color="$GREEN" ;;
            interrupted) status_color="$YELLOW" ;;
            killed)      status_color="$RED" ;;
            *)           status_color="$DIM" ;;
        esac

        display=$(printf '[%s] %b%s%b %s (%d threats)' \
            "$h_start" "$status_color" "$h_status" "$RESET" "$h_duration" "$h_threats")

        local max_width=$((cols - 5))
        if (( ${#display} > max_width + 20 )); then  # account for color escapes
            :  # don't truncate, color codes inflate length
        fi

        if (( i == HISTORY_SCROLL )); then
            printf " ${BOLD}▸${RESET} %b\n" "$display"
        else
            printf "   %b\n" "$display"
        fi
    done
}

draw_keybindings() {
    if [[ "$PAGE" == "threats" ]]; then
        if (( ${#THREATS[@]} > 0 )); then
            printf " ${DIM}[${RESET}${CYAN}d${RESET}${DIM}]${RESET} Delete  "
            printf "${DIM}[${RESET}${CYAN}i${RESET}${DIM}]${RESET} Ignore  "
            printf "${DIM}[${RESET}${CYAN}D${RESET}${DIM}]${RESET} Delete all  "
            printf "${DIM}[${RESET}${CYAN}I${RESET}${DIM}]${RESET} Ignore all  "
            printf "${DIM}[${RESET}${CYAN}r${RESET}${DIM}]${RESET} Refresh  "
            if (( TREE_VIEW )); then
                printf "${DIM}[${RESET}${CYAN}enter${RESET}${DIM}]${RESET} Expand  "
                printf "${DIM}[${RESET}${CYAN}t${RESET}${DIM}]${RESET} Flat  "
            else
                printf "${DIM}[${RESET}${CYAN}t${RESET}${DIM}]${RESET} Tree  "
            fi
        fi
    else
        if is_scan_alive; then
            printf " ${DIM}[${RESET}${CYAN}S${RESET}${DIM}]${RESET} Stop scan  "
        else
            printf " ${DIM}[${RESET}${CYAN}s${RESET}${DIM}]${RESET} Start scan  "
        fi
        if (( ${#HISTORY_ENTRIES[@]} > 0 )); then
            printf "${DIM}[${RESET}${CYAN}j${RESET}${DIM}/${RESET}${CYAN}k${RESET}${DIM}]${RESET} Scroll  "
        fi
    fi
    printf "${DIM}[${RESET}${CYAN}h${RESET}${DIM}/${RESET}${CYAN}l${RESET}${DIM}]${RESET} Navigate  "
    printf "${DIM}[${RESET}${CYAN}q${RESET}${DIM}]${RESET} Quit"
}

draw() {
    local rows content keys
    rows=$(tput lines)

    content="$(draw_header; if [[ "$PAGE" == "threats" ]]; then draw_threats_page; else draw_scan_page; fi)"
    content="${content//$'\n'/$'\033[K\n'}"
    keys="$(draw_keybindings)"

    # Single atomic write: home, content, clear-to-bottom, position keybindings, keys, clear-eol
    printf '\033[H%s\033[J\033[%d;1H%s\033[K' "$content" "$((rows - 1))" "$keys"
}

# --- Input ---
read_key() {
    local key
    IFS= read -rsn1 -t 1 key
    local rc=$?
    if (( rc > 0 )) && [[ -z "$key" ]]; then
        printf 'timeout'
        return
    fi
    if [[ "$key" == $'\x1b' ]]; then
        read -rsn2 -t 0.01 key || true
        case "$key" in
            '[A') printf 'up' ;;
            '[B') printf 'down' ;;
            '[D') printf 'left' ;;
            '[C') printf 'right' ;;
        esac
    elif [[ -z "$key" ]]; then
        printf 'enter'
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
    if (( TREE_VIEW )); then
        if (( ${#VISIBLE_ITEMS[@]} == 0 )); then
            SELECTED=0
        elif (( SELECTED >= ${#VISIBLE_ITEMS[@]} )); then
            SELECTED=$(( ${#VISIBLE_ITEMS[@]} - 1 ))
        fi
    else
        if (( ${#THREATS[@]} == 0 )); then
            SELECTED=0
        elif (( SELECTED >= ${#THREATS[@]} )); then
            SELECTED=$(( ${#THREATS[@]} - 1 ))
        fi
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

    dismiss_notifications "$entry"

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

    dismiss_notifications "$entry"

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
        dismiss_notifications "$entry"
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
        dismiss_notifications "$entry"
    done

    load_threats
    SELECTED=0
    show_status "All threats ignored." "$GREEN"
}

do_delete_node() {
    local tree_idx="$1"
    local depth type path label
    IFS='|' read -r depth type path label <<< "${TREE_NODES[$tree_idx]}"
    local count="${TREE_COUNTS[$tree_idx]}"

    local display_label="$label"
    (( depth == 0 )) && [[ "$path" == /* ]] && display_label="/${label}"

    if ! confirm "Delete ALL ${count} threat(s) in ${display_label}?"; then
        return
    fi

    # Collect all threat indices under this node
    local -a all_indices=()
    if [[ "$type" == "dir" ]]; then
        all_indices=(${DIR_THREATS[$path]})
    else
        local j jdepth jtype jpath
        for (( j = tree_idx + 1; j < ${#TREE_NODES[@]}; j++ )); do
            IFS='|' read -r jdepth jtype jpath _ <<< "${TREE_NODES[$j]}"
            if (( jdepth <= depth )); then break; fi
            if [[ "$jtype" == "dir" ]]; then
                all_indices+=(${DIR_THREATS[$jpath]})
            fi
        done
    fi

    local ts idx filepath entry
    ts="$(date '+%Y-%m-%d %H:%M:%S')"

    # Sort indices in reverse to avoid shift issues
    local -a sorted_indices
    mapfile -t sorted_indices < <(printf '%s\n' "${all_indices[@]}" | sort -rn)

    for idx in "${sorted_indices[@]}"; do
        entry="${THREATS[$idx]}"
        filepath=$(extract_filepath "$entry")
        if [[ -n "$filepath" ]]; then
            with_normal_term pkexec "$HELPER" delete-threat "$filepath"
        fi
        with_normal_term pkexec "$HELPER" log-action "$ts - DELETED - $entry"
        with_normal_term pkexec "$HELPER" remove-entry "$entry"
        dismiss_notifications "$entry"
    done

    load_threats
    clamp_selected
    show_status "Deleted ${count} threats from ${display_label}." "$GREEN"
}

do_ignore_node() {
    local tree_idx="$1"
    local depth type path label
    IFS='|' read -r depth type path label <<< "${TREE_NODES[$tree_idx]}"
    local count="${TREE_COUNTS[$tree_idx]}"

    local display_label="$label"
    (( depth == 0 )) && [[ "$path" == /* ]] && display_label="/${label}"

    if ! confirm "Ignore ALL ${count} threat(s) in ${display_label}?"; then
        return
    fi

    local -a all_indices=()
    if [[ "$type" == "dir" ]]; then
        all_indices=(${DIR_THREATS[$path]})
    else
        local j jdepth jtype jpath
        for (( j = tree_idx + 1; j < ${#TREE_NODES[@]}; j++ )); do
            IFS='|' read -r jdepth jtype jpath _ <<< "${TREE_NODES[$j]}"
            if (( jdepth <= depth )); then break; fi
            if [[ "$jtype" == "dir" ]]; then
                all_indices+=(${DIR_THREATS[$jpath]})
            fi
        done
    fi

    local ts idx entry
    ts="$(date '+%Y-%m-%d %H:%M:%S')"

    local -a sorted_indices
    mapfile -t sorted_indices < <(printf '%s\n' "${all_indices[@]}" | sort -rn)

    for idx in "${sorted_indices[@]}"; do
        entry="${THREATS[$idx]}"
        with_normal_term pkexec "$HELPER" log-action "$ts - IGNORED - $entry"
        with_normal_term pkexec "$HELPER" remove-entry "$entry"
        dismiss_notifications "$entry"
    done

    load_threats
    clamp_selected
    show_status "Ignored ${count} threats from ${display_label}." "$GREEN"
}

# --- Main ---
if [[ -f "$THREATS_LOG" && ! -r "$THREATS_LOG" ]]; then
    printf 'Cannot read %s\n' "$THREATS_LOG" >&2
    exit 1
fi

setup_term
load_threats
load_scan_history
detect_running_scan

# Default to threats page if there are threats, scan page otherwise
if (( ${#THREATS[@]} > 0 )); then
    PAGE="threats"
else
    PAGE="scan"
fi

while true; do
    check_scan_status
    draw

    key=$(read_key)

    # Global keys
    case "$key" in
        timeout) continue ;;
        q) break ;;
        h|left)  PAGE="threats"; continue ;;
        l|right) PAGE="scan"; continue ;;
    esac

    # Page-specific keys
    if [[ "$PAGE" == "threats" ]]; then
        case "$key" in
            t)
                TREE_VIEW=$(( 1 - TREE_VIEW ))
                SELECTED=0
                ;;
            up|k)
                if (( SELECTED > 0 )); then
                    SELECTED=$((SELECTED - 1))
                fi
                ;;
            down|j)
                if (( TREE_VIEW )); then
                    if (( SELECTED < ${#VISIBLE_ITEMS[@]} - 1 )); then
                        SELECTED=$((SELECTED + 1))
                    fi
                else
                    if (( SELECTED < ${#THREATS[@]} - 1 )); then
                        SELECTED=$((SELECTED + 1))
                    fi
                fi
                ;;
            enter|' ')
                if (( TREE_VIEW )) && (( ${#VISIBLE_ITEMS[@]} > 0 )); then
                    _item="${VISIBLE_ITEMS[$SELECTED]}"
                    _type="${_item%%:*}"
                    if [[ "$_type" == "virtual" || "$_type" == "dir" ]]; then
                        _tree_idx="${_item#*:}"
                        IFS='|' read -r _ _ _path _ <<< "${TREE_NODES[$_tree_idx]}"
                        if [[ "${DIR_EXPANDED[$_path]}" == "1" ]]; then
                            DIR_EXPANDED[$_path]="0"
                        else
                            DIR_EXPANDED[$_path]="1"
                        fi
                        _build_visible
                        clamp_selected
                    fi
                fi
                ;;
            d)
                if (( TREE_VIEW )) && (( ${#VISIBLE_ITEMS[@]} > 0 )); then
                    _item="${VISIBLE_ITEMS[$SELECTED]}"
                    _type="${_item%%:*}"
                    _rest="${_item#*:}"
                    if [[ "$_type" == "virtual" || "$_type" == "dir" ]]; then
                        do_delete_node "$_rest"
                    elif [[ "$_type" == "file" ]]; then
                        do_delete "${_rest%%:*}"
                    fi
                elif (( ! TREE_VIEW )) && (( ${#THREATS[@]} > 0 )); then
                    do_delete "$SELECTED"
                fi
                ;;
            i)
                if (( TREE_VIEW )) && (( ${#VISIBLE_ITEMS[@]} > 0 )); then
                    _item="${VISIBLE_ITEMS[$SELECTED]}"
                    _type="${_item%%:*}"
                    _rest="${_item#*:}"
                    if [[ "$_type" == "virtual" || "$_type" == "dir" ]]; then
                        do_ignore_node "$_rest"
                    elif [[ "$_type" == "file" ]]; then
                        do_ignore "${_rest%%:*}"
                    fi
                elif (( ! TREE_VIEW )) && (( ${#THREATS[@]} > 0 )); then
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
            r)
                load_threats
                clamp_selected
                ;;
        esac
    elif [[ "$PAGE" == "scan" ]]; then
        case "$key" in
            s|enter)
                if ! is_scan_alive; then
                    start_scan
                fi
                ;;
            S)
                if is_scan_alive; then
                    stop_scan
                    load_scan_history
                    show_status "Scan stopped." "$YELLOW"
                fi
                ;;
            up|k)
                if (( HISTORY_SCROLL > 0 )); then
                    HISTORY_SCROLL=$((HISTORY_SCROLL - 1))
                fi
                ;;
            down|j)
                if (( HISTORY_SCROLL < ${#HISTORY_ENTRIES[@]} - 1 )); then
                    HISTORY_SCROLL=$((HISTORY_SCROLL + 1))
                fi
                ;;
        esac
    fi
done
