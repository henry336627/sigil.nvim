-- sigil.nvim - Atomic symbol motions
-- Makes prettified symbols behave as single characters for navigation

local state = require("sigil.state")

local M = {}

---Extract replacement character from extmark details
---@param details table Extmark details
---@return string|nil Replacement character
local function get_replacement(details)
	-- Check virt_text (overlay mode) first, then conceal (legacy mode)
	if details.virt_text and #details.virt_text > 0 then
		return details.virt_text[1][1]
	elseif details.conceal and details.conceal ~= "" then
		return details.conceal
	end
	return nil
end

---Get extmark info at cursor position if it's a prettified symbol
---@param buf integer Buffer number
---@param row integer 0-indexed row
---@param col integer 0-indexed column
---@return table|nil Extmark info {id, start_col, end_col, replacement} or nil
function M.get_symbol_at(buf, row, col)
	if not state.is_enabled(buf) then
		return nil
	end

	-- Get all extmarks on this line
	local marks = vim.api.nvim_buf_get_extmarks(buf, state.ns, { row, 0 }, { row, -1 }, { details = true })

	for _, mark in ipairs(marks) do
		local mark_id = mark[1]
		local mark_col = mark[3]
		local details = mark[4]

		-- Check if cursor is within this extmark's range
		local end_col = details.end_col or (mark_col + 1)
		if col >= mark_col and col < end_col then
			return {
				id = mark_id,
				start_col = mark_col,
				end_col = end_col,
				replacement = get_replacement(details),
			}
		end
	end

	return nil
end

---Get extmark starting at or after given column
---@param buf integer
---@param row integer 0-indexed row
---@param col integer 0-indexed column (exclusive, search starts after this)
---@return table|nil Extmark info or nil
function M.get_next_symbol(buf, row, col)
	if not state.is_enabled(buf) then
		return nil
	end

	local marks = vim.api.nvim_buf_get_extmarks(buf, state.ns, { row, col + 1 }, { row, -1 }, { details = true })

	if #marks > 0 then
		local mark = marks[1]
		return {
			id = mark[1],
			start_col = mark[3],
			end_col = mark[4].end_col or mark[3],
			replacement = get_replacement(mark[4]),
		}
	end

	return nil
end

---Get extmark ending at or before given column
---@param buf integer
---@param row integer 0-indexed row
---@param col integer 0-indexed column (exclusive, search ends before this)
---@return table|nil Extmark info or nil
function M.get_prev_symbol(buf, row, col)
	if not state.is_enabled(buf) then
		return nil
	end

	-- Get all marks on this line up to col
	local marks = vim.api.nvim_buf_get_extmarks(buf, state.ns, { row, 0 }, { row, col }, { details = true })

	-- Find the last one that ends before or at col
	for i = #marks, 1, -1 do
		local mark = marks[i]
		local end_col = mark[4].end_col or mark[3]
		if end_col <= col then
			return {
				id = mark[1],
				start_col = mark[3],
				end_col = end_col,
				replacement = get_replacement(mark[4]),
			}
		end
	end

	return nil
end

---Move cursor right, treating prettified symbols as single chars
function M.move_right()
	local buf = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1 -- 0-indexed
	local col = cursor[2] -- 0-indexed

	-- Check if we're on a prettified symbol
	local symbol = M.get_symbol_at(buf, row, col)

	if symbol then
		-- Move to end of symbol (past the entire prettified text)
		local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
		local line_len = #line

		if symbol.end_col < line_len then
			vim.api.nvim_win_set_cursor(0, { row + 1, symbol.end_col })
			return
		end
	end

	-- Normal movement (not on a symbol)
	vim.cmd("normal! l")
end

---Move cursor left, treating prettified symbols as single chars
---@return string Empty string (for expr mapping)
function M.move_left()
	local buf = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1 -- 0-indexed
	local col = cursor[2] -- 0-indexed

	-- Check if we're on a prettified symbol (not at its start)
	local symbol = M.get_symbol_at(buf, row, col)

	if symbol and col > symbol.start_col then
		-- Move to start of symbol
		vim.api.nvim_win_set_cursor(0, { row + 1, symbol.start_col })
	else
		-- Check if position to the left is end of a symbol
		if col > 0 then
			local prev_symbol = M.get_symbol_at(buf, row, col - 1)

			if prev_symbol then
				-- Move to start of that symbol
				vim.api.nvim_win_set_cursor(0, { row + 1, prev_symbol.start_col })
			else
				-- Normal movement
				vim.cmd("normal! h")
			end
		else
			-- At start of line
			vim.cmd("normal! h")
		end
	end

	return ""
