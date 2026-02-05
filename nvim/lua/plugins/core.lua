return {
  {
    "navarasu/onedark.nvim",
    opts = {
      style = "darker",
      -- toggle theme style ---
      toggle_style_key = "<leader>Ts", -- keybind to toggle theme style. Leave it nil to disable it, or set it to a string, for example "<leader>ts"
      toggle_style_list = { "light", "darker" }, -- List of styles to toggle between
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "onedark",
    },
  },
  {
    "neovim/nvim-lspconfig", -- TODO: Find out proper way to set config. Now it loads from nvim-lspconfig on start and from vim.lsp.config() on restart
    opts = {
      inlay_hints = { enabled = false },
      servers = {
        basedpyright = {
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
        },
      },
    },
  },
}
