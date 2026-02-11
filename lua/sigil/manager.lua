-- sigil.nvim - Buffer lifecycle manager

local config = require("sigil.config")
local state = require("sigil.state")
local prettify = require("sigil.prettify")
local motions = require("sigil.motions")
local visual = require("sigil.visual")
local unprettify = require("sigil.unprettify")
local M = {}

---Augroup for sigil autocmds
M.augroup = vim.api.nvim_create_augroup("Sigil", { clear = true })

---@type table<integer, { start: integer, clear_end: integer, prettify_end: integer, timer: uv_timer_t? }>
M._pending = {}

---@type table<integer, uv_timer_t?>
M._lazy_timers = {}

---Get visible line range for buffer with optional buffer zone
---@param buf integer
---@param buffer_lines? integer Lines to add above/below visible area
---@return integer start_row 0-indexed
---@return integer end_row 0-indexed, exclusive
local function get_visible_range(buf, buffer_lines)
	buffer_lines = buffer_lines or config.current.lazy_prettify_buffer or 50
	local wins = vim.fn.win_findbuf(buf)
	local line_count = vim.api.nvim_buf_line_count(buf)

	if #wins == 0 then
		-- No window showing buffer, return empty range (will prettify on BufWinEnter)
		return 0, 0
	end

	-- Find union of all windows showing this buffer
	local min_row, max_row = math.huge, 0
	for _, win in ipairs(wins) do
		local top = vim.fn.line("w0", win) - 1 -- Convert to 0-indexed
		local bot = vim.fn.line("w$", win) -- Already end-exclusive
		min_row = math.min(min_row, top)
		max_row = math.max(max_row, bot)
	end

	-- Add buffer zone
	min_row = math.max(0, min_row - buffer_lines)
	max_row = math.min(line_count, max_row + buffer_lines)

	return min_row, max_row
end

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

	-- Initial prettification
	-- Force Tree-sitter to parse first if available, then prettify
	local ok, parser = pcall(vim.treesitter.get_parser, buf)
	if ok and parser then
		pcall(function()
			parser:parse()
		end)
	end

	-- Check if we should use lazy prettification
	local line_count = vim.api.nvim_buf_line_count(buf)
	local lazy_threshold = config.current.lazy_prettify_threshold or 500
	if lazy_threshold > 0 and line_count > lazy_threshold then
		-- Large file: enable lazy mode and only prettify visible range
		state.enable_lazy_mode(buf)
		local start_row, end_row = get_visible_range(buf)
		if end_row > start_row then
			prettify.prettify_lines(buf, start_row, end_row)
			state.mark_prettified(buf, start_row, end_row)
		end
	else
		-- Small file: prettify everything immediately
		prettify.prettify_buffer(buf)
	end

	-- Setup atomic motions if enabled (but not when unprettify_at_point is active)
	-- When unprettify_at_point is on, cursor shows original text, so normal motions are appropriate
	if config.current.atomic_motions and not config.current.unprettify_at_point then
		motions.setup_keymaps(buf)
	end

	-- Attach incremental update listener
	M.attach_on_lines(buf)

	-- Setup buffer-local autocmds
	M.setup_buffer_autocmds(buf)
end

---Detach from a buffer
---@param buf integer
function M.detach(buf)
	-- Remove atomic motions keymaps (only if they were set up)
	if config.current.atomic_motions and not config.current.unprettify_at_point then
		motions.remove_keymaps(buf)
	end

	-- Clear visual overlays
	visual.clear(buf)

	-- Clear unprettify state
	unprettify.clear(buf)

	-- Clean up pending timer
	local pending = M._pending[buf]
	if pending and pending.timer then
		pending.timer:stop()
		pending.timer:close()
	end
	M._pending[buf] = nil

	-- Clean up lazy prettify timer
	if M._lazy_timers[buf] then
		M._lazy_timers[buf]:stop()
		M._lazy_timers[buf]:close()
		M._lazy_timers[buf] = nil
	end

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

---Attach on_lines handler for incremental updates
---@param buf integer
function M.attach_on_lines(buf)
	vim.api.nvim_buf_attach(buf, false, {
		on_lines = function(_, bufnr, _, firstline, lastline, new_lastline)
			-- Return true to detach when buffer is no longer managed
			if not state.is_attached(bufnr) then
				return true
			end
			if not state.is_enabled(bufnr) or not vim.api.nvim_buf_is_valid(bufnr) then
				return
			end
			M.queue_update(bufnr, firstline, lastline, new_lastline)
		end,
	})
