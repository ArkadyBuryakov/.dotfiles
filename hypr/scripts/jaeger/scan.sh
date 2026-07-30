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
    hypr=$(jq -c --argjson pid "$kpid" \
      '[.[] | select(.class == "kitty" and .pid == $pid)][0]
       | {workspace: .workspace.name, workspace_id: .workspace.id, hypr_address: .address}' \
      <<<"$clients")
    agents+=$(jq -c --argjson kpid "$kpid" --argjson hypr "$hypr" \
      --arg agent_re "$AGENT_RE" --arg wrapper_re "$WRAPPER_RE" '
      .[] as $osw | $osw.tabs[] as $tab | $tab.windows[] as $w
      | ($w.foreground_processes // [])[] as $fp
      | ($fp.cmdline // []) as $cmd
      | (($cmd[0] // "") | split("/") | last) as $base
      | (if ($base | test($wrapper_re))
         then (($cmd[1] // "") | split("/") | last)
         else $base end) as $name
      | select($name | test($agent_re))
      | $hypr + {
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
          tab_id: $tab.id
        }' <<<"$tree")$'\n'
  done

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
