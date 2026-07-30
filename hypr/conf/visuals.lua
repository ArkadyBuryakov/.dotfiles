-- ##############################################################################
-- Visual settings
-- ##############################################################################

-- Set cursor style
hl.env("HYPRCURSOR_THEME", "HyprBibataModernClassicSVG")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic") -- Fallback for apps not supporting server-side cursors
hl.env("XCURSOR_SIZE", "24")

hl.on("hyprland.start", function()
	hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic'")
	hl.exec_cmd("gsettings set org.gnome.desktop.default-applications.terminal exec kitty")

	-- Apply dark theme
	hl.exec_cmd('gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"') -- for GTK4 apps
	hl.exec_cmd('gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark"') -- for GTK3 apps
end)

-- Set QT style
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

-- Make waybar transparent with blur effect
hl.layer_rule({
	name = "waybar rules",
	match = { namespace = "waybar" },

	xray = true,
	blur = true,
})
hl.layer_rule({ match = { namespace = "logout_dialog" }, blur = true })

-- Slide jaeger panel from/to the left edge on open/close
hl.layer_rule({
	name = "jaeger slide",
	match = { namespace = "jaeger" },
	animation = "slide left",
})

-- General settings
hl.config({
	general = {
		gaps_in = 4,
		gaps_out = 8,
		border_size = 2,
		col = {
			active_border = "rgba(6A7B92FF)",
			inactive_border = "rgba(595959FF)",
		},

		allow_tearing = false,
	},

	decoration = {
		rounding = 0,
		dim_special = 0.2,

		blur = {
			enabled = true,
			size = 3,
			passes = 2,
		},

		shadow = {
			enabled = false,
			range = 4,
			render_power = 3,
			color = "rgba(1a1a1aee)",
		},
	},

	animations = {
		enabled = true,
	},

	misc = {
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		force_default_wallpaper = 0,
	},

	group = {
		col = {
			border_active = "rgba(6A7B92FF)",
			border_inactive = "rgba(595959aa)",
			border_locked_active = "rgba(6A7B92FF)",
			border_locked_inactive = "rgba(595959aa)",
		},

		groupbar = {
			gaps_in = 4,
			gaps_out = 4,
			keep_upper_gap = false,
			font_family = "JetBrainsMono Nerd Font",
			font_size = 13,
			text_offset = 1,
			height = 16,
			indicator_height = 0,
			gradients = true,
			rounding = 0,
			gradient_rounding = 0,
			col = {
				active = "rgba(6A7B92AA)",
				inactive = "rgba(59595988)",
				locked_active = "rgba(6A7B92FF)",
				locked_inactive = "rgba(595959aa)",
			},
		},
	},
})

hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 7, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 7, bezier = "default" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 7, bezier = "myBezier", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 7, bezier = "myBezier", style = "fade" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 6, bezier = "myBezier", style = "fade" })
