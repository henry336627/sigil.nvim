-- sigil.nvim - Buffer state management

local M = {}

---Plugin namespace (created once)
M.ns = vim.api.nvim_create_namespace("sigil")

---@class sigil.BufState
---@field enabled boolean
---@field prettified_ranges? table[] List of {start, end} intervals (0-indexed, end exclusive)
---@field lazy_mode? boolean Whether lazy prettification is active for this buffer

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

---Enable lazy mode for buffer
---@param buf integer
function M.enable_lazy_mode(buf)
	local buf_state = M.buffers[buf]
	if buf_state then
		buf_state.lazy_mode = true
		buf_state.prettified_ranges = {}
	end
end

---Check if buffer is in lazy mode
---@param buf integer
---@return boolean
function M.is_lazy_mode(buf)
	local buf_state = M.buffers[buf]
	return buf_state ~= nil and buf_state.lazy_mode == true
end

---Mark a range as prettified (for lazy mode)
---@param buf integer
---@param start_row integer 0-indexed
---@param end_row integer 0-indexed, exclusive
function M.mark_prettified(buf, start_row, end_row)
	local buf_state = M.buffers[buf]
	if not buf_state or not buf_state.lazy_mode then
		return
	end

	local ranges = buf_state.prettified_ranges or {}

	-- Insert new range and merge overlapping/adjacent intervals
	local new_ranges = {}
	local inserted = false

	for _, range in ipairs(ranges) do
		if range[2] < start_row then
			-- range is before new range
			table.insert(new_ranges, range)
		elseif range[1] > end_row then
			-- range is after new range
			if not inserted then
				table.insert(new_ranges, { start_row, end_row })
				inserted = true
			end
			table.insert(new_ranges, range)
		else
			-- ranges overlap or are adjacent, merge
			start_row = math.min(start_row, range[1])
			end_row = math.max(end_row, range[2])
		end
	end

	if not inserted then
		table.insert(new_ranges, { start_row, end_row })
	end

	buf_state.prettified_ranges = new_ranges
end

---Get unprettified sub-ranges within a given range
---@param buf integer
---@param start_row integer 0-indexed
---@param end_row integer 0-indexed, exclusive
---@return table[] List of {start, end} intervals that need prettification
function M.get_unprettified_in_range(buf, start_row, end_row)
	local buf_state = M.buffers[buf]
	if not buf_state or not buf_state.lazy_mode then
		return { { start_row, end_row } }
	end

	local ranges = buf_state.prettified_ranges or {}
	local result = {}
	local current = start_row

	for _, range in ipairs(ranges) do
		if range[2] <= start_row then
			-- range is before our area, skip
		elseif range[1] >= end_row then
			-- range is after our area, stop
			break
		else
			-- range overlaps with our area
			if range[1] > current then
				-- gap before this range
				table.insert(result, { current, math.min(range[1], end_row) })
			end
			current = math.max(current, range[2])
		end
	end

	-- Remaining gap after all ranges
	if current < end_row then
		table.insert(result, { current, end_row })
	end

	return result
end

---Clear prettified range tracking (for full refresh)
---@param buf integer
function M.clear_prettified_tracking(buf)
	local buf_state = M.buffers[buf]
	if buf_state and buf_state.lazy_mode then
		buf_state.prettified_ranges = {}
	end
end

---Adjust prettified ranges when lines are deleted/inserted
---@param buf integer
---@param start_row integer 0-indexed line where change starts
---@param lines_removed integer Number of lines removed
---@param lines_added integer Number of lines added
function M.adjust_ranges_for_edit(buf, start_row, lines_removed, lines_added)
	local buf_state = M.buffers[buf]
	if not buf_state or not buf_state.lazy_mode then
		return
	end

	local ranges = buf_state.prettified_ranges or {}
	local delta = lines_added - lines_removed
	local edit_end = start_row + lines_removed

	local new_ranges = {}
	for _, range in ipairs(ranges) do
		if range[2] <= start_row then
			-- range is entirely before edit
			table.insert(new_ranges, range)
		elseif range[1] >= edit_end then
			-- range is entirely after edit, shift by delta
			table.insert(new_ranges, { range[1] + delta, range[2] + delta })
		else
			-- range overlaps with edit region
			if range[1] < start_row then
				-- part before edit survives
				table.insert(new_ranges, { range[1], start_row })
			end
			if range[2] > edit_end then
				-- part after edit survives (shifted)
				local new_start = start_row + lines_added
				local new_end = range[2] + delta
				if new_end > new_start then
					table.insert(new_ranges, { new_start, new_end })
				end
			end
		end
	end

	buf_state.prettified_ranges = new_ranges
end

return M
