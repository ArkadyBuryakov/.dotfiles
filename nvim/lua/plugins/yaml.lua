-- YAML files that are really Jinja templates (e.g. Terraform-rendered) get the
-- "yaml.jinja" filetype: yamlls doesn't attach, treesitter parses them as jinja,
-- and the plain text between tags is highlighted as yaml (after/queries/jinja).
vim.filetype.add({
  pattern = {
    [".*%.ya?ml"] = {
      function(_, bufnr)
        for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, 500, false)) do
          if line:find("{[{%%#]") then
            return "yaml.jinja"
          end
        end
      end,
      { priority = 10 }, -- run before the plain .yaml extension match
    },
  },
})
vim.treesitter.language.register("jinja", "yaml.jinja")
vim.treesitter.query.add_predicate("buf-filetype?", function(_, _, source, pred)
  return type(source) == "number" and vim.bo[source].filetype == pred[2]
end, { force = true })

return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "jinja", "jinja_inline" } },
  },
}