end

---Check if character is a word character (alphanumeric or underscore)
---@param char string
---@return boolean
local function is_word_char(char)
	return char:match("[%w_]") ~= nil
end

---Check if character is whitespace
---@param char string
---@return boolean
local function is_whitespace(char)
	return char:match("%s") ~= nil
end

---Move to next word start, treating prettified symbols as word boundaries
function M.move_word_forward()
	local buf = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1 -- 0-indexed
	local col = cursor[2] -- 0-indexed

	local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
	if not line or #line == 0 then
		vim.cmd("normal! w")
		return
	end

	-- If we're on a prettified symbol, skip to end of it first
	local symbol = M.get_symbol_at(buf, row, col)
	if symbol then
		col = symbol.end_col
	else
		-- Skip current word
		local char = line:sub(col + 1, col + 1)
		if is_word_char(char) then
			-- Skip word characters
			while col < #line do
				local next_symbol = M.get_symbol_at(buf, row, col)
				if next_symbol then
					col = next_symbol.end_col
					break
				end
				local c = line:sub(col + 1, col + 1)
				if not is_word_char(c) then
					break
				end
				col = col + 1
			end
		elseif not is_whitespace(char) then
			-- Skip punctuation
			while col < #line do
				local next_symbol = M.get_symbol_at(buf, row, col)
				if next_symbol then
					col = next_symbol.end_col
					break
				end
				local c = line:sub(col + 1, col + 1)
				if is_word_char(c) or is_whitespace(c) then
					break
				end
				col = col + 1
			end
		end
	end

	-- Skip whitespace
	while col < #line do
		local c = line:sub(col + 1, col + 1)
		if not is_whitespace(c) then
			break
		end
		col = col + 1
	end

	-- If at end of line, use normal 'w' to go to next line
	if col >= #line then
		vim.cmd("normal! w")
		return
	end

	vim.api.nvim_win_set_cursor(0, { row + 1, col })
end

---Move to previous word start, treating prettified symbols as word boundaries
function M.move_word_backward()
	local buf = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1 -- 0-indexed
	local col = cursor[2] -- 0-indexed

	local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
	if not line or col == 0 then
		vim.cmd("normal! b")
		return
	end

	-- Move one position left first
	col = col - 1

	-- Skip whitespace going backward
	while col > 0 do
		local c = line:sub(col + 1, col + 1)
		if not is_whitespace(c) then
			break
		end
		col = col - 1
	end

	-- Check if we're now on a prettified symbol
	local symbol = M.get_symbol_at(buf, row, col)
	if symbol then
		vim.api.nvim_win_set_cursor(0, { row + 1, symbol.start_col })
		return
	end

	-- Find start of current word/punctuation sequence
	local char = line:sub(col + 1, col + 1)
	if is_word_char(char) then
		-- Go back to start of word
		while col > 0 do
			local prev_symbol = M.get_symbol_at(buf, row, col - 1)
			if prev_symbol then
				break
			end
			local c = line:sub(col, col)
			if not is_word_char(c) then
				break
			end
			col = col - 1
		end
	elseif not is_whitespace(char) then
		-- Go back to start of punctuation
		while col > 0 do
			local prev_symbol = M.get_symbol_at(buf, row, col - 1)
			if prev_symbol then
				break
			end
			local c = line:sub(col, col)
			if is_word_char(c) or is_whitespace(c) then
				break
			end
			col = col - 1
		end
	end

	-- If at start of line, use normal 'b' to go to previous line
	if col < 0 then
		vim.cmd("normal! b")
		return
	end

	vim.api.nvim_win_set_cursor(0, { row + 1, col })
end

