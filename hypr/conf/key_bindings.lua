-- ##############################################################################
-- Hotkeys
-- ##############################################################################

local roles = require("conf/roles")
local sidebar = require("conf/sidebar")

local mainMod = "SUPER"

-- Default programs
local terminal = "kitty"
local fileManager = "kitty yazi"
local guiFileManager = "nautilus"
local menu = "rofi"

-- A window docked as a sidebar stays put: binds that would move or resize it
-- do nothing while it is focused (see conf/sidebar.lua)
local unless_docked = sidebar.unless_docked

-- Equivalent of the old `bindp`: bypasses app requests to inhibit keybinds
local function bindp(keys, dispatcher, opts)
	opts = opts or {}
	opts.dont_inhibit = true
	return hl.bind(keys, dispatcher, opts)
end

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
bindp(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
bindp(mainMod .. " + Q", hl.dsp.window.close())
bindp(mainMod .. " + SHIFT + F", hl.dsp.exec_cmd(fileManager))
bindp(mainMod .. " + F", hl.dsp.exec_cmd(guiFileManager))
bindp(mainMod .. " + B", hl.dsp.exec_cmd("zen-browser"))
bindp(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("zen-browser --private-window"))
bindp(mainMod .. " + ALT + B", hl.dsp.exec_cmd("chromium"))
bindp(mainMod .. " + escape", hl.dsp.exec_cmd("hyprlock"))
bindp(mainMod .. " + SHIFT + escape", hl.dsp.exec_cmd("pkill wlogout || wlogout"))
bindp(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
bindp(mainMod .. " + SHIFT + V", unless_docked(hl.dsp.window.pin()))
-- Open / close the sidebar; put the focused window into it / take it out
-- (quickshell/Sidebar.qml)
bindp(mainMod .. " + backslash", sidebar.toggle)
bindp(mainMod .. " + SHIFT + backslash", sidebar.toggle_window)
bindp(
	mainMod .. " + SUPER_L",
	hl.dsp.exec_cmd("pkill " .. menu .. " || { ~/.config/rofi/scan-projects.sh; " .. menu .. " -show drun; }"),
	{ release = true }
)
-- bindp(mainMod .. " + W", hl.dsp.layout("togglesplit")) -- dwindle
bindp(mainMod .. " + G", hl.dsp.group.toggle())
bindp(mainMod .. " + SHIFT + G", hl.dsp.group.lock_active({ action = "toggle" }))
-- Also steps through the tabs of the sidebar
bindp(mainMod .. " + bracketleft", function()
	sidebar.cycle(-1)
end)
bindp(mainMod .. " + bracketright", function()
	sidebar.cycle(1)
end)
bindp(mainMod .. " + SHIFT + bracketleft", hl.dsp.group.move_window({ forward = false }))
bindp(mainMod .. " + SHIFT + bracketright", hl.dsp.group.move_window({ forward = true }))
bindp("f11", hl.dsp.window.fullscreen())
bindp(mainMod .. " + R", function()
	roles.reassign_workspaces()
end)
bindp(mainMod .. " + N", hl.dsp.exec_cmd('~/.config/hypr/scripts/toggle_vpn.sh "Personal DE"'))
bindp(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd('~/.config/hypr/scripts/toggle_vpn.sh "Personal RU"'))
bindp(mainMod .. " + D", hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle_dnd.sh"))
bindp(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd("makoctl dismiss -a"))
bindp(mainMod .. " + Tab", hl.dsp.exec_cmd("~/.config/hypr/scripts/jaeger/jaeger.sh one"))
bindp(mainMod .. " + SHIFT + Tab", hl.dsp.exec_cmd("~/.config/hypr/scripts/jaeger/jaeger.sh all"))
for i = 1, 9 do
	bindp(mainMod .. " + ALT + " .. i, hl.dsp.exec_cmd("~/.config/hypr/scripts/jaeger/goto.sh " .. i))
end

-- Screenshots and screencasts
-- Area captures go through the vendored grimblast-sharp: stock `grim -g` blurs
-- free-region shots on fractionally scaled outputs (crops from the raw buffer
-- instead). Window/output captures are already pixel-perfect with stock grimblast.
-- Every capture is `copysave`: copied to the clipboard AND written to $shotDir.
local shotDir = "$HOME/Pictures/Screenshots"
local shot = "mkdir -p " .. shotDir .. " && XDG_SCREENSHOTS_DIR=" .. shotDir .. " "
bindp("Print", hl.dsp.exec_cmd(shot .. "~/.config/hypr/scripts/grimblast-sharp --notify --freeze copysave area"))
bindp("SHIFT + Print", hl.dsp.exec_cmd(shot .. "grimblast --notify --cursor copysave output"))
bindp(
	mainMod .. " + P",
	hl.dsp.exec_cmd(shot .. "~/.config/hypr/scripts/grimblast-sharp --notify --freeze copysave area")
)
bindp(mainMod .. " + CTRL + P", hl.dsp.exec_cmd(shot .. "grimblast --notify --cursor copysave active"))
bindp(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd(shot .. "grimblast --notify --cursor copysave output"))
bindp(mainMod .. " + ALT + P", hl.dsp.exec_cmd("pkill kooha || kooha"))
bindp(mainMod .. " + A", hl.dsp.exec_cmd("pkill swappy || ~/.config/hypr/scripts/image-annotation.sh"))

-- Special Keys
bindp("xf86monbrightnessup", function()
	hl.dispatch(hl.dsp.dpms({ action = "enable" }))
	hl.dispatch(hl.dsp.exec_cmd("brightnessctl set 10%+"))
end)
bindp("xf86monbrightnessdown", hl.dsp.exec_cmd("brightnessctl set 10%-"))
bindp("code:123", hl.dsp.exec_cmd("~/.config/hypr/scripts/volume.sh up"), { locked = true, repeating = true })
bindp("code:122", hl.dsp.exec_cmd("~/.config/hypr/scripts/volume.sh down"), { locked = true, repeating = true })
bindp("xf86audiomute", hl.dsp.exec_cmd("~/.config/hypr/scripts/volume.sh toggle"), { locked = true })
bindp("xf86audiomicmute", hl.dsp.exec_cmd("~/.config/hypr/scripts/volume.sh mic"), { locked = true })
bindp("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"))
bindp("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"))
bindp("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"))
bindp(mainMod .. " + SHIFT + f23", hl.dsp.exec_cmd('zen-browser --new-window "https://claude.ai/new"'))

