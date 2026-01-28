-- sigil.nvim - Buffer lifecycle manager

local config = require("sigil.config")
local state = require("sigil.state")
local prettify = require("sigil.prettify")
local motions = require("sigil.motions")
local visual = require("sigil.visual")

local M = {}

---Augroup for sigil autocmds
M.augroup = vim.api.nvim_create_augroup("Sigil", { clear = true })

---Attach to a buffer
---@param buf integer
function M.attach(buf)
	-- Skip if already attached
	if state.is_attached(buf) then
		return
	end

	-- Check if filetype is enabled
	local ft = vim.bo[buf].filetype
	if not config.is_enabled_for_filetype(ft) then
		return
	end

	-- Skip special buffers
	if vim.bo[buf].buftype ~= "" then
		return
	end

	-- Attach state
	state.attach(buf)

	-- Set conceal options for buffer window(s)
	M.setup_conceal(buf)

	-- Initial prettification (may be incomplete if treesitter not ready)
	prettify.prettify_buffer(buf)

	-- Delayed re-prettify after forcing treesitter parse
	vim.defer_fn(function()
		if vim.api.nvim_buf_is_valid(buf) and state.is_enabled(buf) then
			-- Force treesitter to parse if available
			local ok, parser = pcall(vim.treesitter.get_parser, buf)
			if ok and parser then
				pcall(function()
					parser:parse()
				end)
			end
			prettify.refresh(buf)
		end
	end, 50)

	-- Setup atomic motions if enabled
	if config.current.atomic_motions then
		motions.setup_keymaps(buf)
	end

	-- Setup buffer-local autocmds
	M.setup_buffer_autocmds(buf)
end

---Detach from a buffer
---@param buf integer
function M.detach(buf)
	-- Remove atomic motions keymaps
	if config.current.atomic_motions then
		motions.remove_keymaps(buf)
	end

	-- Clear visual overlays
	visual.clear(buf)

	state.detach(buf)
end

---Setup conceal options for buffer
---@param buf integer
function M.setup_conceal(buf)
	-- Set conceallevel and concealcursor for all windows showing this buffer
	for _, win in ipairs(vim.fn.win_findbuf(buf)) do
		vim.wo[win].conceallevel = 2
		vim.wo[win].concealcursor = config.current.conceal_cursor
	end
end

---Setup buffer-local autocmds
---@param buf integer
function M.setup_buffer_autocmds(buf)
	-- Re-prettify on text change
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = M.augroup,
		buffer = buf,
		callback = function()
			if state.is_enabled(buf) then
				-- For now, refresh entire buffer
				-- TODO: optimize to only update changed lines
				prettify.refresh(buf)
			end
		end,
	})

	-- Cleanup on buffer delete
	vim.api.nvim_create_autocmd("BufDelete", {
		group = M.augroup,
		buffer = buf,
		callback = function()
			M.detach(buf)
		end,
	})

	-- Re-apply conceal when entering window
	vim.api.nvim_create_autocmd("BufWinEnter", {
		group = M.augroup,
		buffer = buf,
		callback = function()
			if state.is_attached(buf) then
				M.setup_conceal(buf)
			end
		end,
	})

	-- Update visual overlays while selecting
	vim.api.nvim_create_autocmd({ "ModeChanged", "CursorMoved" }, {
		group = M.augroup,
		buffer = buf,
		callback = function()
			visual.update(buf)
			-- Maintain desired byte column for vertical motions.
			local cursor = vim.api.nvim_win_get_cursor(0)
			if vim.w.sigil_vert_active then
				vim.w.sigil_vert_active = false
			else
				vim.w.sigil_curswant_disp = motions.get_display_col(buf, cursor[1] - 1, cursor[2])
			end
		end,
	})
end

---Initialize manager (setup global autocmds)
function M.init()
	-- Attach to buffers on FileType
	vim.api.nvim_create_autocmd("FileType", {
		group = M.augroup,
		callback = function(args)
			-- Defer to allow other plugins to set buffer options
			vim.schedule(function()
				if vim.api.nvim_buf_is_valid(args.buf) then
					M.attach(args.buf)
				end
			end)
		end,
	})

	-- Attach to already open buffers
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype ~= "" then
			M.attach(buf)
		end
	end
end

---Disable all buffers
function M.disable_all()
	for buf, _ in pairs(state.buffers) do
		if vim.api.nvim_buf_is_valid(buf) then
			state.disable(buf)
		end
	end
end

---Enable all attached buffers
function M.enable_all()
	for buf, _ in pairs(state.buffers) do
		if vim.api.nvim_buf_is_valid(buf) then
			state.enable(buf)
			prettify.prettify_buffer(buf)
		end
	end
end

return M
