-- ##############################################################################
-- Input configurations
-- ##############################################################################

hl.bind("F13", hl.dsp.exec_cmd("~/.config/hypr/scripts/switch-kb-layout.sh"))
hl.bind("SHIFT + F13", hl.dsp.exec_cmd("~/.config/hypr/scripts/switch-kb-layout.sh 2"))

hl.config({
	input = {
		kb_layout = "us,ru,tr",
		kb_options = "fkeys:basic_13-24",
		numlock_by_default = true,

		follow_mouse = 1,

		touchpad = {
			natural_scroll = true,
		},

		sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.
	},

	gestures = {
		workspace_swipe_touch = true,
		workspace_swipe_use_r = true,
	},

	misc = {
		middle_click_paste = false,
	},
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