-- Move focus with mainMod + arrow keys
-- Goes through conf/sidebar.lua so that a docked window can be reached too
local function focus(direction)
	return function()
		sidebar.focus(direction)
	end
end
-- Moving goes through it as well: right from the rightmost position takes a
-- window into the sidebar, left takes it out
local function move(direction)
	return function()
		sidebar.move(direction)
	end
end
bindp(mainMod .. " + h", focus("left"))
bindp(mainMod .. " + l", focus("right"))
bindp(mainMod .. " + k", focus("up"))
bindp(mainMod .. " + j", focus("down"))
bindp(mainMod .. " + SHIFT + h", move("left"))
bindp(mainMod .. " + SHIFT + l", move("right"))
bindp(mainMod .. " + SHIFT + k", move("up"))
bindp(mainMod .. " + SHIFT + j", move("down"))
bindp(mainMod .. " + left", focus("left"))
bindp(mainMod .. " + right", focus("right"))
bindp(mainMod .. " + up", focus("up"))
bindp(mainMod .. " + down", focus("down"))
bindp(mainMod .. " + SHIFT + left", move("left"))
bindp(mainMod .. " + SHIFT + right", move("right"))
bindp(mainMod .. " + SHIFT + up", move("up"))
bindp(mainMod .. " + SHIFT + down", move("down"))

