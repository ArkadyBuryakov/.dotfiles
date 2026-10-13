-- ##############################################################################
-- Docked sidebar (quickshell/Sidebar.qml)
-- ##############################################################################

-- A monitor with a docked window gives up smart gaps (conf/workspaces.lua):
-- tiled windows keep their gaps and borders there even when alone, so they
-- stay visually apart from the sidebar.
--
-- Quickshell keeps a layer with this namespace mapped on a monitor for as long
-- as its sidebar is open (quickshell/SidebarPanel.qml).
local NAMESPACE = "quickshell-sidebar"
-- Tag of the docked window: the one a sidebar has on show
local TAG = "sidebar"
-- Never shown: holds the other windows of a sidebar, and all of them while it
-- is closed
local STASH = "special:sidebar"

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
		-- The docked window lives on the regular workspace even while a
		-- special one is shown over it
		local home = monitor and monitor.active_workspace
		local shown = monitor and (monitor.active_special_workspace or home)
		local fullscreen = shown and shown.fullscreen_mode == 2 and shown.fullscreen_window
		local covered = fullscreen and fullscreen.address ~= dock.address

		if covered and dock.pinned then
			hl.dispatch(hl.dsp.window.pin({ window = dock }))
			hl.dispatch(hl.dsp.window.alter_zorder({ mode = "bottom", window = dock }))
		elseif home and not covered and not dock.pinned and dock.floating then
			-- Changing workspace shifts a floating window, so put it back
			local x, y = dock.at.x, dock.at.y
			if dock.workspace and dock.workspace.id ~= home.id then
				hl.dispatch(hl.dsp.window.move({ workspace = home.id, follow = false, window = dock }))
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

--- Quickshell owns the sidebars (which windows, which one is on show). It is
--- asked through a custom event, and answers by calling show/stash/release.
local function ask(...)
	hl.dispatch(hl.dsp.event("sidebar " .. table.concat({ ... }, " ")))
end

