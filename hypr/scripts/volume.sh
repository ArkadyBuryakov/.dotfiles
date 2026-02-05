#!/bin/bash
# Volume control script using wpctl for volume actions and notify-send for notifications.
#
# Usage:
#   ./volume.sh up      # Increase volume by 5%
#   ./volume.sh down    # Decrease volume by 5%
#   ./volume.sh toggle  # Toggle mute
#
# Note: When changing volume with "up" or "down", the script ensures that the sink is unmuted.
# A test sound will be played and a notification will be sent showing the new volume level.
#
# Replace TEST_SOUND file path with an appropriate sound file in your system.

TEST_SOUND="/usr/share/sounds/freedesktop/stereo/audio-volume-change.oga"
SOUND_SINK="@DEFAULT_SINK@"
LABEL="volume-control" # Used for notification replacement
PREVIOUS_ID="$(<${XDG_RUNTIME_DIR}/arkady_sys_notification_id)"
PREVIOUS_ID="${PREVIOUS_ID:-0}"

function get_volume() {
  # Get the current volume as a decimal (e.g. "Volume: 0.65")
  local output
  output=$(wpctl get-volume "$SOUND_SINK" 2>/dev/null)

  # Extract the decimal value using grep and awk
  local volume
  volume=$(echo "$output" | grep -oE '[0-9]+\.[0-9]+')

  # Convert the volume to a percentage using awk
  local percent
  percent=$(awk -v vol="$volume" 'BEGIN {printf "%d", vol * 100}')

  echo "$percent"
}

function is_muted() {
  # Get the raw output of the volume command.
  output=$(wpctl get-volume "$SOUND_SINK" 2>/dev/null)

  # Check for the "[MUTED]" marker.
  if [[ "$output" == *"[MUTED]"* ]]; then
    echo 1
  else
    echo 0
  fi
}

function send_vol_notification() {
  local volume_percent=$(get_volume)
  # The -r option replaces previous notifications with the same id.
  notify-send "Volume: ${volume_percent}%" -h int:value:"${volume_percent}" -c system
}

function send_mute_notification() {
  local volume_percent=$(get_volume)
  if [[ $(is_muted) == 1 ]]; then
    notify-send "Muted  " -h int:value:0 -c system
  else
    notify-send "Unmuted  : ${volume_percent}%" -h int:value:"${volume_percent}" -c system
  fi
}

function play_test_sound() {
  if command -v mpv &>/dev/null && [ -f "$TEST_SOUND" ]; then
    mpv "$TEST_SOUND" &
  fi
}

function increase_volume() {
  wpctl set-volume -l 1.0 "$SOUND_SINK" 5%+
  # Unmute the sink after changing the volume.
  wpctl set-mute "$SOUND_SINK" 0
}

function decrease_volume() {
  wpctl set-volume -l 1.0 "$SOUND_SINK" 5%-
  # Unmute the sink after changing the volume.
  wpctl set-mute "$SOUND_SINK" 0
}

function toggle_mute() {
  wpctl set-mute "$SOUND_SINK" toggle
}

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 {up|down|toggle}"
  exit 1
fi

case "$1" in
up)
  increase_volume
  ;;
down)
  decrease_volume
  ;;
toggle)
  toggle_mute
  ;;
*)
  echo "Invalid parameter: $1"
  echo "Usage: $0 {up|down|toggle}"
  exit 1
  ;;
esac

# Allow a short delay for the volume change to be applied.
sleep 0.1

# Play the test sound.
play_test_sound

# Get updated volume and send notification only if the operation was a volume change.
if [[ "$1" == "up" || "$1" == "down" ]]; then
  send_vol_notification
elif [[ "$1" == "toggle" ]]; then
  send_mute_notification
fi

exit 0