-- Switch workspaces with mainMod + [1-9]
-- Move active window to a workspace with mainMod + SHIFT + [1-9]
local navigate = "~/.config/hypr/scripts/navigate.sh"
for i = 1, 9 do
	bindp(mainMod .. " + " .. i, hl.dsp.exec_cmd(navigate .. " workspace " .. i .. " false"))
	bindp(mainMod .. " + CTRL + " .. i, hl.dsp.exec_cmd(navigate .. " workspace " .. i .. " true"))
	bindp(mainMod .. " + SHIFT + " .. i, unless_docked(hl.dsp.exec_cmd(navigate .. " movetoworkspace " .. i .. " false")))
	bindp(mainMod .. " + CTRL + SHIFT + " .. i, unless_docked(hl.dsp.exec_cmd(navigate .. " movetoworkspace " .. i .. " true")))
end

bindp(mainMod .. " + 0", hl.dsp.exec_cmd('notify-send "Copied hex value: $(hyprpicker -a)"'))

-- Special workspaces
bindp(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
bindp(mainMod .. " + SHIFT + S", unless_docked(hl.dsp.window.move({ workspace = "special:magic" })))
bindp(mainMod .. " + C", hl.dsp.workspace.toggle_special("config"))
bindp(mainMod .. " + SHIFT + C", unless_docked(hl.dsp.window.move({ workspace = "special:config" })))

-- Scroll through existing workspaces
bindp(mainMod .. " + CTRL + l", hl.dsp.focus({ workspace = "+1" }))
bindp(mainMod .. " + CTRL + h", hl.dsp.focus({ workspace = "-1" }))
bindp(mainMod .. " + CTRL + SHIFT + l", unless_docked(hl.dsp.window.move({ workspace = "+1" })))
bindp(mainMod .. " + CTRL + SHIFT + h", unless_docked(hl.dsp.window.move({ workspace = "-1" })))
bindp(mainMod .. " + CTRL + right", hl.dsp.focus({ workspace = "+1" }))
bindp(mainMod .. " + CTRL + left", hl.dsp.focus({ workspace = "-1" }))
bindp(mainMod .. " + CTRL + SHIFT + right", unless_docked(hl.dsp.window.move({ workspace = "+1" })))
bindp(mainMod .. " + CTRL + SHIFT + left", unless_docked(hl.dsp.window.move({ workspace = "-1" })))

-- Scroll through existing monitors
-- A docked window moves into the sidebar of the other monitor
local function to_monitor(offset)
	return function()
		sidebar.move_to_monitor(offset)
	end
end
bindp(mainMod .. " + CTRL + k", hl.dsp.focus({ monitor = "+1" }))
bindp(mainMod .. " + CTRL + j", hl.dsp.focus({ monitor = "-1" }))
bindp(mainMod .. " + CTRL + SHIFT + k", to_monitor(1))
bindp(mainMod .. " + CTRL + SHIFT + j", to_monitor(-1))
bindp(mainMod .. " + CTRL + up", hl.dsp.focus({ monitor = "+1" }))
bindp(mainMod .. " + CTRL + down", hl.dsp.focus({ monitor = "-1" }))
bindp(mainMod .. " + CTRL + SHIFT + up", to_monitor(1))
bindp(mainMod .. " + CTRL + SHIFT + down", to_monitor(-1))

-- Move/resize windows with mainMod + LMB/RMB and dragging
-- Dropped on an open sidebar a window goes into it, and a docked one dragged
-- out leaves it
bindp(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
bindp(mainMod .. " + mouse:272", sidebar.grab)
-- Whatever is held by then: the button may well outlast the modifier
bindp("mouse:272", sidebar.drop, { release = true, ignore_mods = true, non_consuming = true })
bindp(mainMod .. " + ALT + mouse:272", unless_docked(hl.dsp.window.resize()), { mouse = true })
