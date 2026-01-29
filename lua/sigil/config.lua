-- sigil.nvim - Configuration module

local M = {}

---@class sigil.ConfigCache
---@field symbols table<string, table<string, string>>
---@field sorted_symbols table<string, table[]>
---@field predicates table<string, fun(ctx: sigil.MatchContext): boolean>

---@class sigil.Config
---@field enabled boolean Enable prettify-symbols
---@field symbols table<string, string> Global symbol mappings
---@field filetype_symbols table<string, table<string, string>> Per-filetype symbols
---@field filetypes string[]|"*" Filetypes to enable (or "*" for all)
---@field excluded_filetypes string[] Filetypes to exclude
---@field conceal_cursor string Modes where cursor line stays concealed
---@field update_debounce_ms integer Debounce for incremental updates (ms)
---@field predicate? fun(ctx: sigil.MatchContext): boolean Global predicate function
---@field filetype_predicates? table<string, fun(ctx: sigil.MatchContext): boolean> Per-filetype predicates
---@field skip_strings? boolean Skip prettification inside strings (default: true)
---@field skip_comments? boolean Skip prettification inside comments (default: true)
---@field atomic_motions? boolean Treat prettified symbols as single chars for h/l (default: true)
---@field filetype_symbol_contexts? table<string, { math_only?: string[], text_only?: string[] }> Context-specific symbols
---@field filetype_context_predicates? table<string, fun(ctx: sigil.MatchContext): boolean> Per-filetype context predicate (e.g. math)
---@field unprettify_at_point? boolean|"right-edge" Show original text when cursor is on prettified symbol

---Default configuration
---@type sigil.Config
M.default = {
	enabled = true,
	symbols = {},
	filetype_symbols = {},
	filetypes = {},
	excluded_filetypes = {},
	conceal_cursor = "nvic", -- all modes: normal, visual, insert, command
	update_debounce_ms = 30,
	-- Predicate options
	predicate = nil, -- custom global predicate (overrides skip_strings/skip_comments)
	filetype_predicates = {}, -- per-filetype custom predicates
	skip_strings = true, -- skip prettification inside strings
	skip_comments = true, -- skip prettification inside comments
	atomic_motions = true, -- treat prettified symbols as single chars for h/l
	filetype_symbol_contexts = {}, -- per-filetype context-specific symbol lists
	filetype_context_predicates = {}, -- per-filetype context predicate (e.g. math)
	unprettify_at_point = nil, -- nil/false: disabled, true: show when cursor on symbol, "right-edge": show when cursor past start
}

---@type sigil.ConfigCache
M._cache = {
	symbols = {},
	sorted_symbols = {},
	predicates = {},
}

---Current merged configuration
---@type sigil.Config
M.current = vim.deepcopy(M.default)

---Merge user config with defaults
---@param opts? sigil.Config
function M.setup(opts)
	M.current = vim.tbl_deep_extend("force", vim.deepcopy(M.default), opts or {})
	M._cache = {
		symbols = {},
		sorted_symbols = {},
		predicates = {},
	}
end

---Check if symbols table is in list format (array of objects with pattern field)
---@param symbols table
---@return boolean
local function is_list_format(symbols)
	return symbols[1] ~= nil and type(symbols[1]) == "table" and symbols[1].pattern ~= nil
end

---Normalize symbols from either format to list format
---@param symbols table Map or list format
---@return table[] List of {pattern, replacement, boundary?}
local function normalize_symbols(symbols)
	if is_list_format(symbols) then
		return symbols
	end

	local result = {}
	for pattern, replacement in pairs(symbols) do
		table.insert(result, { pattern = pattern, replacement = replacement })
	end
	return result
end

---Get symbols for a specific filetype (returns map format for backward compat)
---@param ft string
---@return table<string, string>
function M.get_symbols(ft)
	if M._cache.symbols[ft] then
		return M._cache.symbols[ft]
	end

	local symbols = {}

	-- Add global symbols
	local global = normalize_symbols(M.current.symbols)
	for _, sym in ipairs(global) do
		symbols[sym.pattern] = sym.replacement
	end

	-- Merge filetype-specific symbols
	local ft_symbols = M.current.filetype_symbols[ft]
	if ft_symbols then
		local ft_normalized = normalize_symbols(ft_symbols)
		for _, sym in ipairs(ft_normalized) do
			symbols[sym.pattern] = sym.replacement
		end
	end

	M._cache.symbols[ft] = symbols
	return symbols
