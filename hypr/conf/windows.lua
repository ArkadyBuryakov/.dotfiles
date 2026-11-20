-- ##############################################################################
-- Window rules
-- ##############################################################################

-- Allow windows to steal focus
hl.config({
	misc = {
		focus_on_activate = true,
		initial_workspace_tracking = 0,
	},

	xwayland = {
		force_zero_scaling = true,
	},
})

-- Disable blur for all windows
-- hl.window_rule({ match = { class = "(.*)" }, no_blur = true })

-- Force focus on auth agent
hl.window_rule({
	name = "Polkit Agent",
	match = { class = "(hyprpolkitagent)" },

	stay_focused = true,
})

hl.window_rule({
	name = "Float GTK Portal file chooser dialogs",
	match = { class = "(xdg-desktop-portal-gtk)" },

	float = true,
})

hl.window_rule({
	name = "Float and Pin Calculator",
	match = { class = "(org.gnome.Calculator)" },

	float = true,
	pin = true,
})

-- Title becomes "N Reminder(s)" once loaded, so match the initial one
hl.window_rule({
	name = "Float Thunderbird calendar reminders",
	match = { class = "(org.mozilla.Thunderbird)", initial_title = "(Calendar Reminders)" },

	float = true,
})

-- Supress fullscreen for some applications
hl.window_rule({ match = { class = "(.*)" }, suppress_event = "maximize" })
hl.window_rule({ match = { class = "(firefox)" }, fullscreen_state = "0 0" })
-- hl.window_rule({ match = { class = "(zen)" }, fullscreen_state = "0 0" })
hl.window_rule({ match = { class = "(yaak-app)" }, fullscreen_state = "0 0" })

-- Game rules
hl.window_rule({ match = { class = "(steam_app_.*)" }, fullscreen_state = "2 2" })

-- Enforce fake fullscreen for some applications
hl.window_rule({ match = { class = "(org.gnome.Loupe)" }, fullscreen_state = "0 2" })

-- Automatically float and maximize telegram media viewer
hl.window_rule({
	match = { class = "(org.telegram.desktop)", initial_title = "(Telegram)" },
	workspace = "special:magic",
})
hl.window_rule({ match = { class = "(org.telegram.desktop)", title = "(Media viewer)" }, float = true, maximize = true })

-- MEGAsync's tray popup is a frameless fixed-size Qt window; tiled, it gets
-- stretched and renders broken. Its other windows have different titles.
-- Placed under the tray, top right.
-- No stay_focused: Qt5's D-Bus tray treats ANY notification's ActionInvoked as
-- a click on its own message, so clicking a mako notification pops this open.
-- Letting it close on focus loss keeps those accidental opens harmless.
hl.window_rule({
	name = "MEGAsync tray popup",
	match = { class = "^(megasync)$", title = "^(MEGAsync)$" },

	float = true,
	size = { 402, 564 },
	move = { "monitor_w-window_w-12", "42" },
})

-- Float some tui menus
hl.window_rule({
	name = "Antivirus Threat Manager",
	match = { class = "(kitty)", title = "(Antivirus)$" },

	float = true,
	size = { 800, 500 },
	border_color = "rgba(B53F36FF)",
})

-- XWaylandVideoBridge
hl.window_rule({
	match = { class = "^(xwaylandvideobridge)$" },

	opacity = "0.0 override 0.0 override",
	no_anim = true,
	no_initial_focus = true,
	max_size = { 1, 1 },
	no_blur = true,
})

-- Stop floating for strudel repl from strudel.nvim
hl.window_rule({ match = { title = "^(strudel.cc_/)$" }, tile = true })

-- RDP sessions into the docker-hosted VMs (see bin/vm).
-- The window is a remote desktop: blur and entry animations only add latency to
-- something that is already a video stream over a socket.
hl.window_rule({
	name = "VM remote desktop",
	match = { class = "^(xfreerdp|xfreerdp3)$" },

	no_blur = true,
	no_anim = true,
})
