#!/bin/bash

send_notification() {
  local title="$1"
  local message="$2"
  local urgency="${3:-normal}"

  if command -v notify-send &>/dev/null; then
    notify-send -c system -u "$urgency" -i "network-vpn" "$title" "$message"
  fi

  echo "$title"
  echo "$message"
}

if [ -z "$1" ]; then
  send_notification "VPN Toggle Script Error" "Error: VPN name argument is required." "critical"
  echo "Usage: $0 \"Your VPN Name\""
  echo "Example: $0 \"Personal DE\""
  exit 1
fi

VPN_NAME="$1"

if nmcli connection show --active | grep -q "^${VPN_NAME}"; then
  initial_active=true
  action_verb="deactivated"
  base_verb="deactivate"
  echo "VPN '$VPN_NAME' is currently active. Attempting to deactivate..."
  nmcli connection down "$VPN_NAME"
  cmd_exit=$?
else
  initial_active=false
  action_verb="activated"
  base_verb="activate"
  echo "VPN '$VPN_NAME' is currently inactive. Attempting to activate..."
  nmcli connection up "$VPN_NAME"
  cmd_exit=$?
fi

success=false
if [ $cmd_exit -eq 0 ]; then
  success=true
fi

if nmcli connection show --active | grep -q "^${VPN_NAME}"; then
  final_active=true
  final_state="ACTIVE"
else
  final_active=false
  final_state="INACTIVE"
fi

final_urgency="critical"
if $success; then
  final_urgency="normal"
fi

echo ""
echo "--- Operation Summary ---"
echo "  - Current state: '$VPN_NAME' is now $final_state."
if ! $success; then
  echo "  - Operation FAILED. Please check terminal output for details."
fi
echo "-------------------------"

title="VPN \"$VPN_NAME\" - $final_state"
if $success; then
  message="Connection was successfully $action_verb"
else
  message="Unable to $base_verb connection"
fi
send_notification "$title" "$message" "$final_urgency"

if ! $success; then
  exit 1
fi
