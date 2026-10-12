-- ##############################################################################
-- Docked sidebar (quickshell/Sidebar.qml)
-- ##############################################################################

-- A monitor with a docked window gives up smart gaps (conf/workspaces.lua):
-- tiled windows keep their gaps and borders there even when alone, so they
-- stay visually apart from the sidebar.
--
-- Quickshell keeps a layer with this namespace mapped on a monitor for as long
-- as a window is docked there (quickshell/SidebarPanel.qml).
local NAMESPACE = "quickshell-sidebar"
-- Tag quickshell puts on the docked window
local TAG = "sidebar"

local M = {}

-- Monitor name -> rules overriding the smart gaps ones there
local overrides = {}

local function override(monitor)
	local workspace = "m[" .. monitor .. "] s[false]"
	return {
		hl.workspace_rule({
			workspace = workspace,
			gaps_out = hl.get_config("general.gaps_out"),
			gaps_in = hl.get_config("general.gaps_in"),
		}),
		hl.window_rule({
			match = { float = false, workspace = workspace },
			border_size = hl.get_config("general.border_size"),
		}),
	}
end

---@param closing HL.LayerSurface|nil layer that is going away but may still be listed
local function refresh(closing)
	local docked = {}
	for _, layer in ipairs(hl.get_layers({ namespace = NAMESPACE })) do
		local gone = closing and layer.address == closing.address
		if layer.monitor and not gone then
			docked[layer.monitor.name] = true
		end
	end

	for monitor in pairs(docked) do
		overrides[monitor] = overrides[monitor] or override(monitor)
	end
	for monitor, rules in pairs(overrides) do
		for _, rule in ipairs(rules) do
			rule:set_enabled(docked[monitor] == true)
		end
	end
end

hl.on("layer.opened", function()
	refresh()
end)
hl.on("layer.closed", refresh)
refresh()

--- Pin the docked windows, except under a fullscreen window.
---
--- Pinning is what carries a docked window across workspaces, but Hyprland
--- also draws pinned windows over fullscreen ones. So a docked window gets
--- unpinned while its monitor shows a fullscreen window, which leaves it
--- behind that window, and pinned again once the monitor shows something else.
function M.sync()
	for _, dock in ipairs(hl.get_windows({ tag = TAG })) do
		local monitor = dock.monitor
		local workspace = monitor and (monitor.active_special_workspace or monitor.active_workspace)
		local fullscreen = workspace and workspace.fullscreen_mode == 2 and workspace.fullscreen_window
		local covered = fullscreen and fullscreen.address ~= dock.address

		if covered and dock.pinned then
			hl.dispatch(hl.dsp.window.pin({ window = dock }))
			hl.dispatch(hl.dsp.window.alter_zorder({ mode = "bottom", window = dock }))
		elseif workspace and not covered and not dock.pinned and dock.floating then
			-- Changing workspace shifts a floating window, so put it back
			local x, y = dock.at.x, dock.at.y
			if dock.workspace and dock.workspace.id ~= workspace.id then
				hl.dispatch(hl.dsp.window.move({ workspace = workspace.id, follow = false, window = dock }))
			end
			hl.dispatch(hl.dsp.window.pin({ window = dock }))
			hl.dispatch(hl.dsp.window.move({ x = x, y = y, window = dock }))
		end
	end
end

-- Not from inside the event: the state it announces may not have settled
local function sync_later()
	hl.timer(M.sync, { timeout = 10, type = "oneshot" })
end

for _, event in ipairs({
	"window.fullscreen",
	"window.close",
	"window.move_to_workspace",
	"workspace.active",
	"workspace.special_active",
}) do
	hl.on(event, sync_later)
end

---@return HL.Window|nil window docked on the monitor
local function docked_on(monitor)
	return hl.get_windows({ tag = TAG, monitor = monitor })[1]
end

---@param window HL.Window|nil
---@return boolean docked whether the window is docked on some monitor
function M.is_docked(window)
	for _, docked in ipairs(window and hl.get_windows({ tag = TAG }) or {}) do
		if docked.address == window.address then
			return true
		end
	end
	return false
end

--- Wrap a dispatcher so that it leaves a docked window where it is.
---@param dispatcher HL.Dispatcher
---@return function
function M.unless_docked(dispatcher)
	return function()
		if not M.is_docked(hl.get_active_window()) then
			hl.dispatch(dispatcher)
		end
	end
end

--- Windows of the workspace shown on the monitor, the docked one aside.
local function neighbours(monitor, dock)
	local workspace = monitor.active_special_workspace or monitor.active_workspace
	local windows = {}
	for _, window in ipairs(workspace and hl.get_workspace_windows(workspace) or {}) do
		if window.address ~= dock.address and not window.hidden then
			windows[#windows + 1] = window
		end
	end
	return windows
end

--- Directional focus that also steps into and out of the docked window.
--- Hyprland itself never crosses between a tiled window and a floating one.
---@param direction "left"|"right"|"up"|"down"
function M.focus(direction)
	local active = hl.get_active_window()
	local monitor = active and active.monitor or hl.get_active_monitor()
	local dock = monitor and docked_on(monitor)
	local target

	if dock and active and active.address == dock.address then
		if direction == "left" then
			-- Out of the sidebar: the window reaching furthest right, the
			-- most recently focused one if several do
			for _, window in ipairs(neighbours(monitor, dock)) do
				local edge, best = window.at.x + window.size.x, target and target.at.x + target.size.x
				if not target or edge > best or (edge == best and window.focus_history_id < target.focus_history_id) then
					target = window
				end
			end
		end
	elseif dock and direction == "right" and not (active and active.fullscreen == 2) then
		-- Into the sidebar, unless there still is a window further right
		target = dock
		for _, window in ipairs(active and neighbours(monitor, dock) or {}) do
			if window.at.x >= active.at.x + active.size.x then
				target = nil
				break
			end
		end
	end

	hl.dispatch(hl.dsp.focus(target and { window = target } or { direction = direction }))
end

return M
