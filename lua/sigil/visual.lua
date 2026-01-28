-- sigil.nvim - Visual selection highlighting for prettified symbols

local state = require("sigil.state")

local M = {}

-- Namespace for visual overlay marks
M.ns = vim.api.nvim_create_namespace("sigil_visual")

-- Track which buffers currently have visual overlays
M._active = {}

---Extract replacement character from extmark details
---@param details table Extmark details
---@return string|nil
local function get_replacement(details)
	if details.virt_text and #details.virt_text > 0 then
		return details.virt_text[1][1]
	elseif details.conceal and details.conceal ~= "" and details.conceal ~= " " then
		return details.conceal
	end
	return nil
end

---Get current visual selection range
---@return string|nil, integer, integer, integer, integer mode, start_row, start_col, end_row, end_col (0-indexed)
local function get_visual_range()
	local mode = vim.fn.mode()
	if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
		return nil
	end

	local start_pos = vim.fn.getpos("v")
	local end_pos = vim.fn.getpos(".")

	local start_row = start_pos[2] - 1
	local start_col = start_pos[3] - 1
	local end_row = end_pos[2] - 1
	local end_col = end_pos[3] - 1

	-- Normalize ordering
	if start_row > end_row or (start_row == end_row and start_col > end_col) then
		start_row, end_row = end_row, start_row
		start_col, end_col = end_col, start_col
	end

	-- Linewise visual: cover full lines
	if mode == "V" then
		start_col = 0
		end_col = math.huge
	end

	return mode, start_row, start_col, end_row, end_col
end

---Clear visual overlay marks
---@param buf integer
function M.clear(buf)
	vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
	M._active[buf] = nil
end

---Update visual overlay marks for current selection
---@param buf integer
function M.update(buf)
	if not state.is_enabled(buf) then
		if M._active[buf] then
			M.clear(buf)
		end
		return
	end

	local mode, start_row, start_col, end_row, end_col = get_visual_range()
	if not mode then
		if M._active[buf] then
			M.clear(buf)
		end
		return
	end

	-- Reset overlay marks
	M.clear(buf)
	M._active[buf] = true

	-- Fetch base extmarks within selected rows
	local marks = vim.api.nvim_buf_get_extmarks(buf, state.ns, { start_row, 0 }, { end_row, -1 }, { details = true })

	for _, mark in ipairs(marks) do
		local row = mark[2]
		local col = mark[3]
		local details = mark[4]
		local mark_end = details.end_col or (col + 1)

		-- Determine selection columns for this row
		local sel_start = start_col
		local sel_end = end_col

		if mode == "\22" then
			-- blockwise: use fixed column range
			sel_start = start_col
			sel_end = end_col
		elseif row == start_row then
			sel_start = start_col
		else
			sel_start = 0
		end

		if row == end_row then
			sel_end = end_col
		else
			sel_end = math.huge
		end

		-- Intersection check (inclusive selection)
		if mark_end - 1 >= sel_start and col <= sel_end then
			local replacement = get_replacement(details)
			if replacement and replacement ~= "" then
				vim.api.nvim_buf_set_extmark(buf, M.ns, row, col, {
					end_col = mark_end,
					virt_text = { { replacement, "Visual" } },
					virt_text_pos = "overlay",
					priority = 200,
				})
			end
		end
	end
end

return M
