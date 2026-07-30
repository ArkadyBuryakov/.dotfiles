return {
  -- Register the <leader>j group label (keymaps live in config/keymaps.lua)
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>j", group = "JSON", icon = "" },
      },
    },
  },
}
