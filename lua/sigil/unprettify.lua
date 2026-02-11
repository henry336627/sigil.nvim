-- sigil.nvim - Unprettify at point module
-- Shows original text when cursor is on a prettified symbol

local state = require("sigil.state")
local config = require("sigil.config")

local M = {}

---@class sigil.UnprettifyState
---@field buf integer Buffer number
---@field id integer Extmark ID that is currently unprettified
---@field row integer 0-indexed row
---@field col integer 0-indexed start column
---@field end_col integer 0-indexed end column
---@field replacement string Original replacement character

---Per-buffer state tracking which symbol is currently unprettified
---@type table<integer, sigil.UnprettifyState|nil>
M._state = {}

---Restore a previously unprettified symbol
---@param buf integer
local function restore_symbol(buf)
	local s = M._state[buf]
	if not s then
		return
	end

	-- Check if buffer is still valid
	if not vim.api.nvim_buf_is_valid(buf) then
		M._state[buf] = nil
		return
	end

	-- Get current extmark position (may have moved due to edits)
	-- Use pcall in case namespace was cleared
	local ok, marks = pcall(vim.api.nvim_buf_get_extmarks, buf, state.ns, s.id, s.id, { details = true })
	if not ok then
		M._state[buf] = nil
		return
	end
	if #marks == 0 then
		-- Extmark was deleted
		M._state[buf] = nil
		return
	end

	local mark = marks[1]
	local row = mark[2]
	local col = mark[3]
	local details = mark[4]
	local end_col = details.end_col or (col + 1)

	-- Restore virt_text by updating the extmark
	pcall(vim.api.nvim_buf_set_extmark, buf, state.ns, row, col, {
		id = s.id,
		end_col = end_col,
		conceal = " ",
		virt_text = { { s.replacement } },
		virt_text_pos = "overlay",
		virt_text_hide = false,
		hl_mode = "combine",
		priority = 100,
	})

	M._state[buf] = nil
end

---Hide the virt_text for a symbol (show original text)
---@param buf integer
---@param id integer Extmark ID
---@param row integer 0-indexed row
---@param col integer 0-indexed start column
---@param end_col integer 0-indexed end column
---@param replacement string The replacement character to restore later
local function hide_symbol(buf, id, row, col, end_col, replacement)
	-- Update extmark without virt_text (shows original concealed text as spaces)
	-- Actually, we need to remove conceal too to show original text
	pcall(vim.api.nvim_buf_set_extmark, buf, state.ns, row, col, {
		id = id,
		end_col = end_col,
		-- No conceal - shows original text
		-- No virt_text - no overlay
		priority = 100,
	})

	M._state[buf] = {
		buf = buf,
		id = id,
		row = row,
		col = col,
		end_col = end_col,
		replacement = replacement,
	}
end

---Extract replacement character from extmark details
---@param details table Extmark details
---@return string|nil Replacement character
local function get_replacement(details)
	if details.virt_text and #details.virt_text > 0 then
		return details.virt_text[1][1]
	elseif details.conceal and details.conceal ~= "" and details.conceal ~= " " then
		return details.conceal
	end
	return nil
end

---Check if cursor is on a symbol and should unprettify
---@param buf integer
---@param row integer 0-indexed row
---@param col integer 0-indexed column
---@return table|nil Extmark info {id, row, col, end_col, replacement} or nil
local function get_symbol_at_cursor(buf, row, col)
	local marks = vim.api.nvim_buf_get_extmarks(buf, state.ns, { row, 0 }, { row, -1 }, { details = true })

	for _, mark in ipairs(marks) do
		local start_col = mark[3]
		local end_col = mark[4].end_col or (start_col + 1)
		local replacement = get_replacement(mark[4])

		if replacement and col >= start_col and col < end_col then
			return {
				id = mark[1],
				row = mark[2],
				col = start_col,
				end_col = end_col,
				replacement = replacement,
			}
		end
	end

	return nil
end

---Check if cursor should trigger unprettify based on mode setting
---@param symbol table Symbol info
---@param col integer Cursor column
---@return boolean
local function should_unprettify(symbol, col)
	local mode = config.current.unprettify_at_point

	if not mode then
		return false
	end

	if mode == "right-edge" then
		-- Only unprettify when cursor is past the start (not on first char)
		return col > symbol.col
	end

	-- mode == true: unprettify when cursor is anywhere on the symbol
	return true
end

---Check if cursor is within the currently unprettified symbol
---@param current_state sigil.UnprettifyState
---@param row integer 0-indexed row
---@param col integer 0-indexed column
---@return boolean
local function cursor_in_unprettified(current_state, row, col)
	if current_state.row ~= row then
		return false
	end
	return col >= current_state.col and col < current_state.end_col
end

---Update unprettify state based on cursor position
---Called on CursorMoved/CursorMovedI
---@param buf integer
function M.update(buf)
	if not config.current.unprettify_at_point then
		return
	end

	if not state.is_enabled(buf) then
		-- Restore any unprettified symbol if sigil is disabled
		restore_symbol(buf)
		return
	end

	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1
	local col = cursor[2]

	local current_state = M._state[buf]

	-- If we have an unprettified symbol, check if cursor is still on it
	if current_state then
		-- Verify the extmark still exists (may have been deleted by refresh/undo)
		local ok, marks = pcall(vim.api.nvim_buf_get_extmarks, buf, state.ns, current_state.id, current_state.id, {})
		if not ok or #marks == 0 then
			-- Extmark was deleted (e.g., by undo/refresh), clear stale state
			M._state[buf] = nil
		elseif cursor_in_unprettified(current_state, row, col) then
			-- Check right-edge mode
			local mode = config.current.unprettify_at_point
			if mode == "right-edge" and col <= current_state.col then
				-- Cursor moved back to start, restore
				restore_symbol(buf)
				return
			end
			-- Still on the same symbol, do nothing
			return
		else
			-- Cursor moved away, restore
			restore_symbol(buf)
		end
	end

	-- Look for a new symbol at cursor position
	local symbol = get_symbol_at_cursor(buf, row, col)

	-- No symbol at cursor
	if not symbol then
		return
	end

	-- Check if we should unprettify based on mode
	if not should_unprettify(symbol, col) then
		return
	end

	-- Hide the symbol
	hide_symbol(buf, symbol.id, symbol.row, symbol.col, symbol.end_col, symbol.replacement)
end

---Clear unprettify state for a buffer (called on detach)
---@param buf integer
function M.clear(buf)
	restore_symbol(buf)
	M._state[buf] = nil
end

return M
