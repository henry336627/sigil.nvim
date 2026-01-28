-- sigil.nvim - Context-aware predicate system
-- Determines whether a match should be prettified based on context

local M = {}

---@class sigil.MatchContext
---@field buf integer Buffer number
---@field row integer 0-indexed row
---@field col integer 0-indexed column
---@field end_col integer 0-indexed end column
---@field pattern string Original pattern that matched
---@field replacement string Replacement character

-- Cache for Tree-sitter parser availability per filetype
local ts_available_cache = {}

---Check if Tree-sitter parser is available for buffer
---@param buf integer
---@return boolean
function M.has_treesitter(buf)
	local ft = vim.bo[buf].filetype
	if ft == "" then
		return false
	end

	-- Check cache
	if ts_available_cache[ft] ~= nil then
		return ts_available_cache[ft]
	end

	-- Try to get parser
	local ok, parser = pcall(vim.treesitter.get_parser, buf)
	local available = ok and parser ~= nil

	ts_available_cache[ft] = available
	return available
end

---Get Tree-sitter captures at position
---@param buf integer
---@param row integer 0-indexed
---@param col integer 0-indexed
---@return string[] List of capture names
function M.get_ts_captures(buf, row, col)
	local captures = {}

	local ok, result = pcall(vim.treesitter.get_captures_at_pos, buf, row, col)
	if ok and result then
		for _, capture in ipairs(result) do
			table.insert(captures, capture.capture)
		end
	end

	return captures
end

-- Common Tree-sitter capture names for strings and comments
local string_captures = {
	"string",
	"string.special",
	"string.escape",
	"string.regex",
	"character",
}

local comment_captures = {
	"comment",
	"comment.documentation",
}

-- Build sets for O(1) lookup
local string_capture_set = {}
for _, cap in ipairs(string_captures) do
	string_capture_set[cap] = true
end

local comment_capture_set = {}
for _, cap in ipairs(comment_captures) do
	comment_capture_set[cap] = true
end