---Move to end of word, treating prettified symbols as word boundaries
function M.move_word_end()
	local buf = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1 -- 0-indexed
	local col = cursor[2] -- 0-indexed

	local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
	if not line or #line == 0 then
		vim.cmd("normal! e")
		return
	end

	-- If we're on a prettified symbol, skip past it first
	local current_symbol = M.get_symbol_at(buf, row, col)
	if current_symbol then
		col = current_symbol.end_col
	else
		-- Move at least one position
		col = col + 1
	end

	-- Skip whitespace
	while col < #line do
		local c = line:sub(col + 1, col + 1)
		if not is_whitespace(c) then
			break
		end
		col = col + 1
	end

	-- If at end of line, use normal 'e' to go to next line
	if col >= #line then
		vim.cmd("normal! e")
		return
	end

	-- Check if we're now on a prettified symbol
	local symbol = M.get_symbol_at(buf, row, col)
	if symbol then
		-- For concealed symbols, cursor on start_col visually appears "on" the symbol
		vim.api.nvim_win_set_cursor(0, { row + 1, symbol.start_col })
		return
	end

	-- Find end of current word/punctuation sequence
	local char = line:sub(col + 1, col + 1)
	if is_word_char(char) then
		while col < #line - 1 do
			local next_symbol = M.get_symbol_at(buf, row, col + 1)
			if next_symbol then
				break
			end
			local c = line:sub(col + 2, col + 2)
			if not is_word_char(c) then
				break
			end
			col = col + 1
		end
	elseif not is_whitespace(char) then
		while col < #line - 1 do
			local next_symbol = M.get_symbol_at(buf, row, col + 1)
			if next_symbol then
				break
			end
			local c = line:sub(col + 2, col + 2)
			if is_word_char(c) or is_whitespace(c) then
				break
			end
			col = col + 1
		end
	end

	vim.api.nvim_win_set_cursor(0, { row + 1, col })
end

---Delete character under cursor (or entire prettified symbol)
function M.delete_char()
	local buf = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1 -- 0-indexed
	local col = cursor[2] -- 0-indexed

	-- Check if we're on a prettified symbol
	local symbol = M.get_symbol_at(buf, row, col)

	if symbol then
		-- Delete the entire symbol text
		local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
		local new_line = line:sub(1, symbol.start_col) .. line:sub(symbol.end_col + 1)
		vim.api.nvim_buf_set_lines(buf, row, row + 1, false, { new_line })
		-- Cursor stays at symbol.start_col or adjusts if at end of line
		local new_col = math.min(symbol.start_col, #new_line - 1)
		new_col = math.max(0, new_col)
		vim.api.nvim_win_set_cursor(0, { row + 1, new_col })
	else
		-- Normal delete
		vim.cmd("normal! x")
	end
end

---Delete character before cursor (or entire prettified symbol before cursor)
function M.delete_char_before()
	local buf = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1 -- 0-indexed
	local col = cursor[2] -- 0-indexed

	if col == 0 then
		-- At start of line, normal X behavior
		vim.cmd("normal! X")
		return
	end

	-- Check if character before cursor is part of a prettified symbol
	local symbol = M.get_symbol_at(buf, row, col - 1)

	if symbol then
		-- Delete the entire symbol text
		local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
		local new_line = line:sub(1, symbol.start_col) .. line:sub(symbol.end_col + 1)
		vim.api.nvim_buf_set_lines(buf, row, row + 1, false, { new_line })
		-- Move cursor to where symbol started
		local new_col = math.max(0, symbol.start_col)
		vim.api.nvim_win_set_cursor(0, { row + 1, new_col })
	else
		-- Normal delete before
		vim.cmd("normal! X")
	end
end

---Substitute character under cursor (or entire prettified symbol) and enter insert mode
function M.substitute_char()
	local buf = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1 -- 0-indexed
	local col = cursor[2] -- 0-indexed

	-- Check if we're on a prettified symbol
	local symbol = M.get_symbol_at(buf, row, col)

	if symbol then
		-- Delete the entire symbol text and enter insert mode
		local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
		local new_line = line:sub(1, symbol.start_col) .. line:sub(symbol.end_col + 1)
		vim.api.nvim_buf_set_lines(buf, row, row + 1, false, { new_line })
		-- Position cursor at symbol start and enter insert mode
		vim.api.nvim_win_set_cursor(0, { row + 1, symbol.start_col })
		vim.cmd("startinsert")
	else
		-- Normal substitute
		vim.cmd("normal! s")
	end
end

---Change operator function for use with motions
---This is called by operatorfunc after a motion is applied
---@param type string The type of motion: 'char', 'line', or 'block'
function M.change_opfunc(type)
	local buf = vim.api.nvim_get_current_buf()

	if type == "char" then
		-- Get the range marked by '[ and ']
		local start_pos = vim.api.nvim_buf_get_mark(buf, "[")
		local end_pos = vim.api.nvim_buf_get_mark(buf, "]")

		local start_row = start_pos[1] - 1 -- 0-indexed
		local start_col = start_pos[2]
		local end_row = end_pos[1] - 1
		local end_col = end_pos[2]

		-- Handle single-line change
		if start_row == end_row then
			-- Check if start position is on a prettified symbol
			local start_symbol = M.get_symbol_at(buf, start_row, start_col)
			if start_symbol and start_col > start_symbol.start_col then
				-- Expand start to include whole symbol
				start_col = start_symbol.start_col
			end

			-- Check if end position is on a prettified symbol
			local end_symbol = M.get_symbol_at(buf, end_row, end_col)
			if end_symbol then
				-- Expand end to include whole symbol
				end_col = end_symbol.end_col - 1
			end

			-- Delete the range and enter insert mode
			local line = vim.api.nvim_buf_get_lines(buf, start_row, start_row + 1, false)[1]
			local new_line = line:sub(1, start_col) .. line:sub(end_col + 2)
			vim.api.nvim_buf_set_lines(buf, start_row, start_row + 1, false, { new_line })
			vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
			vim.cmd("startinsert")
		else
			-- Multi-line change - use normal behavior
			vim.cmd('normal! `[v`]"_c')
		end
	elseif type == "line" then
		-- Line-wise change - use normal behavior
		vim.cmd('normal! `[V`]"_c')
	else
		-- Block change - use normal behavior
		vim.cmd('normal! `[\\<C-V>`]"_c')
	end
