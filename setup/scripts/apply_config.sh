#!/bin/bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="$HOME/.config"

# Symlink config directories
CONFIG_DIRS=(hypr kitty mako nvim rofi swappy waybar yazi lazygit lazydocker workforest vm)

for dir in "${CONFIG_DIRS[@]}"; do
  rm -rf "$CONFIG_DIR/$dir"
  ln -sf "$DOTFILES/$dir" "$CONFIG_DIR/$dir"
  echo "==> Linked $CONFIG_DIR/$dir"
done

# wlogout is linked file-by-file rather than as a whole directory, so that an
# "icons" symlink can be dropped alongside style.css. GTK resolves url(...) in
# CSS lexically, so "../icons/..." would escape to ~/.config/icons instead of
# following the directory symlink back into the repo -- the icons have to be
# reachable by a path that stays inside ~/.config/wlogout.
rm -rf "$CONFIG_DIR/wlogout"
mkdir -p "$CONFIG_DIR/wlogout"
for file in "$DOTFILES/wlogout/"*; do
  ln -sfn "$file" "$CONFIG_DIR/wlogout/$(basename "$file")"
done
ln -sfn "$DOTFILES/icons/hicolor/512x512/apps" "$CONFIG_DIR/wlogout/icons"
echo "==> Linked $CONFIG_DIR/wlogout (icons -> icons/hicolor/512x512/apps)"

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
