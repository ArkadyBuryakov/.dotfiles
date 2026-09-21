-- ##############################################################################
-- Monitor roles
-- ##############################################################################
--
-- This config is shared between machines with different outputs, so nothing
-- downstream may hardcode an output name. Everything is expressed as two roles
-- resolved from whatever is actually connected:
--
--   primary   - hosts workspaces 1-9. The built-in laptop panel when there is
--               one, otherwise simply the first screen that is plugged in, so a
--               desktop with a single unknown output works out of the box.
--   secondary - hosts workspaces 11-19. The external screen.

local M = {}

-- Built-in panels. Always take the primary role when connected.
local BUILTIN = { "eDP-1", "eDP-2", "LVDS-1" }

-- External outputs, in the order they are picked for a role.
local EXTERNAL = { "DP-1", "HDMI-A-1", "DP-2", "HDMI-A-2", "DP-3", "HDMI-A-3" }

local function connected_names()
	local names = {}
	for _, monitor in ipairs(hl.get_monitors()) do
		names[monitor.name] = true
	end
	return names
end

local function first_connected(candidates, names, exclude)
	for _, name in ipairs(candidates) do
		if names[name] and name ~= exclude then
			return name
		end
	end
end

--- Resolve the monitor roles for the currently connected outputs.
---
--- `secondary` is returned even while disconnected so workspaces 11-19 keep
--- their binding and migrate back on hotplug; `secondary_connected` tells
--- whether it is actually present.
---@return { primary: string|nil, secondary: string|nil, secondary_connected: boolean }
function M.resolve()
	local names = connected_names()

	local primary = first_connected(BUILTIN, names) or first_connected(EXTERNAL, names)
	if not primary then
		-- An output this config has never heard of: still better than no primary.
		local monitors = hl.get_monitors()
		primary = monitors[1] and monitors[1].name
	end

	local secondary = first_connected(EXTERNAL, names, primary)
	local secondary_connected = secondary ~= nil
	if not secondary then
		-- Nothing else is plugged in, so reserve the preferred external output
		-- for workspaces 11-19 rather than leaving them unbound.
		for _, name in ipairs(EXTERNAL) do
			if name ~= primary then
				secondary = name
				break
			end
		end
	end

	return { primary = primary, secondary = secondary, secondary_connected = secondary_connected }
end

--- Start or restart waybar with a bar per connected monitor for the current roles.
function M.reload_waybar()
	local r = M.resolve()
	hl.exec_cmd(
		string.format(
			"~/.config/hypr/scripts/restart-waybar.sh '%s' '%s'",
			r.primary or "",
			r.secondary_connected and r.secondary or ""
		)
	)
end

--- Move workspaces 1-9/11-19 back onto the monitor their role owns.
function M.reassign_workspaces()
	local r = M.resolve()

	local function move(from, to, monitor)
		if not monitor then
			return
		end
		for i = from, to do
			hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(i), monitor = monitor }))
		end
	end

	move(1, 10, r.primary)
	move(11, 20, r.secondary_connected and r.secondary or r.primary)

	-- Cross-group moves leave stale buttons in waybar's ext/workspaces module
	M.reload_waybar()
end

return M
