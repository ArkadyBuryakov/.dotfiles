return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "cpp",
        "python",
        "sql",
      },
    },
  },
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "windwp/nvim-autopairs",
      opts = {},
    },
    opts = function()
      local cmp = require("cmp")
      local cmp_autopairs = require("nvim-autopairs.completion.cmp")
      cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
    end,
  },
}
