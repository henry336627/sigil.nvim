-- sigil.nvim - Buffer state management

local M = {}

---Plugin namespace (created once)
M.ns = vim.api.nvim_create_namespace("sigil")

---@class sigil.BufState
---@field enabled boolean

---Per-buffer state
---@type table<integer, sigil.BufState>
M.buffers = {}

-- Cache visual module reference
local visual_module = nil

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
	}

	return M.buffers[buf]
end

---Get visual module (cached)
---@return table|nil
local function get_visual()
	if visual_module == nil then
		local ok, mod = pcall(require, "sigil.visual")
		visual_module = ok and mod or false
	end
	return visual_module or nil
end

---Detach from buffer
---@param buf integer
function M.detach(buf)
	if not M.buffers[buf] then
		return
	end

	-- Clear all extmarks
	vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
	-- Clear visual overlay marks
	local visual = get_visual()
	if visual then
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
	local buf_state = M.buffers[buf]
	if buf_state then
		buf_state.enabled = false
		-- Clear extmarks when disabled
		vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
		-- Clear visual overlay marks
		local visual = get_visual()
		if visual then
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

---Clear extmarks for specific lines
---@param buf integer
---@param start_row integer 0-indexed
---@param end_row integer 0-indexed, exclusive
function M.clear_lines(buf, start_row, end_row)
	vim.api.nvim_buf_clear_namespace(buf, M.ns, start_row, end_row)
end

return M
