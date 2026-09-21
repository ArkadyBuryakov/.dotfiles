-- ##############################################################################
-- Workspace Layouts settings
-- ##############################################################################

local roles = require("conf/roles")

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
-- Roles rather than output names: this config is shared between machines whose
-- screens are called different things (see conf/roles.lua).
-- 1-9/11-19 are persistent so they always exist in the compositor: waybar's
-- ext/workspaces module renders only live ext-workspace-v1 entries and has no
-- bar-side persistent-workspaces option like hyprland/workspaces had.
-- 11-19 are persistent only while the secondary monitor is connected,
-- otherwise they'd get moved to the primary and clutter its bar with a second
-- set of buttons.
local function apply_monitor_bindings()
	local r = roles.resolve()

	for i = 1, 10 do
		hl.workspace_rule({
			workspace = tostring(i),
			monitor = r.primary,
			default = (i == 1),
			persistent = (r.primary ~= nil and i <= 9),
		})
	end

	for i = 11, 20 do
		hl.workspace_rule({
			workspace = tostring(i),
			monitor = r.secondary,
			default = (i == 11),
			persistent = (r.secondary_connected and i <= 19),
		})
	end
end

apply_monitor_bindings()

-- Hotplug changes which output holds which role, and waybar's ext/workspaces
-- module keeps stale buttons when workspaces switch groups (11-19 linger on the
-- primary bar after the secondary reconnects), so rebind and rebuild the bars
-- once the compositor state has settled.
local function on_monitor_change()
	apply_monitor_bindings()
	roles.reload_waybar()
end

hl.on("monitor.added", on_monitor_change)
hl.on("monitor.removed", on_monitor_change)

-- Workspace rules
hl.workspace_rule({ workspace = "special:magic", on_created_empty = "Telegram & gtk-launch org.arkady.todo.desktop" })
hl.workspace_rule({ workspace = "special:config", on_created_empty = "gtk-launch org.arkady.config.desktop" })

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
