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
