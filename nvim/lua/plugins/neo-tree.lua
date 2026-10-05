return {

  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      open_files_do_not_replace_types = {
        "dbui",
        "dbout",
      },
      filesystem = {
        filtered_items = {
          -- visible = true,
          show_hidden_count = true,
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_by_name = {
            ".git",
            ".idea",
            "venv",
            ".venv",
            ".ruff_cache",
            "__pycache__",
            ".pytest_cache",
            ".obsidian",
            ".mypy_cache",
            ".db_ui",
          },
          never_show = {},
        },
        window = {
          mappings = {
            ["o"] = "system_open",
            ["O"] = "file_manager_open",
          },
        },
        commands = {
          -- Open directory (or reveal file) in the default GUI file manager
          file_manager_open = function(state)
            local node = state.tree:get_node()
            local method = node.type == "directory" and "ShowFolders" or "ShowItems"
            vim.fn.jobstart({
              "busctl", "--user", "call",
              "org.freedesktop.FileManager1", "/org/freedesktop/FileManager1", "org.freedesktop.FileManager1",
              method, "ass", "1", vim.uri_from_fname(node:get_id()), "",
            }, { detach = true })
          end,
          system_open = function(state)
            local node = state.tree:get_node()
            local path = node:get_id()
            -- If the file has an *drawio extension, open the file in the drawio desktop app
            if path:match("%.drawio$") then
              vim.fn.jobstart({ "drawio", path }, { detach = true })
            else
              vim.fn.jobstart({ "xdg-open", path }, { detach = true })
            end
          end,
        },
      },
    },
  },
}
