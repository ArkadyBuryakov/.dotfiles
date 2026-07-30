#!/bin/bash

# jaeger: Claude Code hook — writes the agent's state to a runtime file so
# scan.sh can report precise status (busy / waiting for input / idle).
#
# Wire it in ~/.claude/settings.json for the events:
#   UserPromptSubmit -> busy, Notification -> waiting, Stop -> idle,
#   SessionEnd -> cleanup
#
# Reads the hook payload on stdin; keys the state file by the claude pid
# (found by walking up the process tree).

STATUS_DIR="${XDG_RUNTIME_DIR:-/tmp}/jaeger"
mkdir -p "$STATUS_DIR"

event=$(jq -r '.hook_event_name // empty')

# Find the claude ancestor pid (hooks run under a shell spawned by claude)
pid=$PPID
while [ "$pid" -gt 1 ]; do
  [ "$(ps -o comm= -p "$pid" 2>/dev/null)" = "claude" ] && break
  pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  [ -z "$pid" ] && exit 0
done
[ "$pid" -le 1 ] && exit 0

case "$event" in
UserPromptSubmit) state=busy ;;
Notification) state=waiting ;;
Stop) state=idle ;;
SessionEnd)
  rm -f "$STATUS_DIR/$pid.json"
  exit 0
  ;;
*) exit 0 ;;
esac

printf '{"pid": %d, "state": "%s"}\n' "$pid" "$state" >"$STATUS_DIR/$pid.json"