end

---Set up change operator and wait for motion
function M.change_operator()
	vim.o.operatorfunc = "v:lua.require'sigil.motions'.change_opfunc"
	return "g@"
end

-- ============================================
-- Visual Mode Support (4.6)
-- ============================================

---Get the visual selection range
---@return integer, integer, integer, integer start_row, start_col, end_row, end_col (0-indexed)
local function get_visual_range()
	local start_pos = vim.fn.getpos("v")
	local end_pos = vim.fn.getpos(".")

	local start_row = start_pos[2] - 1
	local start_col = start_pos[3] - 1
	local end_row = end_pos[2] - 1
	local end_col = end_pos[3] - 1

	-- Ensure start is before end
	if start_row > end_row or (start_row == end_row and start_col > end_col) then
		start_row, end_row = end_row, start_row
		start_col, end_col = end_col, start_col
	end

	return start_row, start_col, end_row, end_col
end

---Expand visual selection to include full prettified symbols at boundaries
---@param buf integer
---@param start_row integer 0-indexed
---@param start_col integer 0-indexed
---@param end_row integer 0-indexed
---@param end_col integer 0-indexed
---@return integer, integer, integer, integer Expanded range
local function expand_selection_to_symbols(buf, start_row, start_col, end_row, end_col)
	-- Check if start is inside a prettified symbol
	local start_symbol = M.get_symbol_at(buf, start_row, start_col)
	if start_symbol and start_col > start_symbol.start_col then
		start_col = start_symbol.start_col
	end

	-- Check if end is inside a prettified symbol
	local end_symbol = M.get_symbol_at(buf, end_row, end_col)
	if end_symbol and end_col < end_symbol.end_col - 1 then
		end_col = end_symbol.end_col - 1
	end

	return start_row, start_col, end_row, end_col
end

---Move cursor right in visual mode, treating prettified symbols as single chars
function M.visual_move_right()
	local buf = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1 -- 0-indexed
	local col = cursor[2] -- 0-indexed

	local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
	if not line then
		vim.cmd("normal! l")
		return
	end

	-- Check if we're on a prettified symbol
	local symbol = M.get_symbol_at(buf, row, col)

	if symbol then
		-- On a symbol: move past it (to end_col)
		if symbol.end_col < #line then
			vim.api.nvim_win_set_cursor(0, { row + 1, symbol.end_col })
		else
			vim.cmd("normal! l")
		end
	else
		-- Not on a symbol: normal movement (will land on symbol start if next char is symbol)
		vim.cmd("normal! l")
	end
end

---Move cursor left in visual mode, treating prettified symbols as single chars
function M.visual_move_left()
	local buf = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1 -- 0-indexed
	local col = cursor[2] -- 0-indexed

	-- Check if we're on a prettified symbol (not at its start)
	local symbol = M.get_symbol_at(buf, row, col)

	if symbol and col > symbol.start_col then
		-- Move to start of symbol
		vim.api.nvim_win_set_cursor(0, { row + 1, symbol.start_col })
	elseif col > 0 then
		-- Check if position to the left is part of a symbol
		local prev_symbol = M.get_symbol_at(buf, row, col - 1)

		if prev_symbol then
			-- Move to start of that symbol
			vim.api.nvim_win_set_cursor(0, { row + 1, prev_symbol.start_col })
		else
			vim.cmd("normal! h")
		end
	else
		vim.cmd("normal! h")
	end
