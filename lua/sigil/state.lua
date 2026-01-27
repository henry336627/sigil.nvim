-- sigil.nvim - Buffer state management

local M = {}

---Plugin namespace (created once)
M.ns = vim.api.nvim_create_namespace("sigil")

---@class sigil.BufState
---@field enabled boolean
---@field marks table<integer, integer[]> Line -> extmark IDs

---Per-buffer state
---@type table<integer, sigil.BufState>
M.buffers = {}

---Check if buffer is attached
---@param buf integer
---@return boolean
function M.is_attached(buf)
	return M.buffers[buf] ~= nil
end

---Get buffer state
---@param buf integer
---@return sigil.BufState|nil
function M.get(buf)
	return M.buffers[buf]
end

---Attach to buffer
---@param buf integer
---@return sigil.BufState
function M.attach(buf)
	if M.buffers[buf] then
		return M.buffers[buf]
	end

	M.buffers[buf] = {
		enabled = true,
		marks = {},
	}

	return M.buffers[buf]
end

---Detach from buffer
---@param buf integer
function M.detach(buf)
	if not M.buffers[buf] then
		return
	end

	-- Clear all extmarks
	vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
	-- Clear visual overlay marks (if module available)
	local ok, visual = pcall(require, "sigil.visual")
	if ok then
		visual.clear(buf)
	end

	M.buffers[buf] = nil
end

---Enable prettify for buffer
---@param buf integer
function M.enable(buf)
	local state = M.buffers[buf]
	if state then
		state.enabled = true
	end
end

---Disable prettify for buffer
---@param buf integer
function M.disable(buf)
	local state = M.buffers[buf]
	if state then
		state.enabled = false
		-- Clear extmarks when disabled
		vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
		state.marks = {}
		-- Clear visual overlay marks (if module available)
		local ok, visual = pcall(require, "sigil.visual")
		if ok then
			visual.clear(buf)
		end
	end
end

---Check if buffer is enabled
---@param buf integer
---@return boolean
function M.is_enabled(buf)
	local state = M.buffers[buf]
	return state ~= nil and state.enabled
end

---Clear marks for specific lines
---@param buf integer
---@param start_row integer 0-indexed
---@param end_row integer 0-indexed, exclusive
function M.clear_lines(buf, start_row, end_row)
	vim.api.nvim_buf_clear_namespace(buf, M.ns, start_row, end_row)

	local state = M.buffers[buf]
	if state then
		for row = start_row, end_row - 1 do
			state.marks[row] = nil
		end
	end
end

---Store extmark ID for a line
---@param buf integer
---@param row integer
---@param mark_id integer
function M.add_mark(buf, row, mark_id)
	local state = M.buffers[buf]
	if not state then
		return
	end

	if not state.marks[row] then
		state.marks[row] = {}
	end

	table.insert(state.marks[row], mark_id)
end

return M
