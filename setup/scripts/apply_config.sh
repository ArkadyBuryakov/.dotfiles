#!/bin/bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="$HOME/.config"

# Symlink config directories
CONFIG_DIRS=(hypr kitty mako nvim rofi swappy waybar wlogout yazi lazygit lazydocker workforest vm)

for dir in "${CONFIG_DIRS[@]}"; do
  rm -rf "$CONFIG_DIR/$dir"
  ln -sf "$DOTFILES/$dir" "$CONFIG_DIR/$dir"
  echo "==> Linked $CONFIG_DIR/$dir"
done

# Symlink individual config files (repo path -> ~/.config path)
CONFIG_FILES=(
  "kde/kglobalshortcutsrc:kglobalshortcutsrc"
)

for entry in "${CONFIG_FILES[@]}"; do
  src="${entry%%:*}"
  dest="${entry#*:}"
  mkdir -p "$(dirname "$CONFIG_DIR/$dest")"
  rm -rf "$CONFIG_DIR/$dest"
  ln -sfn "$DOTFILES/$src" "$CONFIG_DIR/$dest"
  echo "==> Linked $CONFIG_DIR/$dest"
done

# Symlink home dotfiles
for file in "$DOTFILES/home/".*; do
  name="$(basename "$file")"
  [[ "$name" == "." || "$name" == ".." ]] && continue
  rm -f "$HOME/$name"
  ln -sf "$file" "$HOME/$name"
  echo "==> Linked ~/$name"
done
