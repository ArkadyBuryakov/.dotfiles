-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
--fuzzy.prebuilt_binaries.force_version = true

vim.api.nvim_create_autocmd({ "UIEnter", "ColorScheme" }, {
  callback = function()
    local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
    if not normal.bg then
      return
    end
    io.write(string.format("\027]11;#%06x\027\\", normal.bg))
  end,
})

vim.api.nvim_create_autocmd("UILeave", {
  callback = function()
    io.write("\027]111\027\\")
  end,
})

vim.lsp.config["basedpyright"] = {
  settings = {
    basedpyright = {
      analysis = {
        typeCheckingMode = "basic",
        diagnosticMode = "workspace",
        diagnosticSeverityOverrides = {
          reportArgumentType = false,
          reportAssignmentType = false,
          reportAttributeAccessIssue = false,
          reportCallIssue = false,
          reportGeneralTypeIssues = false,
          reportIndexIssue = "warning",
          reportMissingImports = true,
          reportOptionalMemberAccess = false,
          reportOptionalOperand = "information",
          reportOptionalSubscript = false,
          reportReturnType = "information",
          reportUnusedCallResult = false,
          reportUnusedCouroutine = false,
          strictDictionaryInference = false,
          strictListInference = false,
          strictParameterNoneValue = false,
          strictSetInference = false,
        },
      },
    },
  },
}
