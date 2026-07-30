-- ##############################################################################
-- Hotkeys
-- ##############################################################################

local mainMod = "SUPER"

-- Default programs
local terminal = "kitty"
local fileManager = "kitty yazi"
local guiFileManager = "nautilus"
local menu = "rofi"

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
bindp(mainMod .. " + SHIFT + V", hl.dsp.window.pin())
bindp(mainMod .. " + SUPER_L", hl.dsp.exec_cmd("pkill " .. menu .. " || " .. menu .. " -show drun"), { release = true })
-- bindp(mainMod .. " + W", hl.dsp.layout("togglesplit")) -- dwindle
bindp(mainMod .. " + G", hl.dsp.group.toggle())
bindp(mainMod .. " + SHIFT + G", hl.dsp.group.lock_active({ action = "toggle" }))
bindp(mainMod .. " + bracketleft", hl.dsp.group.prev())
bindp(mainMod .. " + bracketright", hl.dsp.group.next())
bindp(mainMod .. " + SHIFT + bracketleft", hl.dsp.group.move_window({ forward = false }))
bindp(mainMod .. " + SHIFT + bracketright", hl.dsp.group.move_window({ forward = true }))
bindp("f11", hl.dsp.window.fullscreen())
bindp(mainMod .. " + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/workspace_reassign.sh"))
bindp(mainMod .. " + N", hl.dsp.exec_cmd('~/.config/hypr/scripts/toggle_vpn.sh "Personal DE"'))
bindp(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd('~/.config/hypr/scripts/toggle_vpn.sh "Personal US"'))
bindp(mainMod .. " + ALT + N", hl.dsp.exec_cmd('~/.config/hypr/scripts/toggle_vpn.sh "Personal RU"'))
bindp(mainMod .. " + D", hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle_dnd.sh"))
bindp(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd("makoctl dismiss -a"))
bindp(mainMod .. " + Tab", hl.dsp.exec_cmd("~/.config/hypr/scripts/jaeger/jaeger.sh toggle"))
for i = 1, 9 do
	bindp(mainMod .. " + ALT + " .. i, hl.dsp.exec_cmd("~/.config/hypr/scripts/jaeger/goto.sh " .. i))
end

-- Screenshots and screencasts
-- Area captures go through the vendored grimblast-sharp: stock `grim -g` blurs
-- free-region shots on fractionally scaled outputs (crops from the raw buffer
-- instead). Window/output captures are already pixel-perfect with stock grimblast.
bindp("Print", hl.dsp.exec_cmd("~/.config/hypr/scripts/grimblast-sharp --notify --freeze copy area"))
bindp("SHIFT + Print", hl.dsp.exec_cmd("grimblast --notify --cursor copy output"))
bindp(mainMod .. " + P", hl.dsp.exec_cmd("~/.config/hypr/scripts/grimblast-sharp --notify --freeze copy area"))
bindp(mainMod .. " + CTRL + P", hl.dsp.exec_cmd("grimblast --notify --cursor copy active"))
bindp(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("grimblast --notify --cursor copy output"))
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
bindp("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"))
bindp("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"))
bindp("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"))
bindp(mainMod .. " + SHIFT + f23", hl.dsp.exec_cmd('zen-browser --new-window "https://t3.chat"'))