end

---Queue a debounced prettify update for changed lines
---@param buf integer
---@param firstline integer
---@param lastline integer
---@param new_lastline integer
function M.queue_update(buf, firstline, lastline, new_lastline)
	-- Adjust lazy mode range tracking for text edits
	local lines_removed = lastline - firstline
	local lines_added = new_lastline - firstline
	if lines_removed ~= lines_added then
		state.adjust_ranges_for_edit(buf, firstline, lines_removed, lines_added)
	end

	local pending = M._pending[buf]
	local clear_end = math.max(lastline, new_lastline)
	if not pending then
		pending = {
			start = firstline,
			clear_end = clear_end,
			prettify_end = new_lastline,
			timer = nil,
		}
		M._pending[buf] = pending
	else
		-- Expand range to include new changes
		if firstline < pending.start then
			pending.start = firstline
		end
		if clear_end > pending.clear_end then
			pending.clear_end = clear_end
		end
		if new_lastline > pending.prettify_end then
			pending.prettify_end = new_lastline
		end
	end

	local delay = config.current.update_debounce_ms or 0
	if delay <= 0 then
		M.apply_pending(buf)
		return
	end

	-- True debounce: restart timer on each change
	if pending.timer then
		pending.timer:stop()
	else
		pending.timer = vim.uv.new_timer()
	end

	pending.timer:start(
		delay,
		0,
		vim.schedule_wrap(function()
			M.apply_pending(buf)
		end)
	)
end

---Apply queued update for a buffer
---@param buf integer
function M.apply_pending(buf)
	local pending = M._pending[buf]
	if not pending then
		return
	end

	-- Clean up timer
	if pending.timer then
		pending.timer:stop()
		pending.timer:close()
	end

	if not state.is_enabled(buf) or not vim.api.nvim_buf_is_valid(buf) then
		M._pending[buf] = nil
		return
	end

	local line_count = vim.api.nvim_buf_line_count(buf)
	local start_row = math.max(0, math.min(pending.start or 0, line_count))
	local clear_end = math.min(pending.clear_end or start_row, line_count)
	local prettify_end = math.min(pending.prettify_end or start_row, line_count)

	-- Tree-sitter parses incrementally via its own on_bytes handler.
	-- The debounce delay gives it time to catch up, so no forced parse needed.

	if clear_end > start_row then
		state.clear_lines(buf, start_row, clear_end)
	end
	if prettify_end > start_row then
		prettify.prettify_lines(buf, start_row, prettify_end, { clear = false })
	end

	M._pending[buf] = nil

	-- Re-check unprettify at point (extmarks were recreated, old state is stale)
	if config.current.unprettify_at_point then
		unprettify.update(buf)
	end
end

---Queue lazy prettification for visible range (debounced)
---@param buf integer
function M.queue_lazy_prettify(buf)
	if not state.is_lazy_mode(buf) then
		return
	end

	local delay = config.current.lazy_prettify_debounce_ms or 50

	if M._lazy_timers[buf] then
		M._lazy_timers[buf]:stop()
	else
		M._lazy_timers[buf] = vim.uv.new_timer()
	end

	M._lazy_timers[buf]:start(
		delay,
		0,
		vim.schedule_wrap(function()
			M.apply_lazy_prettify(buf)
		end)
	)
end

---Apply lazy prettification for visible range
---@param buf integer
function M.apply_lazy_prettify(buf)
	if M._lazy_timers[buf] then
		M._lazy_timers[buf]:stop()
		M._lazy_timers[buf]:close()
		M._lazy_timers[buf] = nil
	end

	if not state.is_enabled(buf) or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	if not state.is_lazy_mode(buf) then
		return
	end

	local start_row, end_row = get_visible_range(buf)
	local unprettified = state.get_unprettified_in_range(buf, start_row, end_row)

	for _, range in ipairs(unprettified) do
		prettify.prettify_lines(buf, range[1], range[2], { clear = false })
		state.mark_prettified(buf, range[1], range[2])
	end

	-- Re-check unprettify at point (new extmarks may be under cursor)
	if config.current.unprettify_at_point then
		unprettify.update(buf)
	end
end

---Track undo sequence for detecting undo/redo
---@type table<integer, integer>
M._undo_seq = {}

