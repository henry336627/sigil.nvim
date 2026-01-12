-- sigil.nvim - Prettify symbols for Neovim
-- Entry point

if vim.g.loaded_sigil then
  return
end
vim.g.loaded_sigil = true

-- Defer setup to allow lazy loading
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  once = true,
  callback = function()
    if vim.g.sigil_config then
      require("sigil").setup(vim.g.sigil_config)
    end
  end,
})

-- Commands
vim.api.nvim_create_user_command("Sigil", function()
  require("sigil").toggle()
end, { desc = "Toggle sigil prettify-symbols" })

vim.api.nvim_create_user_command("SigilEnable", function()
  require("sigil").enable()
end, { desc = "Enable sigil prettify-symbols" })

vim.api.nvim_create_user_command("SigilDisable", function()
  require("sigil").disable()
end, { desc = "Disable sigil prettify-symbols" })
