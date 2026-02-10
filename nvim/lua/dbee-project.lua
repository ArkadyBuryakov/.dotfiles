-- lua/dbee-project.lua

local M = {}

local dbee_dir_name = ".dbee"
local connections_filename = "connections.json"
local notes_dirname = "notes"

local default_connections = vim.json.encode({
  {
    id = "example",
    name = "local-pg",
    type = "postgres",
    url = "postgres://user:pass@localhost:5432/mydb",
  },
})

--- Find .dbee/ walking up from cwd
local function find_project_root()
  local dir = vim.fn.getcwd()
  while dir ~= "/" do
    if vim.fn.isdirectory(dir .. "/" .. dbee_dir_name) == 1 then
      return dir
    end
    dir = vim.fn.fnamemodify(dir, ":h")
  end
  return nil
end

--- Build the dbee config table for a given project root (or global fallback)
local function build_config(root)
  local sources = require("dbee.sources")
  local opts = {}

  if root then
    local dbee_path = root .. "/" .. dbee_dir_name
    local notes_path = dbee_path .. "/" .. notes_dirname
    local conn_path = dbee_path .. "/" .. connections_filename

    -- ensure notes directory exists before setup
    vim.fn.mkdir(notes_path, "p")

    opts.sources = { sources.FileSource:new(conn_path) }
    opts.editor = { directory = notes_path }
  else
    opts.sources = {
      sources.FileSource:new(vim.fn.stdpath("state") .. "/dbee/persistence.json"),
    }
  end

  return opts, root
end

--- Initialize a .dbee/ project in cwd
function M.init()
  local cwd = vim.fn.getcwd()
  local dbee_path = cwd .. "/" .. dbee_dir_name

  if vim.fn.isdirectory(dbee_path) == 1 then
    vim.notify("dbee: project already exists in " .. dbee_path, vim.log.levels.WARN)
    return
  end

  local notes_path = dbee_path .. "/" .. notes_dirname
  vim.fn.mkdir(notes_path, "p")

  local conn_path = dbee_path .. "/" .. connections_filename
  local f = io.open(conn_path, "w")
  if f then
    f:write(default_connections)
    f:close()
  end

  vim.notify("dbee: initialized project in " .. dbee_path, vim.log.levels.INFO)
end

--- Setup dbee with project-scoped config if available
function M.setup()
  local dbee = require("dbee")
  local root = find_project_root()
  local opts, found_root = build_config(root)

  dbee.setup(opts)

  if found_root then
    vim.notify("dbee: loaded project from " .. found_root .. "/" .. dbee_dir_name, vim.log.levels.INFO)
  end
end

--- Open dbee UI with project config (re-runs setup to pick up current cwd)
function M.open()
  local dbee = require("dbee")

  -- close existing UI if open so setup can re-apply
  if dbee.is_open() then
    dbee.close()
  end

  local root = find_project_root()
  local opts, found_root = build_config(root)
  dbee.setup(opts)

  if found_root then
    vim.notify("dbee: loaded project from " .. found_root .. "/" .. dbee_dir_name, vim.log.levels.INFO)
  end

  dbee.open()
end

--- Register user commands
function M.create_commands()
  vim.api.nvim_create_user_command("DbeeInit", function()
    M.init()
  end, { desc = "Initialize a .dbee project in cwd" })

  vim.api.nvim_create_user_command("DbeeProject", function()
    M.open()
  end, { desc = "Load project dbee config and open UI" })
end

return M
