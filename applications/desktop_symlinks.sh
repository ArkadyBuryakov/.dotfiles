#!/bin/bash
# This script creates symlinks in ~/.local/share/applications
# for all files in the current directory ending with .desktop.
#
# Usage:
#   ./desktop_symlinks.sh          # prompts for each conflict
#   ./desktop_symlinks.sh Y        # automatically overwrite on conflicts
#   ./desktop_symlinks.sh N        # automatically skip overwriting

TARGET_DIR="$HOME/.local/share/applications"

# Create target directory if it does not exist.
mkdir -p "$TARGET_DIR"

# Check if a flag (Y or N) is provided.
auto_response=""
if [[ "$1" == "Y" || "$1" == "N" ]]; then
  auto_response="$1"
fi

# Global flags used when the user chooses yes/no for all subsequent
global_yes=0
global_no=0

# confirm_overwrite takes one argument: the destination file path.
# It returns 0 (yes) or 1 (no) based on:
# - Global yes/no flags (or auto flag if provided),
# - or prompts the user with:
#   (n) - no,
#   (N) - no to all,
#   (y) - yes,
#   (Y) - yes to all.
confirm_overwrite() {
  local file="$1"

  # Apply global decision if already set.
  if [ "$global_yes" -eq 1 ]; then
    return 0
  elif [ "$global_no" -eq 1 ]; then
    return 1
  fi

  # If an auto response flag was provided.
  if [ -n "$auto_response" ]; then
    if [ "$auto_response" == "Y" ]; then
      return 0
    elif [ "$auto_response" == "N" ]; then
      return 1
    fi
  fi

  # Otherwise, ask the user.
  while true; do
    echo -n "Target file '$file' exists. Overwrite? (n/N/y/Y): "
    read -r answer
    case "$answer" in
    Y)
      global_yes=1
      return 0
      ;;
    y)
      return 0
      ;;
    N)
      global_no=1
      return 1
      ;;
    n)
      return 1
      ;;
    *)
      echo "Please answer y (yes), Y (yes to all), n (no), or N (no to all)."
      ;;
    esac
  done
}

# Enable nullglob so that the pattern expands to nothing
# if no .desktop files are found.
shopt -s nullglob

# Process all .desktop files in the current directory.
for file in *.desktop; do
  # Get the absolute path of the source file.
  src="$(pwd)/$file"
  dest="$TARGET_DIR/$file"

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    # If a file or symlink already exists, ask (or use auto response).
    if confirm_overwrite "$dest"; then
      rm -rf "$dest"
      ln -s "$src" "$dest"
      echo "Overwritten and created symlink for '$file'."
    else
      echo "Skipped '$file'."
    fi
  else
    ln -s "$src" "$dest"
    echo "Created symlink for '$file'."
  fi
done

# --- Icons -------------------------------------------------------------
# Mirror ../icons/hicolor into the user icon theme so .desktop files can
# refer to icons by bare name (Icon=org.arkady.foo) instead of by an
# absolute path, which would hardcode $HOME into the repo.
ICON_SRC="$(cd "$(dirname "$0")/../icons/hicolor" && pwd)"
ICON_DEST="$HOME/.local/share/icons/hicolor"

if [ -d "$ICON_SRC" ]; then
  while IFS= read -r -d '' icon; do
    rel="${icon#"$ICON_SRC"/}"
    mkdir -p "$ICON_DEST/$(dirname "$rel")"
    ln -sfn "$icon" "$ICON_DEST/$rel"
  done < <(find "$ICON_SRC" \( -type l -o -type f \) -print0)
  echo "Installed icons into '$ICON_DEST'."
fi

# Refresh the caches so the new entries/icons are picked up immediately.
command -v update-desktop-database >/dev/null && update-desktop-database "$TARGET_DIR"
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f -t "$ICON_DEST" 2>/dev/null
command -v kbuildsycoca6 >/dev/null && kbuildsycoca6 --noincremental 2>/dev/null
