#!/bin/bash

# jaeger: launcher for the quickshell agent panel.
#
# Usage: jaeger.sh [start|stop|toggle]   (default: toggle)

DIR=$(dirname "$(readlink -f "$0")")
QML="$DIR/shell.qml"

is_running() {
  pgrep -f "quickshell -p $QML" >/dev/null
}

case "${1:-toggle}" in
start)
  is_running || setsid quickshell -p "$QML" >/dev/null 2>&1 &
  ;;
stop)
  pkill -f "quickshell -p $QML"
  ;;
toggle)
  if is_running; then
    pkill -f "quickshell -p $QML"
  else
    setsid quickshell -p "$QML" >/dev/null 2>&1 &
  fi
  ;;
*)
  echo "Usage: $0 [start|stop|toggle]"
  exit 1
  ;;
esac
