-- Minimal init for testing sigil.nvim
-- Usage: nvim --headless -u tests/minimal_init.lua

-- Add plenary to runtimepath
local plenary_path = vim.fn.expand("~/.local/share/nvim/lazy/plenary.nvim")
if vim.fn.isdirectory(plenary_path) == 1 then
  vim.opt.runtimepath:append(plenary_path)
end

-- Add sigil to runtimepath (current directory)
vim.opt.runtimepath:prepend(vim.fn.getcwd())

-- Basic settings for testing
vim.o.swapfile = false
vim.o.backup = false
vim.o.writebackup = false

-- Load sigil
vim.cmd("runtime plugin/sigil.lua")