---Setup buffer-local autocmds
---@param buf integer
function M.setup_buffer_autocmds(buf)
	-- Initialize undo tracking
	M._undo_seq[buf] = vim.fn.undotree().seq_cur or 0

	-- Cleanup on buffer delete
	vim.api.nvim_create_autocmd("BufDelete", {
		group = M.augroup,
		buffer = buf,
		callback = function()
			M._undo_seq[buf] = nil
			M.detach(buf)
		end,
	})

	-- Re-apply conceal when entering window and trigger lazy prettify
	vim.api.nvim_create_autocmd("BufWinEnter", {
		group = M.augroup,
		buffer = buf,
		callback = function()
			if state.is_attached(buf) then
				M.setup_conceal(buf)
				-- Trigger lazy prettify for visible range
				if state.is_lazy_mode(buf) then
					M.queue_lazy_prettify(buf)
				end
			end
		end,
	})

	-- Lazy prettify on scroll
	vim.api.nvim_create_autocmd("WinScrolled", {
		group = M.augroup,
		callback = function()
			-- WinScrolled is not buffer-specific, so check if this buffer is in any scrolled window
			local wins = vim.fn.win_findbuf(buf)
			for _, win in ipairs(wins) do
				if vim.v.event and vim.v.event[tostring(win)] then
					if state.is_enabled(buf) and state.is_lazy_mode(buf) then
						M.queue_lazy_prettify(buf)
					end
					break
				end
			end
		end,
	})

	-- Detect undo/redo and refresh buffer
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = M.augroup,
		buffer = buf,
		callback = function()
			if not state.is_enabled(buf) then
				return
			end
			local seq = vim.fn.undotree().seq_cur or 0
			local prev_seq = M._undo_seq[buf] or 0
			M._undo_seq[buf] = seq
			-- If sequence went backward (undo) or jumped (redo), do full refresh
			-- Use vim.schedule to run after Tree-sitter has updated (next event loop)
			if seq < prev_seq or seq > prev_seq + 1 then
				vim.schedule(function()
					if vim.api.nvim_buf_is_valid(buf) and state.is_enabled(buf) then
						-- Force Tree-sitter to parse synchronously
						local ok, parser = pcall(vim.treesitter.get_parser, buf)
						if ok and parser then
							pcall(function()
								parser:parse()
							end)
						end
						-- Reset lazy tracking and refresh
						if state.is_lazy_mode(buf) then
							state.clear_prettified_tracking(buf)
							-- Re-prettify visible range only
							local start_row, end_row = get_visible_range(buf)
							state.clear_lines(buf, 0, -1)
							if end_row > start_row then
								prettify.prettify_lines(buf, start_row, end_row)
								state.mark_prettified(buf, start_row, end_row)
							end
						else
							prettify.refresh(buf)
						end
						-- Re-check unprettify at point after undo/redo refresh
						if config.current.unprettify_at_point then
							unprettify.update(buf)
						end
					end
				end)
			end
		end,
	})

	-- Adjust cursor position after leaving insert mode
	-- (Vim moves cursor left on Esc, which can land inside a concealed symbol)
	vim.api.nvim_create_autocmd("InsertLeave", {
		group = M.augroup,
		buffer = buf,
		callback = function()
			if not state.is_enabled(buf) then
				return
			end
			local cursor = vim.api.nvim_win_get_cursor(0)
			local row = cursor[1] - 1
			local col = cursor[2]
			local symbol = motions.get_symbol_at(buf, row, col)
			if symbol and col > symbol.start_col then
				-- Cursor is inside symbol, move to start
				vim.api.nvim_win_set_cursor(0, { row + 1, symbol.start_col })
			end
		end,
	})

	-- Update visual overlays while selecting and handle unprettify at point
	vim.api.nvim_create_autocmd({ "ModeChanged", "CursorMoved" }, {
		group = M.augroup,
		buffer = buf,
		callback = function()
			visual.update(buf)
			-- Update unprettify at point
			if config.current.unprettify_at_point then
				unprettify.update(buf)
			end
			-- Maintain desired byte column for vertical motions.
			local cursor = vim.api.nvim_win_get_cursor(0)
			if vim.w.sigil_vert_active then
				vim.w.sigil_vert_active = false
			else
				vim.w.sigil_curswant_disp = motions.get_display_col(buf, cursor[1] - 1, cursor[2])
			end
		end,
	})

	-- Also update unprettify on CursorMovedI (insert mode)
	if config.current.unprettify_at_point then
		vim.api.nvim_create_autocmd("CursorMovedI", {
			group = M.augroup,
			buffer = buf,
			callback = function()
				unprettify.update(buf)
			end,
		})
	end
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
