-- Determine the repo's default branch (origin/HEAD, falling back to main/master).
local function default_branch()
  local ref = vim.fn.systemlist({ "git", "symbolic-ref", "--short", "refs/remotes/origin/HEAD" })[1]
  if vim.v.shell_error == 0 and ref and ref ~= "" then
    return ref:gsub("^origin/", "")
  end
  for _, b in ipairs({ "main", "master" }) do
    vim.fn.system({ "git", "rev-parse", "--verify", "--quiet", b })
    if vim.v.shell_error == 0 then
      return b
    end
  end
  return "main"
end

-- Review the current branch's history that diverged from the default branch.
local function review_branch()
  local base = default_branch()
  vim.cmd("DiffviewOpen " .. base .. "...HEAD --imply-local")
end

-- Pick a branch (fuzzy-filterable) and diff the working tree against it.
local function diff_against_branch()
  local branches = vim.fn.systemlist({
    "git",
    "for-each-ref",
    "--format=%(refname:short)",
    "--sort=-committerdate",
    "refs/heads",
    "refs/remotes",
  })
  if vim.v.shell_error ~= 0 then
    vim.notify("Not a git repository", vim.log.levels.ERROR)
    return
  end
  branches = vim.tbl_filter(function(b)
    return b ~= "" and not b:find("HEAD")
  end, branches)
  vim.ui.select(branches, { prompt = "Diff against branch:" }, function(choice)
    if choice then
      vim.cmd("DiffviewOpen " .. choice)
    end
  end)
end

-- Pick a commit (fuzzy-filterable) and diff the working tree against it.
local function diff_against_commit()
  local commits = vim.fn.systemlist({ "git", "log", "--oneline", "--no-decorate", "-n", "200" })
  if vim.v.shell_error ~= 0 then
    vim.notify("Not a git repository", vim.log.levels.ERROR)
    return
  end
  vim.ui.select(commits, { prompt = "Diff against commit:" }, function(choice)
    if choice then
      local hash = choice:match("^(%x+)")
      if hash then
        vim.cmd("DiffviewOpen " .. hash)
      end
    end
  end)
end

return {
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewToggleFiles",
      "DiffviewFocusFiles",
      "DiffviewRefresh",
      "DiffviewFileHistory",
    },
    -- stylua: ignore
    keys = {
      { "<leader>gdd", "<cmd>DiffviewOpen<cr>", desc = "Open diff view" },
      { "<leader>gdr", review_branch, desc = "Review branch diff (vs. main)" },
      { "<leader>gdb", diff_against_branch, desc = "Diff against branch" },
      { "<leader>gdc", diff_against_commit, desc = "Diff against commit" },
    },
    opts = {},
  },
  -- Register the <leader>gd group label
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>gd", group = "Git diff view", icon = "" },
      },
    },
  },
}
