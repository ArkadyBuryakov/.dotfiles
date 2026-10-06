#!/bin/bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="$HOME/.config"

# Symlink config directories
CONFIG_DIRS=(hypr kitty mako nvim quickshell rofi swappy yazi lazygit lazydocker workforest vm)

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
  "kde/kxkbrc:kxkbrc"
  "teams-for-linux/config.json:teams-for-linux/config.json"
  "btop/themes/neutron.theme:btop/themes/neutron.theme"
  "k9s/skins/neutron.yaml:k9s/skins/neutron.yaml"
)

for entry in "${CONFIG_FILES[@]}"; do
  src="${entry%%:*}"
  dest="${entry#*:}"
  mkdir -p "$(dirname "$CONFIG_DIR/$dest")"
  rm -rf "$CONFIG_DIR/$dest"
  ln -sfn "$DOTFILES/$src" "$CONFIG_DIR/$dest"
  echo "==> Linked $CONFIG_DIR/$dest"
done

# btop rewrites its config on exit, so the file itself is not tracked: only
# the theme is linked (above), and selected here.
BTOP_CONF="$CONFIG_DIR/btop/btop.conf"
touch "$BTOP_CONF"
sed -i '/^color_theme = /d' "$BTOP_CONF"
echo 'color_theme = "neutron"' >>"$BTOP_CONF"
echo "==> Selected btop theme neutron"

# Same for k9s: it rewrites config.yaml itself, so only the skin is tracked.
K9S_CONF="$CONFIG_DIR/k9s/config.yaml"
if [[ -f "$K9S_CONF" ]] && grep -q '^  ui:$' "$K9S_CONF"; then
  sed -i -e '/^    skin: /d' -e 's/^  ui:$/  ui:\n    skin: neutron/' "$K9S_CONF"
else
  printf 'k9s:\n  ui:\n    skin: neutron\n' >"$K9S_CONF"
fi
echo "==> Selected k9s skin neutron"

# systemd user drop-ins. These override packaged units without touching
# /usr/lib, which is how the notification daemons are kept apart: see
# systemd/user/mako.service.d/hyprland-only.conf.
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_USER_DIR"
for dropin in "$DOTFILES/systemd/user/"*.d; do
  name="$(basename "$dropin")"
  rm -rf "$SYSTEMD_USER_DIR/$name"
  ln -sfn "${dropin%/}" "$SYSTEMD_USER_DIR/$name"
  echo "==> Linked $SYSTEMD_USER_DIR/$name"
done
systemctl --user daemon-reload
echo "==> Reloaded systemd user units"

# Symlink home dotfiles
for file in "$DOTFILES/home/".*; do
  name="$(basename "$file")"
  [[ "$name" == "." || "$name" == ".." ]] && continue
  rm -f "$HOME/$name"
  ln -sf "$file" "$HOME/$name"
  echo "==> Linked ~/$name"
done
