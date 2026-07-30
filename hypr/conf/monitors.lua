-- ##############################################################################
-- Monitors settings
-- ##############################################################################

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({ output = "eDP-1", mode = "1920x1200", position = "0x0", scale = 1.066667 }) -- Laptop screen
hl.monitor({ output = "DP-1", mode = "3840x2160", position = "0x-1728", scale = 1.25 }) -- Home 4k screen
-- hl.monitor({ output = "DP-1", mode = "1920x1080", position = "0x-1920", scale = 1 })  -- Stub for external monitor

-- Closing lid behavior
-- trigger when the switch is turning off
hl.bind("switch:off:Lid Switch", function()
	hl.monitor({ output = "eDP-1", mode = "1920x1200", position = "0x0", scale = 1.066667 })
end, { locked = true })
-- trigger when the switch is turning on
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("~/.config/hypr/scripts/lid_switch_on.sh"), { locked = true })
