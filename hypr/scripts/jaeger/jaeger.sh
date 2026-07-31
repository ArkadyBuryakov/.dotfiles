#!/bin/bash

# jaeger: launcher for the quickshell agent panel.
#
# Usage: jaeger.sh [start|stop|restart|all|one|toggle]   (default: toggle)
#   start   - launch the panel (all monitors) if not running
#   stop    - kill the panel process
#   restart - stop + start (needed to pick up shell.qml changes)
#   all    - toggle panels on every monitor
#   one    - toggle a single panel on the focused monitor:
#            hidden -> open here; open elsewhere -> move here; open here -> close
#   toggle - alias for `all`

DIR=$(dirname "$(readlink -f "$0")")
QML="$DIR/shell.qml"

is_running() {
  pgrep -f "quickshell -p $QML" >/dev/null
}

launch() { # $1 = mode, $2 = monitor (one-mode only)
  JAEGER_MODE="$1" JAEGER_MONITOR="$2" setsid quickshell -p "$QML" >/dev/null 2>&1 &
}

ipc() {
  quickshell ipc -p "$QML" call jaeger "$@" >/dev/null 2>&1
}

focused_monitor() {
  hyprctl monitors -j | jq -r '.[] | select(.focused) | .name'
}

case "${1:-toggle}" in
start)
  is_running || launch all ""
  ;;
stop)
  pkill -f "quickshell -p $QML"
  ;;
restart)
  pkill -f "quickshell -p $QML"
  launch all ""
  ;;
all | toggle)
  if is_running; then
    ipc toggleAll
  else
    launch all ""
  fi
  ;;
one)
  MON=$(focused_monitor)
  if [ -z "$MON" ]; then # no monitors: nothing to open
    exit 0
  fi
  if is_running; then
    ipc toggleOne "$MON"
  else
    launch one "$MON"
  fi
  ;;
*)
  echo "Usage: $0 [start|stop|restart|all|one|toggle]"
  exit 1
  ;;
esac
