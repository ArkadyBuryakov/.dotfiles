-- ##############################################################################
-- Automatically start required services
-- ##############################################################################

local roles = require("conf/roles")

hl.on("hyprland.start", function()
	-- Must run before other services so they inherit the session environment
	hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

	-- Enable wifi and bluetooth
	hl.exec_cmd("nmcli radio wifi on")
	hl.exec_cmd("rfkill unblock bluetooth")

	-- Wallpapers manager
	hl.exec_cmd("hyprpaper")

	-- Notification daemon
	hl.exec_cmd("mako")

	-- System bar. Bars are generated per monitor, so it is started through
	-- the same script that rebuilds them on hotplug.
	roles.reload_waybar()

	-- Authentication Agent
	hl.exec_cmd("systemctl --user start hyprpolkitagent")
	-- hl.exec_cmd("~/.config/hypr/scripts/auth-agent.sh")

	-- Run swayidle and media inhibitor
	hl.exec_cmd("hypridle")

	-- Per-window keyboard layout
	-- hl.exec_cmd("RUST_LOG='debug' /usr/bin/hyprland-per-window-layout > /tmp/hyprland-per-window-layout.log 2>&1")
	hl.exec_cmd("hyprland-per-window-layout")

	-- Connect headset
	-- hl.exec_cmd("~/.config/hypr/scripts/connect-headset.sh")

	-- Run keyring daemon
	hl.exec_cmd("kwalletd6")

	-- Setup 1password. Run it with flags so it could show windows and sync X11 clipboard to copy from app
	hl.exec_cmd("clipsync watch without-notifications")
end)
