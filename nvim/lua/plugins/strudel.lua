return {
  "gruvw/strudel.nvim",
  build = "npm install",
  config = function()
    require("strudel").setup({
      -- Strudel web user interface related options
      ui = {
        -- Maximise the menu panel
        -- (optional, default: true)
        maximise_menu_panel = false,
        -- Hide the Strudel menu panel (and handle)
        -- (optional, default: false)
        hide_menu_panel = false,
        -- Hide the default Strudel top bar (controls)
        -- (optional, default: false)
        hide_top_bar = false,
        -- Hide the Strudel code editor
        -- (optional, default: false)
        hide_code_editor = false,
        -- Hide the Strudel eval error display under the editor
        -- (optional, default: false)
        hide_error_display = false,
      },
      -- Set to `true` to automatically trigger the code evaluation after saving the buffer content
      -- Only works if the playback was already started (doesn't start the playback on save)
      -- (optional, default: false)
      update_on_save = true,
      -- Enable two-way cursor position sync between Neovim and Strudel editor.
      -- (optional, default: true)
      sync_cursor = true,
      -- Report evaluation errors from Strudel as Neovim notifications.
      -- (optional, default: true)
      report_eval_errors = true,
      -- Path to a custom CSS file to style the Strudel web editor (base64-encoded and injected at launch).
      -- This allows you to override or extend the default Strudel UI appearance.
      -- (optional, default: nil)
      -- custom_css_file = "/path/to/your/custom.css",
      -- Headless mode: set to `true` to run the browser without launching a window
      -- (optional, default: false)
      headless = false,
      -- Path to the directory where Strudel browser user data (cookies, sessions, etc.) is stored
      -- (optional, default: `~/.cache/strudel-nvim/`)
      browser_data_dir = "~/.cache/strudel-nvim/",
      -- Absolute path to a (chromium based) browser executable of choice
      -- (optional, default: nil)
      browser_exec_path = "/usr/bin/chromium",
    })
  end,
}