end

---Get sorted symbols list for a filetype (preserves boundary and other options)
---@param ft string
---@return table[] List of {pattern, replacement, boundary?}
function M.get_sorted_symbols(ft)
	if M._cache.sorted_symbols[ft] then
		return M._cache.sorted_symbols[ft]
	end

	local sorted = {}

	-- Add global symbols
	local global = normalize_symbols(M.current.symbols)
	for _, sym in ipairs(global) do
		table.insert(sorted, vim.deepcopy(sym))
	end

	-- Merge filetype-specific symbols (override by pattern)
	local ft_symbols = M.current.filetype_symbols[ft]
	if ft_symbols then
		local ft_normalized = normalize_symbols(ft_symbols)
		-- Build a map of existing patterns for quick lookup
		local pattern_idx = {}
		for i, sym in ipairs(sorted) do
			pattern_idx[sym.pattern] = i
		end
		-- Add or replace filetype symbols
		for _, sym in ipairs(ft_normalized) do
			local idx = pattern_idx[sym.pattern]
			if idx then
				sorted[idx] = vim.deepcopy(sym)
			else
				table.insert(sorted, vim.deepcopy(sym))
			end
		end
	end

	-- Sort by pattern length (longest first)
	table.sort(sorted, function(a, b)
		return #a.pattern > #b.pattern
	end)

	M._cache.sorted_symbols[ft] = sorted
	return sorted
end

---Check if filetype should be prettified
---@param ft string
---@return boolean
function M.is_enabled_for_filetype(ft)
	-- Check excluded filetypes
	if vim.tbl_contains(M.current.excluded_filetypes, ft) then
		return false
	end

	-- Check if all filetypes enabled
	if M.current.filetypes == "*" then
		return true
	end

	-- Check specific filetypes
	return vim.tbl_contains(M.current.filetypes, ft)
end

---Get predicate function for filetype
---@param ft string
---@return fun(ctx: sigil.MatchContext): boolean
function M.get_predicate(ft)
	if M._cache.predicates[ft] then
		return M._cache.predicates[ft]
	end

	local base_pred = nil

	-- Check for filetype-specific predicate
	local ft_pred = M.current.filetype_predicates and M.current.filetype_predicates[ft]
	if ft_pred then
		base_pred = ft_pred
	end

	-- Check for global custom predicate
	if not base_pred and M.current.predicate then
		base_pred = M.current.predicate
	end

	-- Build default predicate based on skip_strings/skip_comments
	if not base_pred then
		local predicate = require("sigil.predicate")
		base_pred = predicate.create({
			skip_strings = M.current.skip_strings,
			skip_comments = M.current.skip_comments,
		})
	end

	local context_spec = M.current.filetype_symbol_contexts and M.current.filetype_symbol_contexts[ft]
	if not context_spec then
		M._cache.predicates[ft] = base_pred
		return base_pred
	end

	local math_list = context_spec.math_only or context_spec.math or {}
	local text_list = context_spec.text_only or context_spec.text or {}

	if #math_list == 0 and #text_list == 0 then
		M._cache.predicates[ft] = base_pred
		return base_pred
	end

	local math_set = {}
	for _, key in ipairs(math_list) do
		math_set[key] = true
	end

	local text_set = {}
	for _, key in ipairs(text_list) do
		text_set[key] = true
	end

	local context_pred = nil
	if M.current.filetype_context_predicates then
		context_pred = M.current.filetype_context_predicates[ft]
	end
	if not context_pred then
		context_pred = require("sigil.context").in_math
	end

	local pred = function(ctx)
		if base_pred and not base_pred(ctx) then
			return false
		end

		local pattern = ctx.pattern
		if math_set[pattern] or text_set[pattern] then
			local in_context = context_pred(ctx)
			if math_set[pattern] and not in_context then
				return false
			end
			if text_set[pattern] and in_context then
				return false
			end
		end

		return true
	end

	M._cache.predicates[ft] = pred
	return pred
end

return M
