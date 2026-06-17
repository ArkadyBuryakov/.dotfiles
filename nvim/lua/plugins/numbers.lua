return {
  -- Move "Notification History" from <leader>n to <leader>N
  {
    "folke/snacks.nvim",
    -- stylua: ignore
    keys = {
      { "<leader>n", false },
      { "<leader>N", function()
        if Snacks.config.picker and Snacks.config.picker.enabled then
          Snacks.picker.notifications()
        else
          Snacks.notifier.show_history()
        end
      end, desc = "Notification History" },
    },
  },
  -- Register the <leader>n group label
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>n", group = "Toggle numbers", icon = "" },
      },
    },
  },
}
