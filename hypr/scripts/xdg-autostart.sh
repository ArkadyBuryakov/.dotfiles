#!/usr/bin/env bash
#
# Run XDG autostart entries (~/.config/autostart, /etc/xdg/autostart) under
# Hyprland.
#
# systemd-xdg-autostart-generator already turns every entry into an
# app-*@autostart.service unit, honouring Hidden=, TryExec= and (through an
# ExecCondition) OnlyShowIn=/NotShowIn= against XDG_CURRENT_DESKTOP. But the
# xdg-desktop-autostart.target that pulls them in has RefuseManualStart=yes and
# is only started by session managers (GNOME, Plasma, uwsm), so nothing starts
# them here. Start the units the target wants directly.
#
# To keep an entry from starting, override it in ~/.config/autostart with the
# same file name and Hidden=true.

# ExecCondition compares OnlyShowIn/NotShowIn against the systemd environment
systemctl --user import-environment XDG_CURRENT_DESKTOP WAYLAND_DISPLAY

# Regenerate units, so entries added since boot are picked up
systemctl --user daemon-reload

# Tray apps need the StatusNotifierWatcher (Quickshell) to register their icon
for _ in $(seq 30); do
  busctl --user status org.kde.StatusNotifierWatcher >/dev/null 2>&1 && break
  sleep 1
done

wants="${XDG_RUNTIME_DIR:-/run/user/$UID}/systemd/generator.late/xdg-desktop-autostart.target.wants"
units=()
for u in "$wants"/*.service; do
  [[ -e "$u" ]] && units+=("${u##*/}")
done
(( ${#units[@]} )) || exit 0

systemctl --user start --no-block -- "${units[@]}"