end

---Move to next word in visual mode, treating prettified symbols as boundaries
function M.visual_move_word_forward()
	local buf = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1 -- 0-indexed
	local col = cursor[2] -- 0-indexed

	local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
	if not line or #line == 0 then
		vim.cmd("normal! w")
		return
	end

	-- If we're on a prettified symbol, skip to end of it first
	local symbol = M.get_symbol_at(buf, row, col)
	if symbol then
		col = symbol.end_col
	else
		-- Skip current word
		local char = line:sub(col + 1, col + 1)
		if is_word_char(char) then
			while col < #line do
				local next_symbol = M.get_symbol_at(buf, row, col)
				if next_symbol then
					col = next_symbol.end_col
					break
				end
				local c = line:sub(col + 1, col + 1)
				if not is_word_char(c) then
					break
				end
				col = col + 1
			end
		elseif not is_whitespace(char) then
			while col < #line do
				local next_symbol = M.get_symbol_at(buf, row, col)
				if next_symbol then
					col = next_symbol.end_col
					break
				end
				local c = line:sub(col + 1, col + 1)
				if is_word_char(c) or is_whitespace(c) then
					break
				end
				col = col + 1
			end
		end
	end

	-- Skip whitespace
	while col < #line do
		local c = line:sub(col + 1, col + 1)
		if not is_whitespace(c) then
			break
		end
		col = col + 1
	end

	if col >= #line then
		vim.cmd("normal! w")
		return
	end

	vim.api.nvim_win_set_cursor(0, { row + 1, col })
end

---Move to previous word in visual mode, treating prettified symbols as boundaries
function M.visual_move_word_backward()
	local buf = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1 -- 0-indexed
	local col = cursor[2] -- 0-indexed

	local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
	if not line or col == 0 then
		vim.cmd("normal! b")
		return
	end

	-- Move one position left first
	col = col - 1

	-- Skip whitespace going backward
	while col > 0 do
		local c = line:sub(col + 1, col + 1)
		if not is_whitespace(c) then
			break
		end
		col = col - 1
	end

	-- Check if we're now on a prettified symbol
	local symbol = M.get_symbol_at(buf, row, col)
	if symbol then
		vim.api.nvim_win_set_cursor(0, { row + 1, symbol.start_col })
		return
	end

	-- Find start of current word/punctuation sequence
	local char = line:sub(col + 1, col + 1)
	if is_word_char(char) then
		while col > 0 do
			local prev_symbol = M.get_symbol_at(buf, row, col - 1)
			if prev_symbol then
				break
			end
			local c = line:sub(col, col)
			if not is_word_char(c) then
				break
			end
			col = col - 1
		end
	elseif not is_whitespace(char) then
		while col > 0 do
			local prev_symbol = M.get_symbol_at(buf, row, col - 1)
			if prev_symbol then
				break
			end
			local c = line:sub(col, col)
			if is_word_char(c) or is_whitespace(c) then
				break
			end
			col = col - 1
		end
	end

	if col < 0 then
		vim.cmd("normal! b")
		return
	end

	vim.api.nvim_win_set_cursor(0, { row + 1, col })
end

---Move to end of word in visual mode, treating prettified symbols as boundaries
function M.visual_move_word_end()
	local buf = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1 -- 0-indexed
	local col = cursor[2] -- 0-indexed

	local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
	if not line or #line == 0 then
		vim.cmd("normal! e")
		return
	end

	-- If we're on a prettified symbol, skip past it first
	local current_symbol = M.get_symbol_at(buf, row, col)
	if current_symbol then
		col = current_symbol.end_col
	else
		col = col + 1
	end

	-- Skip whitespace
	while col < #line do
		local c = line:sub(col + 1, col + 1)
		if not is_whitespace(c) then
			break
		end
		col = col + 1
	end

	if col >= #line then
		vim.cmd("normal! e")
		return
	end

	-- Check if we're now on a prettified symbol
	local symbol = M.get_symbol_at(buf, row, col)
	if symbol then
		-- In visual mode, position at end of symbol (end_col - 1)
		vim.api.nvim_win_set_cursor(0, { row + 1, symbol.end_col - 1 })
		return
	end

	-- Find end of current word/punctuation sequence
	local char = line:sub(col + 1, col + 1)
	if is_word_char(char) then
		while col < #line - 1 do
			local next_symbol = M.get_symbol_at(buf, row, col + 1)
			if next_symbol then
				break
			end
			local c = line:sub(col + 2, col + 2)
			if not is_word_char(c) then
				break
			end
			col = col + 1
		end
	elseif not is_whitespace(char) then
		while col < #line - 1 do
			local next_symbol = M.get_symbol_at(buf, row, col + 1)
			if next_symbol then
				break
			end
			local c = line:sub(col + 2, col + 2)
			if is_word_char(c) or is_whitespace(c) then
				break
			end
			col = col + 1
		end
	end

	vim.api.nvim_win_set_cursor(0, { row + 1, col })
