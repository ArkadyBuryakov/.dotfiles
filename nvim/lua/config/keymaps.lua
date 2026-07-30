-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local map = vim.keymap.set
map("x", "<leader>p", '"_dP', { desc = "Paste without replacing registry" })

-- Toggle numbers group (<leader>n)
map("n", "<leader>nn", function()
  if vim.opt_local.number:get() then
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
  else
    vim.opt_local.number = true
  end
end, { desc = "Toggle line numbers" })

map("n", "<leader>nr", function()
  if not vim.opt_local.number:get() then
    vim.opt_local.number = true
    vim.opt_local.relativenumber = true
  else
    vim.opt_local.relativenumber = not vim.opt_local.relativenumber:get()
  end
end, { desc = "Toggle relative numbers" })

-- JSON operations (<leader>j) — run a processor over the visual selection (charwise-aware,
-- so mid-line selections work), or the whole buffer in normal mode.

-- Recursively unwrap string values that are themselves a valid JSON object/array, or a
-- Python literal (repr) of a dict/list/tuple — converting them into real JSON. Scalar
-- strings (e.g. "123", "true", "hello") are left untouched. ast.literal_eval is safe:
-- it parses literals only and never executes code.
local json_python = [[
import sys, json, ast

def parse(s):
    try:
        return json.loads(s)
    except Exception:
        pass
    try:
        return ast.literal_eval(s)
    except Exception:
        return None

def deep(v):
    if isinstance(v, str):
        p = parse(v)
        if isinstance(p, (dict, list, tuple, set)):
            return deep(p)
        return v
    if isinstance(v, dict):
        return {k: deep(x) for k, x in v.items()}
    if isinstance(v, (list, tuple, set)):
        return [deep(x) for x in v]
    return v

data = sys.stdin.read()
root = parse(data)
if root is None:
    sys.stderr.write("not valid JSON or a Python literal\n")
    sys.exit(1)
json.dump(deep(root), sys.stdout, indent=2, ensure_ascii=False)
]]

local function run_jq(input, program, opts)
  local cmd = { "jq" }
  if opts.compact then
    table.insert(cmd, "-c")
  else
    vim.list_extend(cmd, { "--indent", "2" })
  end
  table.insert(cmd, program or ".")

  local res = vim.system(cmd, { stdin = input, text = true }):wait()
  if res.code ~= 0 then
    vim.notify("json: " .. vim.trim(res.stderr or "jq failed"), vim.log.levels.ERROR)
    return nil
  end
  return vim.split(vim.trim(res.stdout or ""), "\n")
end

local function run_python(input)
  local res = vim.system({ "python3", "-c", json_python }, { stdin = input, text = true }):wait()
  if res.code ~= 0 then
    vim.notify("json: " .. vim.trim(res.stderr or "python failed"), vim.log.levels.ERROR)
    return nil
  end
  return vim.split(vim.trim(res.stdout or ""), "\n")
end

local function json_op(processor)
  local mode = vim.fn.mode()
  local charwise = mode == "v"
  if mode == "v" or mode == "V" or mode == "\22" then
    vim.cmd("normal! \27") -- leave visual mode so '< and '> are set
  end

  if charwise then
    -- Character-precise selection: operate on exactly the selected region.
    local p1, p2 = vim.fn.getpos("'<"), vim.fn.getpos("'>")
    local text = table.concat(vim.fn.getregion(p1, p2, { type = "v" }), "\n")
    local out = processor(text)
    if not out then
      return
    end
    local rp = vim.fn.getregionpos(p1, p2, { type = "v" })
    local a, b = rp[1][1], rp[#rp][2]
    vim.api.nvim_buf_set_text(0, a[2] - 1, a[3] - 1, b[2] - 1, b[3], out)
  else
    -- Linewise/blockwise selection uses whole lines; normal mode uses the whole buffer.
    local s, e
    if mode == "V" or mode == "\22" then
      s, e = vim.fn.line("'<"), vim.fn.line("'>")
    else
      s, e = 1, vim.fn.line("$")
    end
    local out = processor(table.concat(vim.api.nvim_buf_get_lines(0, s - 1, e, false), "\n"))
    if not out then
      return
    end
    vim.api.nvim_buf_set_lines(0, s - 1, e, false, out)
  end
end

map({ "n", "x" }, "<leader>jc", function()
  json_op(function(text)
    return run_jq(text, ".", { compact = true })
  end)
end, { desc = "Compact JSON" })

map({ "n", "x" }, "<leader>jj", function()
  json_op(function(text)
    return run_jq(text, ".", {})
  end)
end, { desc = "Format JSON" })

map({ "n", "x" }, "<leader>jJ", function()
  json_op(run_python)
end, { desc = "Format JSON (unwrap nested JSON/Python strings)" })
