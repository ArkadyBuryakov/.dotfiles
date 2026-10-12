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