end

---Adjust visual selection to include full prettified symbols
---Called after standard visual operations (d, y, c) via operatorfunc
function M.visual_adjust_selection()
	local buf = vim.api.nvim_get_current_buf()
	local mode = vim.fn.mode()

	if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
		return
	end

	local start_row, start_col, end_row, end_col = get_visual_range()
	local new_start_row, new_start_col, new_end_row, new_end_col =
		expand_selection_to_symbols(buf, start_row, start_col, end_row, end_col)

	-- If selection was expanded, update it
	if new_start_col ~= start_col or new_end_col ~= end_col then
		-- Exit visual mode and reselect with new range
		vim.cmd("normal! \\<Esc>")
		vim.api.nvim_win_set_cursor(0, { new_start_row + 1, new_start_col })
		vim.cmd("normal! v")
		vim.api.nvim_win_set_cursor(0, { new_end_row + 1, new_end_col })
	end
end

---Setup keymaps for atomic symbol motions
---@param buf integer
function M.setup_keymaps(buf)
	local opts = { buffer = buf, silent = true }

	-- Character motions (normal mode)
	vim.keymap.set("n", "l", M.move_right, opts)
	vim.keymap.set("n", "h", M.move_left, opts)

	-- Word motions (normal mode)
	vim.keymap.set("n", "w", M.move_word_forward, opts)
	vim.keymap.set("n", "b", M.move_word_backward, opts)
	vim.keymap.set("n", "e", M.move_word_end, opts)

	-- Delete operations
	vim.keymap.set("n", "x", M.delete_char, opts)
	vim.keymap.set("n", "X", M.delete_char_before, opts)

	-- Change operations
	vim.keymap.set("n", "s", M.substitute_char, opts)
	vim.keymap.set("n", "c", M.change_operator, { buffer = buf, silent = true, expr = true })

	-- Visual mode motions (4.6)
	vim.keymap.set("x", "l", M.visual_move_right, opts)
	vim.keymap.set("x", "h", M.visual_move_left, opts)
	vim.keymap.set("x", "w", M.visual_move_word_forward, opts)
	vim.keymap.set("x", "b", M.visual_move_word_backward, opts)
	vim.keymap.set("x", "e", M.visual_move_word_end, opts)
end

---Remove keymaps for atomic symbol motions
---@param buf integer
function M.remove_keymaps(buf)
	-- Character motions (normal mode)
	pcall(vim.keymap.del, "n", "l", { buffer = buf })
	pcall(vim.keymap.del, "n", "h", { buffer = buf })

	-- Word motions (normal mode)
	pcall(vim.keymap.del, "n", "w", { buffer = buf })
	pcall(vim.keymap.del, "n", "b", { buffer = buf })
	pcall(vim.keymap.del, "n", "e", { buffer = buf })

	-- Delete operations
	pcall(vim.keymap.del, "n", "x", { buffer = buf })
	pcall(vim.keymap.del, "n", "X", { buffer = buf })

	-- Change operations
	pcall(vim.keymap.del, "n", "s", { buffer = buf })
	pcall(vim.keymap.del, "n", "c", { buffer = buf })

	-- Visual mode motions (4.6)
	pcall(vim.keymap.del, "x", "l", { buffer = buf })
	pcall(vim.keymap.del, "x", "h", { buffer = buf })
	pcall(vim.keymap.del, "x", "w", { buffer = buf })
	pcall(vim.keymap.del, "x", "b", { buffer = buf })
	pcall(vim.keymap.del, "x", "e", { buffer = buf })
end

return M
