-- sigil.nvim - Core prettification logic

local config = require("sigil.config")
local state = require("sigil.state")
local extmark = require("sigil.extmark")
local predicate = require("sigil.predicate")

local M = {}

---Find all symbol matches in a line
---@param line string
---@param symbols table<string, string>
---@return table[] List of {col, end_col, replacement}
function M.find_matches(line, symbols)
	local matches = {}

	-- Sort symbols by length (longest first) to handle overlapping patterns
	local sorted_symbols = {}
	for pattern, replacement in pairs(symbols) do
		table.insert(sorted_symbols, { pattern = pattern, replacement = replacement })
	end
	table.sort(sorted_symbols, function(a, b)
		return #a.pattern > #b.pattern
	end)

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
				local is_valid = true

				if pattern:match("^%a") then
					-- Pattern starts with letter - check left boundary
					if match_start > 1 then
						local char_before = line:sub(match_start - 1, match_start - 1)
						if char_before:match("[%w_]") then
							is_valid = false
						end
					end
				end

				if is_valid and pattern:match("%a$") then
					-- Pattern ends with letter - check right boundary
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
---@param symbols table<string, string>
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
function M.prettify_lines(buf, start_row, end_row)
	if not state.is_enabled(buf) then
		return
	end

	local ft = vim.bo[buf].filetype
	local symbols = config.get_symbols(ft)

	if vim.tbl_isempty(symbols) then
		return
	end

	-- Get predicate (custom, filetype-specific, or default)
	local pred = config.get_predicate(ft)

	-- Clear existing marks in range
	state.clear_lines(buf, start_row, end_row)

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
	extmark.clear(buf)
	local buf_state = state.get(buf)
	if buf_state then
		buf_state.marks = {}
	end
	M.prettify_buffer(buf)
end

return M
