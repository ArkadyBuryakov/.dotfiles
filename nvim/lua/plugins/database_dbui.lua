return {
  {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = {
      { "tpope/vim-dadbod",                     lazy = true },
      { "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true },
    },
    cmd = {
      "DBUI",
      "DBUIToggle",
      "DBUIAddConnection",
      "DBUIFindBuffer",
    },
    init = function()
      -- Your DBUI configuration
      vim.g.db_ui_save_location = vim.fn.getcwd() .. "/.db_ui"
      vim.g.db_ui_use_nerd_fonts = 1
      vim.g.db_ui_win_position = "right"
      vim.g.db_ui_execute_on_save = 0
      vim.g.db_ui_disable_mappings_sql = 1

      function FindCurrentSql()
        -- Get the current node
        local ts = vim.treesitter
        local node = ts.get_node()
        if node == nil then
          error("No SQL statement found under cursor")
        end

        local parent = node:parent()

        while parent ~= nil and parent:type() ~= "program" do
          node = parent
          parent = node:parent()
        end

        if node:type() ~= "statement" then
          error("No SQL statement found under cursor")
        end
        return node
      end

      function SelectCurrentSql()
        local node = FindCurrentSql()
        local sr, sc, er, ec = node:range()
        vim.fn.setpos("'<", { 0, sr + 1, sc + 1, 0 })
        vim.fn.setpos("'>", { 0, er + 1, ec, 0 })
        vim.cmd("normal! gv")
      end

      function RunCurrentSql()
        local current_pos = vim.api.nvim_win_get_cursor(0)
        local node = FindCurrentSql()
        local text = vim.treesitter.get_node_text(node, 0)
        vim.cmd.DB(text)
        vim.api.nvim_win_set_cursor(0, current_pos)
      end

      function IsDBUI()
        return vim.bo.filetype == "dbui"
      end

      -- Keybindings for DB usage
      local wk = require("which-key")
      wk.add({
        { "<leader>S",  group = "SQL" },
        { "<leader>Ss", RunCurrentSql,         desc = "Run Statement under Cursor" },
        { "<leader>Sv", SelectCurrentSql,      desc = "Select Statement under Cursor" },
        { "<leader>Ss", ":'<,'> DB<CR>",       desc = "Run Selected",                 mode = "v" },
        { "<leader>Sa", ":%DB<CR>",            desc = "Run All Queries",              mode = { "n", "v" } },
        { "<leader>Sc", ":DBUIFindBuffer<CR>", desc = "Connect to DataBase",          mode = { "n", "v" } },
      })
    end,
  },
  { -- optional saghen/blink.cmp completion source
    "saghen/blink.cmp",
    version = "1.*",
    opts = {
      sources = {
        -- add vim-dadbod-completion to your completion providers
        default = { "lsp", "path", "snippets", "buffer", "dadbod" },
        providers = {
          dadbod = { name = "Dadbod", module = "vim_dadbod_completion.blink" },
        },
      },
    },
  },
}
