-- sigil.nvim - Extmark wrapper module

local M = {}

-- Import state lazily to avoid circular dependency
local function get_ns()
	return require("sigil.state").ns
end

---Create a conceal extmark
---@param buf integer Buffer number
---@param row integer 0-indexed row
---@param col integer 0-indexed start column
---@param end_col integer 0-indexed end column (exclusive)
---@param replacement string Single character to display
---@return integer|nil Extmark ID or nil on failure
function M.create(buf, row, col, end_col, replacement)
	local opts = {
		end_col = end_col,
		-- Hide original text; render replacement via virt_text so Visual highlight can combine.
		-- Use a single-space conceal so the replacement still occupies one cell.
		conceal = " ",
		-- No explicit highlight: lets Visual selection background show through.
		virt_text = { { replacement } },
		virt_text_pos = "overlay",
		virt_text_hide = true,
		hl_mode = "combine",
		priority = 100,
	}

	local ok, id = pcall(vim.api.nvim_buf_set_extmark, buf, get_ns(), row, col, opts)

	if not ok then
		-- Fallback for older Neovim versions that don't support overlay virt_text.
		ok, id = pcall(vim.api.nvim_buf_set_extmark, buf, get_ns(), row, col, {
			end_col = end_col,
			conceal = replacement,
			priority = 100,
		})
	end

	if ok then
		return id
	end

	return nil
end

---Delete a specific extmark
---@param buf integer
---@param id integer
function M.delete(buf, id)
	pcall(vim.api.nvim_buf_del_extmark, buf, get_ns(), id)
end

---Clear extmarks in a range
---@param buf integer
---@param start_row? integer 0-indexed start row (default 0)
---@param end_row? integer 0-indexed end row exclusive (default -1 for end)
function M.clear(buf, start_row, end_row)
	start_row = start_row or 0
	end_row = end_row or -1
	vim.api.nvim_buf_clear_namespace(buf, get_ns(), start_row, end_row)
end

---Get extmark at position
---@param buf integer
---@param row integer
---@param col integer
---@return table|nil Extmark info or nil
function M.get_at(buf, row, col)
	local marks = vim.api.nvim_buf_get_extmarks(buf, get_ns(), { row, col }, { row, col + 1 }, { details = true })

	if #marks > 0 then
		return {
			id = marks[1][1],
			row = marks[1][2],
			col = marks[1][3],
			details = marks[1][4],
		}
	end

	return nil
end

---Get all extmarks in buffer
---@param buf integer
---@return table[] List of extmarks
function M.get_all(buf)
	return vim.api.nvim_buf_get_extmarks(buf, get_ns(), 0, -1, { details = true })
end

return M
