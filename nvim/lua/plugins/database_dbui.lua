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

      local query_types = { statement = true, subquery = true }
      local hl_ns = vim.api.nvim_create_namespace("sql_query_highlight")

      function FindCurrentSql(callback)
        local node = vim.treesitter.get_node()
        if node == nil then
          error("No SQL statement found under cursor")
        end

        local bufnr = vim.api.nvim_get_current_buf()
        local queries = {}
        while node ~= nil do
          if query_types[node:type()] then
            table.insert(queries, 1, node) -- prepend: biggest first
          end
          node = node:parent()
        end

        if #queries == 0 then
          error("No SQL statement found under cursor")
        end

        if #queries == 1 then
          callback(queries[1])
          return
        end

        local function highlight_node(n)
          vim.api.nvim_buf_clear_namespace(bufnr, hl_ns, 0, -1)
          local sr, sc, er, ec = n:range()
          vim.highlight.range(bufnr, hl_ns, "Visual", { sr, sc }, { er, ec })
        end

        local function format_entry(n)
          local text = vim.treesitter.get_node_text(n, bufnr)
          local first_line
          for line in text:gmatch("[^\n]+") do
            local trimmed = line:match("^%s*(.-)%s*$")
            if trimmed ~= "" and trimmed ~= "(" and trimmed ~= ")" then
              first_line = trimmed
              break
            end
          end
          first_line = first_line or text:gsub("\n", " ")
          if #first_line > 80 then
            first_line = first_line:sub(1, 77) .. "..."
          end
          local line_count = n:end_() - n:start() + 1
          if line_count > 1 then
            return first_line .. " (" .. line_count .. " lines)"
          end
          return first_line
        end

        -- Build display lines
        local lines = {}
        local max_width = 0
        for i, n in ipairs(queries) do
          local line = (i == 1 and "> " or "  ") .. format_entry(n)
          lines[i] = line
          if #line > max_width then max_width = #line end
        end

        -- Create floating window
        local width = math.min(max_width + 2, math.floor(vim.o.columns * 0.8))
        local height = #lines
        local win_opts = {
          relative = "editor",
          row = math.floor(vim.o.lines / 4),
          col = math.floor((vim.o.columns - width) / 2),
          width = width,
          height = height,
          style = "minimal",
          border = "rounded",
          title = " Select SQL query ",
          title_pos = "center",
        }
        local float_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, lines)
        vim.bo[float_buf].modifiable = false
        local float_win = vim.api.nvim_open_win(float_buf, true, win_opts)
        vim.wo[float_win].cursorline = true
        vim.api.nvim_win_set_cursor(float_win, { 1, 0 })

        local selected = 1
        highlight_node(queries[selected])

        local function update_cursor()
          vim.bo[float_buf].modifiable = true
          for i = 1, #lines do
            local prefix = i == selected and "> " or "  "
            lines[i] = prefix .. format_entry(queries[i])
          end
          vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, lines)
          vim.bo[float_buf].modifiable = false
          vim.api.nvim_win_set_cursor(float_win, { selected, 0 })
          highlight_node(queries[selected])
        end

        local function close()
          vim.api.nvim_buf_clear_namespace(bufnr, hl_ns, 0, -1)
          if vim.api.nvim_win_is_valid(float_win) then
            vim.api.nvim_win_close(float_win, true)
          end
          vim.api.nvim_buf_delete(float_buf, { force = true })
        end

        local keymaps = {
          ["j"] = function()
            if selected < #queries then
              selected = selected + 1
              update_cursor()
            end
          end,
          ["k"] = function()
            if selected > 1 then
              selected = selected - 1
              update_cursor()
            end
          end,
          ["<CR>"] = function()
            local choice = queries[selected]
            close()
            callback(choice)
          end,
          ["<Esc>"] = close,
          ["q"] = close,
        }
        keymaps["<C-n>"] = keymaps["j"]
        keymaps["<C-p>"] = keymaps["k"]
        keymaps["<Down>"] = keymaps["j"]
        keymaps["<Up>"] = keymaps["k"]

        for key, fn in pairs(keymaps) do
          vim.keymap.set("n", key, fn, { buffer = float_buf, nowait = true })
        end
      end

      function SelectCurrentSql()
        FindCurrentSql(function(node)
          local sr, sc, er, ec = node:range()
          vim.fn.setpos("'<", { 0, sr + 1, sc + 1, 0 })
          vim.fn.setpos("'>", { 0, er + 1, ec, 0 })
          vim.cmd("normal! gv")
        end)
      end

      function RunCurrentSql()
        local current_pos = vim.api.nvim_win_get_cursor(0)
        FindCurrentSql(function(node)
          local text = vim.treesitter.get_node_text(node, 0)
          vim.cmd.DB(text)
          vim.api.nvim_win_set_cursor(0, current_pos)
        end)
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
        FindCurrentSql(function(node)
          local text = strip_semicolon(vim.treesitter.get_node_text(node, 0))
          export_query("COPY (" .. text .. ") TO STDOUT WITH (FORMAT CSV, HEADER)", {}, "csv")
        end)
      end

      function ExportCurrentSqlJson()
        FindCurrentSql(function(node)
          local text = strip_semicolon(vim.treesitter.get_node_text(node, 0))
          local query = "SELECT jsonb_pretty(jsonb_agg(to_jsonb(t))) FROM (" .. text .. ") t"
          export_query(query, { "--quiet", "-t", "-A" }, "json")
        end)
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
