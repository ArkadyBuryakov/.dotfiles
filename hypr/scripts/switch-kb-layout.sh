#!/bin/bash

default_keyboard="at-translated-set-2-keyboard"

# Get the optional layout ID argument
ARG_TARGET_ID="$1"

# Check if hyprctl is available
if ! command -v hyprctl &>/dev/null; then
  echo "Error: hyprctl not found. Is Hyprland running and in your PATH?"
  exit 1
fi

# Check if jq is available
if ! command -v jq &>/dev/null; then
  echo "Error: jq not found. Please install it."
  exit 1
fi

# --- Find Main Keyboard Name and Active Keymap using jq ---
# Filter hyprctl devices -j output for the main keyboard and extract name and active_keymap
# jq filter explained:
# .keyboards[] : iterate through the array of keyboards
# select(.main == true) : find the object where 'main' is true
# .name, .active_keymap : output the 'name' and 'active_keymap' fields (jq outputs each on a new line by default)
main_keyboard_info=$(hyprctl devices -j | jq -r '.keyboards[] | select(.main == true) | .name, .active_keymap')

# Read the output of jq into variables
# IFS= read -r line; active_keyboard=$line; IFS= read -r line; active_layout=$line
# A more direct way using mapfile or process substitution:
# Use process substitution and mapfile to read multiline output directly
mapfile -t main_keyboard_array < <(echo "$main_keyboard_info")

active_keyboard="${main_keyboard_array[0]}"
active_layout="${main_keyboard_array[1]}"

# Check if we found the main keyboard information
if [ -z "$active_keyboard" ] || [ -z "$active_layout" ]; then
  echo "Error: Could not find main keyboard device or its active layout."
  echo "Please check 'hyprctl devices -j' output for a device with '\"main\": true'."
  exit 1
fi

# Note: With the JSON output and jq, we get the active_keymap (like "English (US)")
# We don't get the Active layout ID directly from the main keyboard object in the same easy way
# unless it's explicitly part of the JSON structure for the 'main: true' device.
# Based on the example JSON, 'active_layout_id' is not present at the same level.
# We'll rely on mapping "English (US)" to ID 0 and others to 1, as requested.
# If you had more complex layout switching, you might need a different strategy or
# parse the 'layout' string ("us,ru" in the example) and map it to IDs.
echo "Main Keyboard: '$active_keyboard'"
echo "Current Layout (active_keymap): '$active_layout'"

# --- Determine Target Layout ID ---
target_layout_id=""

if [ -n "$ARG_TARGET_ID" ]; then
  # Argument provided, use it as the target ID
  if [[ "$ARG_TARGET_ID" =~ ^[0-9]+$ ]]; then
    target_layout_id="$ARG_TARGET_ID"
    echo "Using provided target ID: $target_layout_id"
  else
    echo "Error: Provided argument '$ARG_TARGET_ID' is not a valid integer."
    exit 1
  fi
else
  # No argument, determine target based on current layout (active_keymap)
  echo "No target ID provided, determining based on current layout."
  # IMPORTANT: Match the exact string from active_keymap in your hyprctl output
  if [ "$active_layout" = "English (US)" ]; then
    target_layout_id="1"
    echo "Current layout is '$active_layout', targeting ID 1."
  else
    target_layout_id="0"
    echo "Current layout is '$active_layout', targeting ID 0."
  fi
fi

# --- Switch and Set Default Layout ---
echo "Switching keyboard '$active_keyboard' to layout ID $target_layout_id..."

# hyprctl switchxkblayout <keyboard_name> <layout_id>
# This command switches the layout for the specified keyboard and
# also sets that keyboard's layout as the default for new windows.
hyprctl switchxkblayout "$active_keyboard" "$target_layout_id"
hyprctl switchxkblayout "$default_keyboard" "$target_layout_id"

if [ $? -eq 0 ]; then
  echo "Successfully switched layout to ID $target_layout_id for '$active_keyboard'."
else
  echo "Error: Failed to switch layout using hyprctl."
  exit 1
fi

exit 0
