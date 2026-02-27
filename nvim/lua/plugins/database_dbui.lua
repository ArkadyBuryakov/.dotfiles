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

      local function strip_semicolon(sql)
        return sql:gsub(";%s*$", "")
      end

      local function get_visual_selection()
        vim.cmd('noau normal! "vy')
        return vim.fn.getreg("v")
      end

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

      local function export_query(query, psql_flags, ft)
        local url = vim.b.db
        if not url then
          error("No database connection. Use :DBUIFindBuffer to connect first.")
        end
        local cmd = vim.list_extend({ "psql", url }, psql_flags)
        table.insert(cmd, "-c")
        table.insert(cmd, query)
        local result = vim.fn.system(cmd)
        if vim.v.shell_error ~= 0 then
          error("psql error: " .. result)
        end
        vim.cmd("enew")
        local lines = vim.split(result, "\n")
        if lines[#lines] == "" then
          table.remove(lines)
        end
        vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
        vim.bo.buftype = "nofile"
        vim.bo.filetype = ft
      end

      function ExportCurrentSqlCsv()
        local node = FindCurrentSql()
        local text = strip_semicolon(vim.treesitter.get_node_text(node, 0))
        export_query("COPY (" .. text .. ") TO STDOUT WITH (FORMAT CSV, HEADER)", {}, "csv")
      end

      function ExportCurrentSqlJson()
        local node = FindCurrentSql()
        local text = strip_semicolon(vim.treesitter.get_node_text(node, 0))
        local query = "SELECT jsonb_pretty(jsonb_agg(to_jsonb(t))) FROM (" .. text .. ") t"
        export_query(query, { "--quiet", "-t", "-A" }, "json")
      end

      function RunSelectedSql()
        local text = get_visual_selection()
        vim.cmd.DB(text)
      end

      function ExportSelectedSqlCsv()
        local text = strip_semicolon(get_visual_selection())
        export_query("COPY (" .. text .. ") TO STDOUT WITH (FORMAT CSV, HEADER)", {}, "csv")
      end

      function ExportSelectedSqlJson()
        local text = strip_semicolon(get_visual_selection())
        local query = "SELECT jsonb_pretty(jsonb_agg(to_jsonb(t))) FROM (" .. text .. ") t"
        export_query(query, { "--quiet", "-t", "-A" }, "json")
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
        { "<leader>Ss", RunSelectedSql,         desc = "Run Selected",                 mode = "v" },
        { "<leader>Sa", ":%DB<CR>",            desc = "Run All Queries",              mode = { "n", "v" } },
        { "<leader>Sc", ":DBUIFindBuffer<CR>", desc = "Connect to DataBase",          mode = { "n", "v" } },
        { "<leader>Se",  group = "SQL Export" },
        { "<leader>Sec", ExportCurrentSqlCsv,    desc = "Export as CSV" },
        { "<leader>Sej", ExportCurrentSqlJson,  desc = "Export as JSON" },
        { "<leader>Sec", ExportSelectedSqlCsv,  desc = "Export as CSV",  mode = "v" },
        { "<leader>Sej", ExportSelectedSqlJson, desc = "Export as JSON", mode = "v" },
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
