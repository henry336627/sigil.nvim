-- sigil.nvim - Context detection helpers (e.g. math)

local predicate = require("sigil.predicate")

local M = {}

---Get Tree-sitter node at position (compat across versions)
---@param buf integer
---@param row integer
---@param col integer
---@return any|nil
local function get_node(buf, row, col)
	local ok, node = pcall(vim.treesitter.get_node, { bufnr = buf, pos = { row, col } })
	if ok and node then
		return node
	end

	local ok2, node2 = pcall(vim.treesitter.get_node_at_pos, buf, row, col)
	if ok2 and node2 then
		return node2
	end

	return nil
end

---Get node type safely
---@param node any
---@return string|nil
local function node_type(node)
	if not node then
		return nil
	end

	local ok, t = pcall(function()
		return node:type()
	end)

	if ok then
		return t
	end

	return nil
end

---Check if treesitter tree is actually parsed and ready
---@param buf integer
---@return boolean
local function is_tree_ready(buf)
	local ok, parser = pcall(vim.treesitter.get_parser, buf)
	if not ok or not parser then
		return false
	end
	-- Check if the tree exists and has been parsed
	local trees = parser:trees()
	return trees and #trees > 0
end

---Check math context for Typst using Tree-sitter
---@param buf integer
---@param row integer
---@param col integer
---@return boolean
local function typst_in_math(buf, row, col)
	local has_ts = predicate.has_treesitter(buf)

	-- If treesitter parser exists but tree isn't ready yet, use fallback
	if has_ts and not is_tree_ready(buf) then
		has_ts = false
	end

	if has_ts then
		local captures = predicate.get_ts_captures(buf, row, col)
		for _, cap in ipairs(captures) do
			if cap:find("math") or cap == "markup.math" then
				return true
			end
		end

		local node = get_node(buf, row, col)
		if node then
			local in_math = false
			local in_string = false

			while node do
				local t = node_type(node)
				if t == "string" then
					in_string = true
				end
				if t == "math" or t == "equation" then
					in_math = true
				end
				node = node:parent()
			end

			return in_math and not in_string
		end
	end

	-- Fallback to syntax group name
	local ok, group = pcall(predicate.get_syntax_group, buf, row, col)
	if ok and group then
		local g = group:lower()
		if g:find("math") or g:find("equation") then
			return true
		end
	end

	-- If treesitter isn't ready, don't prettify math_only symbols
	-- (better to show nothing than show in wrong context)
	return false
end

---Check math context for LaTeX using Tree-sitter (fallback to syntax)
---@param buf integer
---@param row integer
---@param col integer
---@return boolean
local function latex_in_math(buf, row, col)
	if predicate.has_treesitter(buf) and is_tree_ready(buf) then
		local captures = predicate.get_ts_captures(buf, row, col)
		for _, cap in ipairs(captures) do
			if cap:find("math") or cap == "markup.math" then
				return true
			end
		end

		local node = get_node(buf, row, col)
		local in_math = false

		while node do
			local t = node_type(node)
			if t and t:lower():find("comment") then
				return false
			end
			if t and (t:lower():find("math") or t:lower():find("equation")) then
				in_math = true
			end
			node = node:parent()
		end

		if in_math then
			return true
		end
	end

	local ok, group = pcall(predicate.get_syntax_group, buf, row, col)
	if ok and group then
		local g = group:lower()
		if g:find("math") or g:find("equation") then
			return true
		end
	end

	return false
end

---Determine if position is inside a math context for the buffer filetype
---@param ctx sigil.MatchContext
---@return boolean
function M.in_math(ctx)
	local buf = ctx.buf
	local row = ctx.row
	local col = ctx.col
	local ft = vim.bo[buf].filetype

	if ft == "typst" then
		return typst_in_math(buf, row, col)
	end

	if ft == "tex" or ft == "plaintex" or ft == "latex" then
		return latex_in_math(buf, row, col)
	end

	return false
end

return M
