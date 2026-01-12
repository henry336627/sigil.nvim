-- sigil.nvim - Atomic symbol motions
-- Makes prettified symbols behave as single characters for navigation

local state = require("sigil.state")

local M = {}

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
				replacement = details.conceal,
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
			replacement = mark[4].conceal,
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
				replacement = mark[4].conceal,
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

---Setup keymaps for atomic symbol motions
---@param buf integer
function M.setup_keymaps(buf)
	local opts = { buffer = buf, silent = true }

	vim.keymap.set("n", "l", M.move_right, opts)
	vim.keymap.set("n", "h", M.move_left, opts)
end

---Remove keymaps for atomic symbol motions
---@param buf integer
function M.remove_keymaps(buf)
	pcall(vim.keymap.del, "n", "l", { buffer = buf })
	pcall(vim.keymap.del, "n", "h", { buffer = buf })
end

return M