-- Move focus with mainMod + arrow keys
bindp(mainMod .. " + h", hl.dsp.focus({ direction = "left" }))
bindp(mainMod .. " + l", hl.dsp.focus({ direction = "right" }))
bindp(mainMod .. " + k", hl.dsp.focus({ direction = "up" }))
bindp(mainMod .. " + j", hl.dsp.focus({ direction = "down" }))
bindp(mainMod .. " + SHIFT + h", hl.dsp.window.move({ direction = "left", group_aware = true }))
bindp(mainMod .. " + SHIFT + l", hl.dsp.window.move({ direction = "right", group_aware = true }))
bindp(mainMod .. " + SHIFT + k", hl.dsp.window.move({ direction = "up", group_aware = true }))
bindp(mainMod .. " + SHIFT + j", hl.dsp.window.move({ direction = "down", group_aware = true }))
bindp(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
bindp(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
bindp(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
bindp(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))
bindp(mainMod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left", group_aware = true }))
bindp(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right", group_aware = true }))
bindp(mainMod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up", group_aware = true }))
bindp(mainMod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down", group_aware = true }))

-- Switch workspaces with mainMod + [1-9]
-- Move active window to a workspace with mainMod + SHIFT + [1-9]
local navigate = "~/.config/hypr/scripts/navigate.sh"
for i = 1, 9 do
	bindp(mainMod .. " + " .. i, hl.dsp.exec_cmd(navigate .. " workspace " .. i .. " false"))
	bindp(mainMod .. " + CTRL + " .. i, hl.dsp.exec_cmd(navigate .. " workspace " .. i .. " true"))
	bindp(mainMod .. " + SHIFT + " .. i, hl.dsp.exec_cmd(navigate .. " movetoworkspace " .. i .. " false"))
	bindp(mainMod .. " + CTRL + SHIFT + " .. i, hl.dsp.exec_cmd(navigate .. " movetoworkspace " .. i .. " true"))
end

bindp(mainMod .. " + 0", hl.dsp.exec_cmd('notify-send "Copied hex value: $(hyprpicker -a)"'))

-- Special workspaces
bindp(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
bindp(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))
bindp(mainMod .. " + C", hl.dsp.workspace.toggle_special("config"))
bindp(mainMod .. " + SHIFT + C", hl.dsp.window.move({ workspace = "special:config" }))
bindp(mainMod .. " + M", hl.dsp.workspace.toggle_special("monorepo_fleetcraft"))
bindp(mainMod .. " + SHIFT + M", hl.dsp.window.move({ workspace = "special:monorepo_fleetcraft" }))
bindp(mainMod .. " + CTRL + M", hl.dsp.workspace.toggle_special("monorepo_aino"))
bindp(mainMod .. " + CTRL + SHIFT + M", hl.dsp.window.move({ workspace = "special:monorepo_aino" }))

-- Scroll through existing workspaces
bindp(mainMod .. " + CTRL + l", hl.dsp.focus({ workspace = "+1" }))
bindp(mainMod .. " + CTRL + h", hl.dsp.focus({ workspace = "-1" }))
bindp(mainMod .. " + CTRL + SHIFT + l", hl.dsp.window.move({ workspace = "+1" }))
bindp(mainMod .. " + CTRL + SHIFT + h", hl.dsp.window.move({ workspace = "-1" }))
bindp(mainMod .. " + CTRL + right", hl.dsp.focus({ workspace = "+1" }))
bindp(mainMod .. " + CTRL + left", hl.dsp.focus({ workspace = "-1" }))
bindp(mainMod .. " + CTRL + SHIFT + right", hl.dsp.window.move({ workspace = "+1" }))
bindp(mainMod .. " + CTRL + SHIFT + left", hl.dsp.window.move({ workspace = "-1" }))

-- Scroll through existing monitors
bindp(mainMod .. " + CTRL + k", hl.dsp.focus({ monitor = "+1" }))
bindp(mainMod .. " + CTRL + j", hl.dsp.focus({ monitor = "-1" }))
bindp(mainMod .. " + CTRL + SHIFT + k", hl.dsp.window.move({ monitor = "+1" }))
bindp(mainMod .. " + CTRL + SHIFT + j", hl.dsp.window.move({ monitor = "-1" }))
bindp(mainMod .. " + CTRL + up", hl.dsp.focus({ monitor = "+1" }))
bindp(mainMod .. " + CTRL + down", hl.dsp.focus({ monitor = "-1" }))
bindp(mainMod .. " + CTRL + SHIFT + up", hl.dsp.window.move({ monitor = "+1" }))
bindp(mainMod .. " + CTRL + SHIFT + down", hl.dsp.window.move({ monitor = "-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
bindp(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
bindp(mainMod .. " + ALT + mouse:272", hl.dsp.window.resize(), { mouse = true })
