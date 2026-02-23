#!/bin/bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="$HOME/.config"

# Symlink config directories
CONFIG_DIRS=(hypr kitty mako nvim rofi waybar wlogout yazi lazygit)

for dir in "${CONFIG_DIRS[@]}"; do
  rm -rf "$CONFIG_DIR/$dir"
  ln -sf "$DOTFILES/$dir" "$CONFIG_DIR/$dir"
  echo "==> Linked $CONFIG_DIR/$dir"
done

# Symlink home dotfiles
for file in "$DOTFILES/home/".*; do
  name="$(basename "$file")"
  [[ "$name" == "." || "$name" == ".." ]] && continue
  rm -f "$HOME/$name"
  ln -sf "$file" "$HOME/$name"
  echo "==> Linked ~/$name"
done
