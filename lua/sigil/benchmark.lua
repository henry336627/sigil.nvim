-- sigil.nvim - Benchmarking utilities

local M = {}

---Generate test lines with symbols
---@param line_count integer
---@param symbols_per_line integer
---@return string[]
function M.generate_test_lines(line_count, symbols_per_line)
	local patterns = { "lambda", "->", "!=", "<=", ">=", "alpha", "beta" }
	local lines = {}

	for i = 1, line_count do
		local parts = {}
		for j = 1, symbols_per_line do
			local pattern = patterns[(i * j) % #patterns + 1]
			table.insert(parts, "x " .. pattern .. " y")
		end
		table.insert(lines, "-- " .. table.concat(parts, " "))
	end

	return lines
end

---Measure execution time with high precision
---@param fn function
---@param ... any
---@return number elapsed_ms
---@return any result
function M.time_it(fn, ...)
	local start = vim.uv.hrtime()
	local result = fn(...)
	local elapsed = vim.uv.hrtime() - start
	return elapsed / 1e6, result -- Convert to milliseconds
end

---Run benchmark multiple times and return statistics
---@param fn function
---@param iterations integer
---@param ... any
---@return { min: number, max: number, avg: number, median: number }
function M.benchmark(fn, iterations, ...)
	local times = {}

	for _ = 1, iterations do
		local elapsed = M.time_it(fn, ...)
		table.insert(times, elapsed)
	end

	table.sort(times)

	local sum = 0
	for _, t in ipairs(times) do
		sum = sum + t
	end

	return {
		min = times[1],
		max = times[#times],
		avg = sum / #times,
		median = times[math.ceil(#times / 2)],
	}
end

---Profile attach time for a buffer
---@param buf integer
---@return number ms
function M.profile_attach(buf)
	local manager = require("sigil.manager")
	local state = require("sigil.state")

	-- Ensure detached
	if state.is_attached(buf) then
		manager.detach(buf)
	end

	local elapsed = M.time_it(function()
		manager.attach(buf)
	end)

	return elapsed
end

---Profile scroll performance
---@param buf integer
---@param scroll_count integer
---@return { avg: number, max: number }
function M.profile_scroll(buf, scroll_count)
	local times = {}
	local wins = vim.fn.win_findbuf(buf)
	if #wins == 0 then
		return { avg = 0, max = 0 }
	end

	local win = wins[1]
	vim.api.nvim_set_current_win(win)

	for _ = 1, scroll_count do
		local start = vim.uv.hrtime()
		vim.cmd("normal! \\<C-d>")
		vim.cmd("redraw")
		local elapsed = (vim.uv.hrtime() - start) / 1e6
		table.insert(times, elapsed)
	end

	local sum, max_t = 0, 0
	for _, t in ipairs(times) do
		sum = sum + t
		max_t = math.max(max_t, t)
	end

	return { avg = sum / #times, max = max_t }
end

---Run full benchmark suite
---@param opts? { line_counts?: integer[], symbols_per_line?: integer }
---@return table[]
function M.run_suite(opts)
	opts = opts or {}
	local line_counts = opts.line_counts or { 100, 1000, 5000, 10000, 20000 }
	local symbols_per_line = opts.symbols_per_line or 3

	local results = {}
	local config = require("sigil.config")
	local manager = require("sigil.manager")
	local state = require("sigil.state")

	-- Setup config if not already done
	if not config.current.symbols or vim.tbl_isempty(config.current.symbols) then
		config.setup({
			symbols = {
				["lambda"] = "\206\187",
				["->"] = "\226\134\146",
				["!="] = "\226\137\160",
				["<="] = "\226\137\164",
				[">="] = "\226\137\165",
				["alpha"] = "\206\177",
				["beta"] = "\206\178",
			},
			filetypes = { "lua" },
		})
	end

	for _, line_count in ipairs(line_counts) do
		-- Create test buffer
		local buf = vim.api.nvim_create_buf(false, true)
		local lines = M.generate_test_lines(line_count, symbols_per_line)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.bo[buf].filetype = "lua"

		-- Profile attach
		local attach_time = M.profile_attach(buf)

		-- Count extmarks
		local marks = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, {})

		-- Cleanup
		manager.detach(buf)
		vim.api.nvim_buf_delete(buf, { force = true })

		table.insert(results, {
			lines = line_count,
			attach_ms = attach_time,
			extmarks = #marks,
		})
	end

	return results
end

---Print benchmark results
---@param results table[]
function M.print_results(results)
	print(string.format("%-10s %-12s %-10s", "Lines", "Attach (ms)", "Extmarks"))
	print(string.rep("-", 35))
	for _, r in ipairs(results) do
		print(string.format("%-10d %-12.2f %-10d", r.lines, r.attach_ms, r.extmarks))
	end
end

return M
