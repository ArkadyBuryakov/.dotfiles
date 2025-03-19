return {
  -- Markdown Preview
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    build = "cd app && npm install",
    init = function()
      vim.g.mkdp_filetypes = { "markdown" }
      vim.g.mkdp_preview_options = {
        disable_filename = 1,
        content_editable = false,
      }
      vim.g.mkdp_highlight_css = vim.fn.expand("~/.config/nvim/lua/plugins/markdown.css")
      vim.g.mkdp_page_title = "${name}"
      vim.g.mkdp_theme = "light"
    end,
    ft = { "markdown" },
  },
}
