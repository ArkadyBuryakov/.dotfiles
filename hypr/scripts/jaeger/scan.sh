#!/bin/bash

# jaeger: scans all kitty instances for running AI agents and emits a JSON
# array (one line) with each agent's project, status, hyprland workspace and
# kitty os-window/tab/window coordinates for navigation.
#
# Usage: scan.sh                one-shot
#        scan.sh --watch [sec]  re-scan every N seconds (default 1)
#
# Status comes from the agent's terminal title (spinner = busy, ✳ = idle),
# overridden by hook-reported state files (see claude-hook.sh) when present.

AGENT_RE='^(claude|codex|opencode|aider|gemini|goose|crush)$'
WRAPPER_RE='^(node|bun|deno|python[0-9.]*)$'
STATUS_DIR="${XDG_RUNTIME_DIR:-/tmp}/jaeger"

scan() {
  local clients kitty_pids agents="" hooks combined enriched=""

  mkdir -p "$STATUS_DIR"
  clients=$(hyprctl clients -j) || return 1
  kitty_pids=$(jq -r '[.[] | select(.class == "kitty") | .pid] | unique | .[]' <<<"$clients")

  local kpid tree hypr
  for kpid in $kitty_pids; do
    tree=$(kitten @ --to "unix:@mykitty-$kpid" ls 2>/dev/null) || continue
    # All hyprland clients of this instance, most recently focused first.
    # A kitty instance can own several os windows (same pid); they are paired
    # with hyprland clients below by matching focus-recency rank, since kitty
    # last_focused_at and hyprland focusHistoryID track the same focus events.
    hypr=$(jq -c --argjson pid "$kpid" \
      '[.[] | select(.class == "kitty" and .pid == $pid)]
       | sort_by(.focusHistoryID)
       | map({workspace: .workspace.name, workspace_id: .workspace.id, hypr_address: .address})' \
      <<<"$clients")
    agents+=$(jq -c --argjson kpid "$kpid" --argjson hypr "$hypr" \
      --arg agent_re "$AGENT_RE" --arg wrapper_re "$WRAPPER_RE" '
      (map({id, recency: ([.tabs[].windows[].last_focused_at // 0] | max // 0)})
       | sort_by(-.recency) | map(.id)) as $osw_rank
      | .[] as $osw
      | (($osw_rank | index($osw.id)) // 0) as $rank
      | ($hypr[$rank] // $hypr[0] // {}) as $loc
      | $osw.tabs[] as $tab | $tab.windows[] as $w
      | ($w.foreground_processes // [])[] as $fp
      | ($fp.cmdline // []) as $cmd
      | (($cmd[0] // "") | split("/") | last) as $base
      | (if ($base | test($wrapper_re))
         then (($cmd[1] // "") | split("/") | last)
         else $base end) as $name
      | select($name | test($agent_re))
      | $loc + {
          agent: $name,
          agent_pid: $fp.pid,
          cwd: $fp.cwd,
          project: ($fp.cwd | split("/") | last),
          task: ($w.title | sub("^[⠀-⣿✳✻] *"; "") | if . == "Claude Code" then "" else . end),
          status: (if $w.needs_attention then "waiting"
                   elif ($w.title | test("^[⠀-⣿]")) then "busy"
                   elif ($w.title | test("^[✳✻]")) then "idle"
                   else "unknown" end),
          kitty_pid: $kpid,
          kitty_win_id: $w.id,
          tab_id: $tab.id,
          focused: (($osw.is_focused == true) and ($w.is_focused == true))
        }' <<<"$tree")$'\n'
  done

  # kitty transiently reports an empty foreground_processes for a window whose
  # agent is mid-work (fg process group unreadable during child spawn/reap),
  # and `kitten @ ls` itself can fail for a cycle — either way the card would
  # flicker. Keep an agent from the previous scan as long as its process is
  # still alive and not suspended (ctrl-z).
  local prev pid name state cmd base0 base1
  prev=$(jq -c --argjson cur "$(jq -sc 'map(.agent_pid)' <<<"$agents")" \
    '.[] | select((.agent_pid as $p | $cur | index($p)) | not)' \
    "$STATUS_DIR/agents.json" 2>/dev/null)
  local a
  while IFS= read -r a; do
    [ -z "$a" ] && continue
    pid=$(jq -r '.agent_pid' <<<"$a")
    name=$(jq -r '.agent' <<<"$a")
    [ -d "/proc/$pid" ] || continue
    state=$(sed 's/.*) //' "/proc/$pid/stat" 2>/dev/null | cut -d' ' -f1)
    [ "$state" = "T" ] && continue
    mapfile -t cmd < <(tr '\0' '\n' <"/proc/$pid/cmdline" 2>/dev/null)
    base0=${cmd[0]##*/}
    base1=${cmd[1]:+${cmd[1]##*/}}
    [ "$base0" = "$name" ] || [ "$base1" = "$name" ] || continue
    agents+="$a"$'\n'
  done <<<"$prev"

  # Drop state files of agents that no longer exist (pid-named files only)
  local f
  for f in "$STATUS_DIR"/[0-9]*.json; do
    [ -e "$f" ] || continue
    [ -d "/proc/$(basename "$f" .json)" ] || rm -f "$f"
  done

  # Hook-reported states override title heuristics (adds "waiting" precision)
  hooks=$(cat "$STATUS_DIR"/[0-9]*.json 2>/dev/null |
    jq -sc 'map({(.pid | tostring): .state}) | add // {}')
  [ -z "$hooks" ] && hooks='{}'

  combined=$(jq -sc --argjson hooks "$hooks" \
    'map(.status = ($hooks[.agent_pid | tostring] // .status))' <<<"$agents")

  # Enrich with git branch per agent
  local a cwd branch
  while IFS= read -r a; do
    [ -z "$a" ] && continue
    cwd=$(jq -r '.cwd' <<<"$a")
    branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
    enriched+=$(jq -c --arg b "$branch" '.branch = $b' <<<"$a")$'\n'
  done < <(jq -c '.[]' <<<"$combined")

  # Cache the list so goto.sh can resolve indices without rescanning
  jq -sc 'sort_by(.workspace_id, .project)' <<<"$enriched" |
    tee "$STATUS_DIR/agents.json"
}

if [ "$1" = "--watch" ]; then
  while :; do
    scan
    sleep "${2:-1}"
  done
else
  scan
fi
