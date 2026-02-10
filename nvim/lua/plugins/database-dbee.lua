return {
  {
    "kndndrj/nvim-dbee",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "MattiasMTS/cmp-dbee",
      "saghen/blink.cmp",
    },
    build = function()
      -- Install tries to automatically detect the install method.
      -- if it fails, try calling it with one of these parameters:
      --    "curl", "wget", "bitsadmin", "go"
      require("dbee").install()
      require("blink-cmp").setup({
        sources = {
          default = { "lsp", "path", "snippets", "buffer" },
          per_filetype = {
            -- Dbee
            sql = { "dbee", "buffer" }, -- Add any other source to include here
          },
          providers = {
            dbee = { name = "cmp-dbee", module = "blink.compat.source" },
          },
        },
      })
    end,
    config = function()
      local dbee_project = require("dbee-project")
      dbee_project.setup()
      dbee_project.create_commands()
    end,
  },
}
