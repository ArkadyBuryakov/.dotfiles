return {
  {
    "L3MON4D3/LuaSnip",
    enabled = false,
    -- follow latest release.
    version = "v2.*", -- Replace <CurrentMajor> by the latest released major (first number of latest release)
    -- install jsregexp (optional!).
    build = "make install_jsregexp",
    init = function()
      local ls = require("luasnip")
      local s = ls.snippet
      local i = ls.insert_node
      local fmt = require("luasnip.extras.fmt").fmt

      ls.add_snippets("plantuml", {
        s(
          "uml",
          fmt(
            [[
            @startuml
            skinparam backgroundColor #FEFEFE

            {}

            @enduml
            ]],
            {
              i(0),
            }
          )
        ),
      })
    end,
  },
  {
    "saadparwaiz1/cmp_luasnip",
    enabled = false,
  },
  {
    "hrsh7th/nvim-cmp",
    enabled = false,
    dependencies = { "L3MON4D3/LuaSnip", "saadparwaiz1/cmp_luasnip" },
    opts = function(_, opts)
      table.insert(opts.sources, { name = "luasnip" })
    end,
  },
}
