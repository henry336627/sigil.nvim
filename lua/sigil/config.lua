-- sigil.nvim - Configuration module

local M = {}

---@class sigil.Config
---@field enabled boolean Enable prettify-symbols
---@field symbols table<string, string> Global symbol mappings
---@field filetype_symbols table<string, table<string, string>> Per-filetype symbols
---@field filetypes string[]|"*" Filetypes to enable (or "*" for all)
---@field excluded_filetypes string[] Filetypes to exclude
---@field conceal_cursor string Modes where cursor line stays concealed
---@field predicate? fun(ctx: sigil.MatchContext): boolean Global predicate function
---@field filetype_predicates? table<string, fun(ctx: sigil.MatchContext): boolean> Per-filetype predicates
---@field skip_strings? boolean Skip prettification inside strings (default: true)
---@field skip_comments? boolean Skip prettification inside comments (default: true)
---@field atomic_motions? boolean Treat prettified symbols as single chars for h/l (default: true)

---Default configuration
---@type sigil.Config
M.default = {
	enabled = true,
	symbols = {
		-- Greek letters
		["lambda"] = "λ",
		["Lambda"] = "Λ",
		["alpha"] = "α",
		["beta"] = "β",
		["gamma"] = "γ",
		["delta"] = "δ",
		["pi"] = "π",
		-- Arrows
		["->"] = "→",
		["<-"] = "←",
		["=>"] = "⇒",
		["<=>"] = "⇔",
		-- Comparison
		["!="] = "≠",
		["~="] = "≠",
		["/="] = "≠",
		["<="] = "≤",
		[">="] = "≥",
		["=="] = "≡",
		-- Logic
		["&&"] = "∧",
		["||"] = "∨",
		["!"] = "¬",
		["not"] = "¬",
		-- Math
		["sqrt"] = "√",
		["sum"] = "∑",
		["prod"] = "∏",
		["inf"] = "∞",
		["..."] = "…",
		-- Sets
		["in"] = "∈",
		["nil"] = "∅",
		["null"] = "∅",
		["None"] = "∅",
	},
	filetype_symbols = {
		-- Lua-specific
		lua = {
			["function"] = "λ",
			["local"] = "ℓ",
		},
		-- Python-specific
		python = {
			["def"] = "λ",
			["True"] = "⊤",
			["False"] = "⊥",
		},
		-- Haskell-specific
		haskell = {
			["\\"] = "λ",
			["forall"] = "∀",
			["exists"] = "∃",
		},
	},
	filetypes = "*",
	excluded_filetypes = { "help", "qf", "netrw", "lazy", "mason" },
	conceal_cursor = "nvic", -- all modes: normal, visual, insert, command
	-- Predicate options
	predicate = nil, -- custom global predicate (overrides skip_strings/skip_comments)
	filetype_predicates = {}, -- per-filetype custom predicates
	skip_strings = true, -- skip prettification inside strings
	skip_comments = true, -- skip prettification inside comments
	atomic_motions = true, -- treat prettified symbols as single chars for h/l
}

---Current merged configuration
---@type sigil.Config
M.current = vim.deepcopy(M.default)

---Merge user config with defaults
---@param opts? sigil.Config
function M.setup(opts)
	M.current = vim.tbl_deep_extend("force", vim.deepcopy(M.default), opts or {})
end

---Get symbols for a specific filetype
---@param ft string
---@return table<string, string>
function M.get_symbols(ft)
	local symbols = vim.deepcopy(M.current.symbols)

	-- Merge filetype-specific symbols
	local ft_symbols = M.current.filetype_symbols[ft]
	if ft_symbols then
		symbols = vim.tbl_extend("force", symbols, ft_symbols)
	end

	return symbols
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
	-- Check for filetype-specific predicate
	local ft_pred = M.current.filetype_predicates and M.current.filetype_predicates[ft]
	if ft_pred then
		return ft_pred
	end

	-- Check for global custom predicate
	if M.current.predicate then
		return M.current.predicate
	end

	-- Build default predicate based on skip_strings/skip_comments
	local predicate = require("sigil.predicate")
	return predicate.create({
		skip_strings = M.current.skip_strings,
		skip_comments = M.current.skip_comments,
	})
end

return M
