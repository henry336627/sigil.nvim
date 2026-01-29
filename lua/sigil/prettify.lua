-- sigil.nvim - Core prettification logic

local config = require("sigil.config")
local state = require("sigil.state")
local extmark = require("sigil.extmark")

local M = {}

---Normalize symbols to a sorted list
---@param symbols table<string, string>|table[] Map or list of {pattern, replacement, boundary?}
---@return table[] sorted list
local function normalize_symbols(symbols)
	if symbols[1] and symbols[1].pattern then
		return symbols
	end

	local sorted = {}
	for pattern, replacement in pairs(symbols) do
		-- Simple map format doesn't support boundary, use default
		table.insert(sorted, { pattern = pattern, replacement = replacement })
	end
	table.sort(sorted, function(a, b)
		return #a.pattern > #b.pattern
	end)

	return sorted
end

---Find all symbol matches in a line
---@param line string
---@param symbols table<string, string>|table[]
---@return table[] List of {col, end_col, replacement}
function M.find_matches(line, symbols)
	local matches = {}

	if line == "" then
		return matches
	end

	-- Sort symbols by length (longest first) to handle overlapping patterns
	local sorted_symbols = normalize_symbols(symbols)
	if #sorted_symbols == 0 then
		return matches
	end

	-- Track which positions are already matched
	local matched_positions = {}

	for _, sym in ipairs(sorted_symbols) do
		local pattern = sym.pattern
		local replacement = sym.replacement
		local start_pos = 1

		while true do
			-- Use plain string find (not pattern matching)
			local match_start, match_end = line:find(pattern, start_pos, true)
			if not match_start then
				break
			end

			-- Check if this position is already matched
			local already_matched = false
			for pos = match_start, match_end do
				if matched_positions[pos] then
					already_matched = true
					break
				end
			end

			if not already_matched then
				-- Check word boundaries for alphabetic patterns
				-- boundary option: "both" (default), "left", "right", "none"
				local boundary = sym.boundary or "both"
				local is_valid = true
				local check_left = boundary == "both" or boundary == "left"
				local check_right = boundary == "both" or boundary == "right"

				if check_left and pattern:match("^%a") then
					-- Pattern starts with letter - check left boundary
					-- Note: _ and ^ are math operators (subscript/superscript), not word chars
					if match_start > 1 then
						local char_before = line:sub(match_start - 1, match_start - 1)
						if char_before:match("[%w]") then
							is_valid = false
						end
					end
				end

				if is_valid and check_right and pattern:match("%a$") then
					-- Pattern ends with letter - check right boundary
					-- Note: _ is kept here since sum_ without boundary=left shouldn't match
					if match_end < #line then
						local char_after = line:sub(match_end + 1, match_end + 1)
						if char_after:match("[%w_]") then
							is_valid = false
						end
					end
				end

				if is_valid then
					-- Mark positions as matched
					for pos = match_start, match_end do
						matched_positions[pos] = true
					end

					-- Store match (convert to 0-indexed columns)
					table.insert(matches, {
						col = match_start - 1,
						end_col = match_end,
						pattern = pattern,
						replacement = replacement,
					})
				end
			end

			start_pos = match_end + 1
		end
	end

	-- Sort matches by column position
	table.sort(matches, function(a, b)
		return a.col < b.col
	end)

	return matches
end

---Prettify a single line
---@param buf integer
---@param row integer 0-indexed
---@param line string
---@param symbols table[] Sorted symbols list
---@param pred? fun(ctx: sigil.MatchContext): boolean
function M.prettify_line(buf, row, line, symbols, pred)
	local matches = M.find_matches(line, symbols)

	for _, match in ipairs(matches) do
		-- Check predicate if provided
		local should_prettify = true
		if pred then
			---@type sigil.MatchContext
			local ctx = {
				buf = buf,
				row = row,
				col = match.col,
				end_col = match.end_col,
				pattern = match.pattern,
				replacement = match.replacement,
			}
			should_prettify = pred(ctx)
		end

		if should_prettify then
			extmark.create(buf, row, match.col, match.end_col, match.replacement)
		end
	end
end

---Prettify a range of lines
---@param buf integer
---@param start_row integer 0-indexed
---@param end_row integer 0-indexed, exclusive
---@param opts? { clear?: boolean }
function M.prettify_lines(buf, start_row, end_row, opts)
	opts = opts or {}

	if not state.is_enabled(buf) then
		return
	end

	local ft = vim.bo[buf].filetype
	local symbols = config.get_sorted_symbols(ft)

	local line_count = vim.api.nvim_buf_line_count(buf)
	start_row = math.max(0, math.min(start_row, line_count))
	end_row = math.max(start_row, math.min(end_row, line_count))

	if opts.clear ~= false then
		-- Clear existing marks in range
		state.clear_lines(buf, start_row, end_row)
	end

	if end_row <= start_row or #symbols == 0 then
		return
	end

	-- Get predicate (custom, filetype-specific, or default)
	local pred = config.get_predicate(ft)

	-- Get lines
	local lines = vim.api.nvim_buf_get_lines(buf, start_row, end_row, false)

	for i, line in ipairs(lines) do
		local row = start_row + i - 1
		M.prettify_line(buf, row, line, symbols, pred)
	end
end

---Prettify entire buffer
---@param buf integer
function M.prettify_buffer(buf)
	if not state.is_enabled(buf) then
		return
	end

	local line_count = vim.api.nvim_buf_line_count(buf)
	M.prettify_lines(buf, 0, line_count)
end

---Refresh buffer (clear and re-prettify)
---@param buf integer
function M.refresh(buf)
	local line_count = vim.api.nvim_buf_line_count(buf)
	state.clear_lines(buf, 0, line_count)
	M.prettify_lines(buf, 0, line_count, { clear = false })
end

return M