---Check if capture matches any target (exact or prefix)
---@param cap string
---@param target_set table<string, boolean>
---@param targets string[]
---@return boolean
local function matches_capture(cap, target_set, targets)
	if target_set[cap] then
		return true
	end
	-- Check if capture is a sub-capture (e.g., "string.special" matches "string")
	for _, target in ipairs(targets) do
		if cap:sub(1, #target + 1) == target .. "." then
			return true
		end
	end
	return false
end

---Check if position is inside a string and/or comment using Tree-sitter (single query)
---@param buf integer
---@param row integer 0-indexed
---@param col integer 0-indexed
---@return boolean, boolean is_string, is_comment
function M.ts_in_string_or_comment(buf, row, col)
	local captures = M.get_ts_captures(buf, row, col)
	local is_string = false
	local is_comment = false

	for _, cap in ipairs(captures) do
		if not is_string and matches_capture(cap, string_capture_set, string_captures) then
			is_string = true
		end
		if not is_comment and matches_capture(cap, comment_capture_set, comment_captures) then
			is_comment = true
		end
		if is_string and is_comment then
			break
		end
	end

	return is_string, is_comment
end

---Check if position is inside a string using Tree-sitter
---@param buf integer
---@param row integer 0-indexed
---@param col integer 0-indexed
---@return boolean
function M.ts_in_string(buf, row, col)
	local is_string, _ = M.ts_in_string_or_comment(buf, row, col)
	return is_string
end

---Check if position is inside a comment using Tree-sitter
---@param buf integer
---@param row integer 0-indexed
---@param col integer 0-indexed
---@return boolean
function M.ts_in_comment(buf, row, col)
	local _, is_comment = M.ts_in_string_or_comment(buf, row, col)
	return is_comment
end

-- Syntax group patterns for strings and comments (fallback)
local syntax_string_patterns = {
	"string",
	"String",
	"Character",
	"Quote",
}

local syntax_comment_patterns = {
	"comment",
	"Comment",
	"Todo",
	"Note",
	"Fixme",
}

---Check if syntax group matches any pattern
---@param group string
---@param patterns string[]
---@return boolean
local function matches_syntax_pattern(group, patterns)
	local lower_group = group:lower()
	for _, pattern in ipairs(patterns) do
		if lower_group:find(pattern:lower()) then
			return true
		end
	end
	return false
end

---Get syntax group at position (for fallback)
---@param buf integer
---@param row integer 0-indexed
---@param col integer 0-indexed
---@return string Syntax group name
function M.get_syntax_group(buf, row, col)
	-- synID uses 1-indexed line and column
	local lnum = row + 1
	local vcol = col + 1

	-- Get the syntax ID at position (with translation for linked groups)
	local id = vim.fn.synID(lnum, vcol, 1)
	local trans_id = vim.fn.synIDtrans(id)

	return vim.fn.synIDattr(trans_id, "name")
end

---Check if position is inside a string using syntax API
---@param buf integer
---@param row integer 0-indexed
---@param col integer 0-indexed
---@return boolean
function M.syntax_in_string(buf, row, col)
	local group = M.get_syntax_group(buf, row, col)
	return matches_syntax_pattern(group, syntax_string_patterns)
end

---Check if position is inside a comment using syntax API
---@param buf integer
---@param row integer 0-indexed
---@param col integer 0-indexed
---@return boolean
function M.syntax_in_comment(buf, row, col)
	local group = M.get_syntax_group(buf, row, col)
	return matches_syntax_pattern(group, syntax_comment_patterns)
end

---Check if position is inside a string (auto-detects method)
---@param buf integer
---@param row integer 0-indexed
---@param col integer 0-indexed
---@return boolean
function M.in_string(buf, row, col)
	if M.has_treesitter(buf) then
		return M.ts_in_string(buf, row, col)
	else
		return M.syntax_in_string(buf, row, col)
	end
end

---Check if position is inside a comment (auto-detects method)
---@param buf integer
---@param row integer 0-indexed
---@param col integer 0-indexed
---@return boolean
function M.in_comment(buf, row, col)
	if M.has_treesitter(buf) then
		return M.ts_in_comment(buf, row, col)
	else
		return M.syntax_in_comment(buf, row, col)
	end
end

---Default predicate: skip strings and comments
---@param ctx sigil.MatchContext
---@return boolean true to prettify, false to skip
function M.default(ctx)
	-- Don't prettify inside strings
	if M.in_string(ctx.buf, ctx.row, ctx.col) then
		return false
	end

	-- Don't prettify inside comments
	if M.in_comment(ctx.buf, ctx.row, ctx.col) then
		return false
	end

	return true
end

---Create a predicate that only prettifies in specific contexts
---@param opts { skip_strings?: boolean, skip_comments?: boolean }
---@return fun(ctx: sigil.MatchContext): boolean
function M.create(opts)
	opts = opts or {}
	local skip_strings = opts.skip_strings ~= false -- default true
	local skip_comments = opts.skip_comments ~= false -- default true

	-- Fast path: skip nothing
	if not skip_strings and not skip_comments then
		return M.always
	end

	return function(ctx)
		-- Single Tree-sitter query for both checks
		if M.has_treesitter(ctx.buf) then
			local is_string, is_comment = M.ts_in_string_or_comment(ctx.buf, ctx.row, ctx.col)
			if skip_strings and is_string then
				return false
			end
			if skip_comments and is_comment then
				return false
			end
		else
			-- Fallback to syntax API (separate calls, but syntax is cheaper)
			if skip_strings and M.syntax_in_string(ctx.buf, ctx.row, ctx.col) then
				return false
			end
			if skip_comments and M.syntax_in_comment(ctx.buf, ctx.row, ctx.col) then
				return false
			end
		end
		return true
	end
end

---Always prettify (no filtering)
---@param _ sigil.MatchContext
---@return boolean
function M.always(_)
	return true
end

---Never prettify (disable all)
---@param _ sigil.MatchContext
---@return boolean
function M.never(_)
	return false
end

---Clear Tree-sitter availability cache
function M.clear_cache()
	ts_available_cache = {}
end

return M
