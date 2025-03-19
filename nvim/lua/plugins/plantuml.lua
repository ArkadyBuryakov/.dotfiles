return {
  {
    "https://gitlab.com/itaranto/plantuml.nvim",
    version = "*",
    lazy = true,
    cmd = "PlantUML",
    init = function()
      local wk = require("which-key")
      wk.add({
        { "<leader>p", desc = "PlantUML" },
        { "<leader>pR", ":PlantUMLSave<CR>", desc = "PlantUML Render" },
        { "<leader>pr", ":PlantUMLCustom<CR>", desc = "PlantUML Render" },
      })

      function PlantUMLCustom()
        vim.cmd([[PlantUML]])
        vim.cmd([[silent !plantuml -tsvg "%"]])
      end

      function PlantUMLSave()
        vim.cmd([[silent !plantuml -tsvg "%"]])
      end

      vim.cmd([[ command! PlantUMLCustom :lua PlantUMLCustom()<CR> ]])
      vim.cmd([[ command! PlantUMLSave :lua PlantUMLSave()<CR> ]])
    end,
    config = function()
      require("plantuml").setup({
        renderer = {
          type = "image",
          options = {
            prog = "loupe",
            dark_mode = false,
            format = "svg",
          },
        },
        render_on_write = false,
      })
    end,
  },
  {
    "https://github.com/aklt/plantuml-syntax",
  },
}
