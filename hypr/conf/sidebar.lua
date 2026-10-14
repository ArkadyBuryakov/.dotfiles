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
-- A sidebar sits on either side of its monitor
local OPPOSITE = { left = "right", right = "left" }

local M = {}

-- An empty sidebar looks like the bar: darkened, blurred wallpaper
-- (quickshell/SidebarBackdrop.qml)
hl.layer_rule({
	name = "sidebar rules",
	match = { namespace = "quickshell-dropzone" },

	xray = true,
	blur = true,
})

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
---@param side "left"|"right" side of the monitor the strip is on
---@param strip integer width of the strip
---@param top integer height the tabs take above the window
---@param border integer
---@param focus boolean
function M.show(address, monitor, side, strip, top, border, focus)
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
	local left = side == "left" and m.x or m.x + m.width / m.scale - strip
	local height = m.height / m.scale - m.reserved.top - m.reserved.bottom
	local x, y = math.floor(left + border), math.floor(m.y + m.reserved.top + top + border)
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

---@return "left"|"right"|nil side the sidebar of the monitor is open on
local function open_side(monitor)
	local layer = hl.get_layers({ namespace = NAMESPACE, monitor = monitor })[1]
	if not layer then
		return nil
	end
	-- Narrower than the monitor, so it only touches the edge it is anchored to
	return layer.x <= monitor.x and "left" or "right"
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

--- Whether a window lies wholly further to a side than another one.
---@param side "left"|"right"
local function beyond(window, other, side)
	if side == "left" then
		return window.at.x + window.size.x <= other.at.x
	end
	return window.at.x >= other.at.x + other.size.x
end

--- Whether a tiled window has nowhere further to a side to go but the sidebar.
---@param side "left"|"right"
local function outermost(window, side)
	if window.floating or window.fullscreen ~= 0 or not window.monitor then
		return false
	end
	-- Moving sideways takes it out of the group first
	if window.group and window.group.size > 1 then
		return false
	end
	for _, other in ipairs(neighbours(window.monitor, window)) do
		if not other.floating and beyond(other, window, side) then
			return false
		end
	end
	return true
end

--- Directional window move that also carries a window into the sidebar (from
--- the outermost position, towards the side the sidebar is on) and out of it
--- (the other way). A closed sidebar takes a window from both sides, and
--- opens on the one it came through.
---@param direction "left"|"right"|"up"|"down"
function M.move(direction)
	local window = hl.get_active_window()
	local side = window and window.monitor and open_side(window.monitor)
	if window and M.is_docked(window) then
		if direction == OPPOSITE[side or "right"] then
			ask("remove", window.address)
		end
	elseif window and OPPOSITE[direction] and (not side or side == direction) and outermost(window, direction) then
		ask("add", window.address, window.monitor.name, side and "" or direction)
	else
		hl.dispatch(hl.dsp.window.move({ direction = direction, group_aware = true }))
	end
end

--- Wrap a dispatcher so that on a docked window it moves the sidebar to a
--- side of its monitor instead.
---@param side "left"|"right"
---@param dispatcher HL.Dispatcher
---@return function
function M.to_side(side, dispatcher)
	return function()
		local window = hl.get_active_window()
		if window and window.monitor and M.is_docked(window) then
			ask("side", window.monitor.name, side)
		else
			hl.dispatch(dispatcher)
		end
	end
end

--- Monitor under the cursor, if the cursor is over the strip of its sidebar.
---@return HL.Monitor|nil
local function strip_at_cursor()
	local cursor, monitor = hl.get_cursor_pos(), hl.get_monitor_at_cursor()
	local side = monitor and open_side(monitor)
	if not cursor or not side then
		return nil
	end
	-- The strip is all that is reserved on that side
	local over
	if side == "left" then
		over = cursor.x < monitor.x + monitor.reserved.left
	else
		over = cursor.x >= monitor.x + monitor.width / monitor.scale - monitor.reserved.right
	end
	return over and monitor or nil
end

-- Address of the window a drag started on
local dragged

--- A drag starts: note the window under the cursor.
function M.grab()
	local window, cursor = hl.get_active_window(), hl.get_cursor_pos()
	local over = window
		and cursor
		and cursor.x >= window.at.x
		and cursor.x < window.at.x + window.size.x
		and cursor.y >= window.at.y
		and cursor.y < window.at.y + window.size.y
	dragged = over and window.address or nil
	if not dragged then
		return
	end
	-- The sidebar shows where to drop it
	ask("drag", 1)
	-- Pinned windows are drawn over the others: until the drop (which syncs)
	-- the docked ones are not, to keep the dragged window in view over them
	for _, dock in ipairs(hl.get_windows({ tag = TAG })) do
		if dock.pinned and dock.address ~= dragged then
			hl.dispatch(hl.dsp.window.pin({ window = dock }))
			hl.dispatch(hl.dsp.window.alter_zorder({ mode = "bottom", window = dock }))
		end
	end
end

--- The drag ended: a window dropped on the strip of an open sidebar goes into
--- it, and a docked one dropped anywhere else leaves it.
function M.drop()
	local address = dragged
	dragged = nil
	if not address then
		return
	end
	ask("drag", 0)
	-- Once Hyprland has put the window down itself
	hl.timer(function()
		local window = hl.get_window("address:" .. address)
		local monitor = strip_at_cursor()
		M.sync()
		if window and monitor then
			ask("add", address, monitor.name)
		elseif window and M.is_docked(window) then
			ask("remove", address)
		end
	end, { timeout = 50, type = "oneshot" })
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
	local side = monitor and open_side(monitor) or "right"
	local target

	--- How far a window reaches towards the sidebar
	local function reach(window)
		return side == "left" and -window.at.x or window.at.x + window.size.x
	end

	if dock and active and active.address == dock.address then
		if direction == OPPOSITE[side] then
			-- Out of the sidebar: the window reaching furthest towards it,
			-- the most recently focused one if several do
			for _, window in ipairs(neighbours(monitor, dock)) do
				local edge, best = reach(window), target and reach(target)
				if not target or edge > best or (edge == best and window.focus_history_id < target.focus_history_id) then
					target = window
				end
			end
		end
	elseif dock and direction == side and not (active and active.fullscreen == 2) then
		-- Into the sidebar, unless there still is a window further that way
		target = dock
		for _, window in ipairs(active and neighbours(monitor, dock) or {}) do
			if beyond(window, active, side) then
				target = nil
				break
			end
		end
	end

	hl.dispatch(hl.dsp.focus(target and { window = target } or { direction = direction }))
end

return M
