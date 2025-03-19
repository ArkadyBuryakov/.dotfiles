return {
  {
    "michaelrommel/nvim-silicon",
    lazy = true,
    cmd = "Silicon",
    init = function()
      local wk = require("which-key")
      wk.add({
        { "<leader>cs", ":Silicon<CR>", desc = "Code snapshot", mode = "v" },
      })
    end,
    config = function()
      require("silicon").setup({
        font = "JetBrainsMono Nerd Font=34;Noto Color Emoji=34",
        theme = "One Dark",
        background = "#EEEDEE",
        window_title = function()
          local workdir = vim.fn.getcwd()
          local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()), "")
          return vim.fn.substitute(path, workdir .. "/", "", "")
        end,
        output = function()
          return "~/Pictures/Screenshots/" .. os.date("%Y-%m-%d-%H-%M-%S") .. "_code.png"
        end,
        to_clipboard = true,
        line_offset = function(args)
          return args.line1
        end,
      })
    end,
  },
}
