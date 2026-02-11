-- sigil.nvim - Prettify symbols for Neovim
-- Main module

local M = {}

M._initialized = false

---Setup sigil with user configuration
---@param opts? sigil.Config
function M.setup(opts)
	if M._initialized and (opts == nil or vim.tbl_isempty(opts)) then
		return
	end

	-- Setup config
	local config = require("sigil.config")
	config.setup(opts)

	-- Define default highlight group (linked to Special, users can override)
	vim.api.nvim_set_hl(0, "SigilSymbol", { default = true, link = "Special" })

	M._initialized = true

	-- Initialize manager (autocmds, attach to buffers)
	if config.current.enabled then
		local manager = require("sigil.manager")
		manager.init()
	end
end

---Enable prettify-symbols for current buffer
---@param buf? integer
function M.enable(buf)
	buf = buf or vim.api.nvim_get_current_buf()

	local state = require("sigil.state")
	local prettify = require("sigil.prettify")
	local manager = require("sigil.manager")

	if not state.is_attached(buf) then
		manager.attach(buf)
	else
		state.enable(buf)
		prettify.prettify_buffer(buf)
	end
end

---Disable prettify-symbols for current buffer
---@param buf? integer
function M.disable(buf)
	buf = buf or vim.api.nvim_get_current_buf()

	local state = require("sigil.state")
	state.disable(buf)
end

---Toggle prettify-symbols for current buffer
---@param buf? integer
function M.toggle(buf)
	buf = buf or vim.api.nvim_get_current_buf()

	local state = require("sigil.state")

	if state.is_enabled(buf) then
		M.disable(buf)
	else
		M.enable(buf)
	end
end

---Refresh current buffer
---@param buf? integer
function M.refresh(buf)
	buf = buf or vim.api.nvim_get_current_buf()

	local prettify = require("sigil.prettify")
	prettify.refresh(buf)
end

---Get current config (read-only access)
---@return sigil.Config
function M.get_config()
	return require("sigil.config").current
end

return M
