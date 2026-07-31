-- ##############################################################################
-- Workspace Layouts settings
-- ##############################################################################

hl.config({
	general = {
		-- Set default layout
		layout = "dwindle",

		resize_on_border = true,
	},

	binds = {
		hide_special_on_workspace_change = true,
	},

	-- Layouts settings

	dwindle = {
		-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
		-- pseudotile = false,
		force_split = 2,
		preserve_split = true,
	},

	master = {
		-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
		-- Isn't actually used in this config
		mfact = 0.7,
	},
})

-- Monitor bindings
-- 1-9/11-19 are persistent so they always exist in the compositor: waybar's
-- ext/workspaces module renders only live ext-workspace-v1 entries and has no
-- bar-side persistent-workspaces option like hyprland/workspaces had.
-- 11-19 are persistent only while DP-1 is connected, otherwise they'd get
-- moved to eDP-1 and clutter the laptop bar with a second set of buttons.
for i = 1, 10 do
	hl.workspace_rule({ workspace = tostring(i), monitor = "eDP-1", default = (i == 1), persistent = (i <= 9) })
end

local function dp1_workspace_rules(connected)
	for i = 11, 20 do
		hl.workspace_rule({
			workspace = tostring(i),
			monitor = "DP-1",
			default = (i == 11),
			persistent = (connected and i <= 19),
		})
	end
end

dp1_workspace_rules(hl.get_monitor("DP-1") ~= nil)

hl.on("monitor.added", function(mon)
	if mon.name == "DP-1" then
		dp1_workspace_rules(true)
	end
end)

hl.on("monitor.removed", function(mon)
	if mon.name == "DP-1" then
		dp1_workspace_rules(false)
	end
end)

-- Workspace rules
hl.workspace_rule({ workspace = "special:magic", on_created_empty = "Telegram & slack" })
hl.workspace_rule({ workspace = "special:config", on_created_empty = "gtk-launch org.arkady.config.desktop" })
hl.workspace_rule({
	workspace = "special:monorepo_fleetcraft",
	on_created_empty = "gtk-launch org.fleetcraft.monorepo.desktop",
})
hl.workspace_rule({
	workspace = "special:monorepo_aino",
	on_created_empty = "gtk-launch org.aino.aino-monorepo.desktop",
})

-- Smart gaps
-- https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/#smart-gaps
hl.workspace_rule({ workspace = "s[true]", gaps_out = 25, gaps_in = 12 })
hl.workspace_rule({ workspace = "s[false] w[tv1] w[g0]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "s[false] w[tv1] w[g1]", gaps_out = 4, gaps_in = 4 })
hl.workspace_rule({ workspace = "s[false] f[1]", gaps_out = 0, gaps_in = 0 })
hl.window_rule({ match = { float = false, workspace = "w[tv1] w[g0] s[false]" }, border_size = 0 })
hl.window_rule({ match = { float = false, workspace = "w[tv1] w[g0] s[false]" }, rounding = 0 })
hl.window_rule({ match = { float = false, workspace = "f[1] s[false]" }, border_size = 0 })
hl.window_rule({ match = { float = false, workspace = "f[1] s[false]" }, rounding = 0 })