--- Dock a window: fit it into the strip of a monitor.
---@param address string
---@param monitor string
---@param strip integer width of the strip
---@param top integer height the tabs take above the window
---@param border integer
---@param focus boolean
function M.show(address, monitor, strip, top, border, focus)
	local w = hl.get_window("address:" .. address)
	local m = hl.get_monitor(monitor)
	if not w or not m then
		return
	end
	if w.fullscreen ~= 0 then
		local mode = w.fullscreen == 1 and "maximized" or "fullscreen"
		hl.dispatch(hl.dsp.window.fullscreen({ action = "unset", mode = mode, window = w }))
	end
	if not w.floating then
		hl.dispatch(hl.dsp.window.float({ action = "enable", window = w }))
	end
	-- Out of the stash, or over from another monitor
	local home = m.active_workspace
	if home and (not w.monitor or w.monitor.name ~= m.name or (w.workspace and w.workspace.name == STASH)) then
		if w.pinned then
			hl.dispatch(hl.dsp.window.pin({ window = w }))
		end
		hl.dispatch(hl.dsp.window.move({ workspace = home.id, follow = false, window = w }))
	end
	hl.dispatch(hl.dsp.window.tag({ tag = "+" .. TAG, window = w }))
	M.sync()
	local right = m.x + m.width / m.scale
	local height = m.height / m.scale - m.reserved.top - m.reserved.bottom
	local x, y = math.floor(right - strip + border), math.floor(m.y + m.reserved.top + top + border)
	local width, tall = strip - 2 * border, math.floor(height - top - 2 * border)
	hl.dispatch(hl.dsp.window.resize({ x = width, y = tall, window = w }))
	hl.dispatch(hl.dsp.window.move({ x = x, y = y, window = w }))
	if focus then
		hl.dispatch(hl.dsp.focus({ window = w }))
		-- Focusing the window that already has the focus leaves the cursor
		-- behind, and the windows rearranged under it would take the focus
		local cursor = hl.get_cursor_pos()
		if cursor and (cursor.x < x or cursor.x >= x + width or cursor.y < y or cursor.y >= y + tall) then
			hl.dispatch(hl.dsp.cursor.move({ x = x + width // 2, y = y + tall // 2 }))
		end
	end
end

--- Put a window of a sidebar out of sight.
---@param address string
function M.stash(address)
	local w = hl.get_window("address:" .. address)
	if not w or (w.workspace and w.workspace.name == STASH) then
		return
	end
	hl.dispatch(hl.dsp.window.tag({ tag = "-" .. TAG, window = w }))
	if w.pinned then
		hl.dispatch(hl.dsp.window.pin({ window = w }))
	end
	hl.dispatch(hl.dsp.window.move({ workspace = STASH, follow = false, window = w }))
end

--- Hand a window of a sidebar back to the tiling layout.
---@param address string
function M.release(address)
	local w = hl.get_window("address:" .. address)
	if not w then
		return
	end
	-- Nowhere to be tiled: in the stash, or pinned on a monitor that went
	-- away, which leaves it on none at all. Unpinning or tiling it there
	-- fails, the latter by taking Hyprland down.
	local lost = not w.monitor or (w.workspace and w.workspace.name == STASH)
	local monitor = lost and hl.get_active_monitor() or w.monitor
	-- Not behind the special workspace it may have been released from
	local workspace = monitor and (monitor.active_special_workspace or (lost and monitor.active_workspace))
	local function move()
		hl.dispatch(hl.dsp.window.move({ workspace = workspace.name, follow = false, window = w }))
	end
	if lost and not workspace then
		return
	elseif lost then
		move()
	end
	hl.dispatch(hl.dsp.window.tag({ tag = "-" .. TAG, window = w }))
	if w.pinned then
		hl.dispatch(hl.dsp.window.pin({ window = w }))
	end
	if workspace and not lost then
		move()
	end
	if w.floating then
		hl.dispatch(hl.dsp.window.float({ action = "disable", window = w }))
	end
end

-- Something focused a stashed window, which brings the stash up: hide it
-- again and have the sidebar show that window instead
hl.on("window.active", function(window)
	if window and window.workspace and window.workspace.name == STASH then
		local address = window.address
		hl.timer(function()
			for _, monitor in ipairs(hl.get_monitors()) do
				local special = monitor.active_special_workspace
				if special and special.name == STASH then
					hl.dispatch(hl.dsp.focus({ monitor = monitor.name }))
					hl.dispatch(hl.dsp.workspace.toggle_special("sidebar"))
				end
			end
			ask("select", address)
		end, { timeout = 10, type = "oneshot" })
	end
end)

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

--- Windows of the workspace shown on the monitor, the given one aside.
local function neighbours(monitor, except)
	local workspace = monitor.active_special_workspace or monitor.active_workspace
	local windows = {}
	for _, window in ipairs(workspace and hl.get_workspace_windows(workspace) or {}) do
		if window.address ~= except.address and not window.hidden then
			windows[#windows + 1] = window
		end
	end
	return windows
end

--- Open the sidebar of the focused monitor, or close it.
function M.toggle()
	local window = hl.get_active_window()
	local monitor = window and window.monitor or hl.get_active_monitor()
	if monitor then
		ask("toggle", monitor.name)
	end
end

--- Put the focused window into the sidebar of its monitor, or take it out.
function M.toggle_window()
	local window = hl.get_active_window()
	if not window or not window.monitor then
		return
	end
	if M.is_docked(window) then
		ask("remove", window.address)
	else
		ask("add", window.address, window.monitor.name)
	end
end

--- Whether a tiled window has nowhere further right to go but the sidebar.
local function rightmost(window)
	if window.floating or window.fullscreen ~= 0 or not window.monitor then
		return false
	end
	-- Moving right takes it out of the group first
	if window.group and window.group.size > 1 then
		return false
	end
	for _, other in ipairs(neighbours(window.monitor, window)) do
		if not other.floating and other.at.x >= window.at.x + window.size.x then
			return false
		end
	end
	return true
end

--- Directional window move that also carries a window into the sidebar (right
--- from the rightmost position) and out of it (left).
---@param direction "left"|"right"|"up"|"down"
function M.move(direction)
	local window = hl.get_active_window()
	if window and M.is_docked(window) then
		if direction == "left" then
			ask("remove", window.address)
		end
	elseif window and direction == "right" and rightmost(window) then
		ask("add", window.address, window.monitor.name)
	else
		hl.dispatch(hl.dsp.window.move({ direction = direction, group_aware = true }))
	end
end

--- Move the focused window to another monitor; a docked one goes into the
--- sidebar there.
---@param offset 1|-1
function M.move_to_monitor(offset)
	local window = hl.get_active_window()
	if not (window and M.is_docked(window)) then
		hl.dispatch(hl.dsp.window.move({ monitor = offset > 0 and "+1" or "-1" }))
		return
	end
	local monitors = hl.get_monitors()
	for i, monitor in ipairs(monitors) do
		if window.monitor and monitor.name == window.monitor.name then
			local target = monitors[(i - 1 + offset) % #monitors + 1]
			if target.name ~= monitor.name then
				ask("add", window.address, target.name)
			end
			return
		end
	end
end

--- Step through the tabs of the sidebar while its window is focused, and
--- through the windows of a group otherwise.
---@param offset 1|-1
function M.cycle(offset)
	local window = hl.get_active_window()
	if window and window.monitor and M.is_docked(window) then
		ask("cycle", window.monitor.name, offset)
	else
		hl.dispatch(offset > 0 and hl.dsp.group.next() or hl.dsp.group.prev())
	end
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
