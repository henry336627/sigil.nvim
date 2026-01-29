-- Performance tests for sigil.nvim
-- These tests verify that operations complete within acceptable time bounds

describe("sigil performance", function()
	local benchmark
	local config
	local manager
	local state
	local prettify

	-- Test symbols
	local test_symbols = {
		["lambda"] = "\206\187",
		["->"] = "\226\134\146",
		["!="] = "\226\137\160",
		["<="] = "\226\137\164",
		[">="] = "\226\137\165",
		["alpha"] = "\206\177",
		["beta"] = "\206\178",
	}

	-- Time thresholds (ms) - generous to avoid flaky tests on slow CI
	local THRESHOLDS = {
		small_file_attach = 100, -- 100 lines
		medium_file_attach = 500, -- 1000 lines
		large_file_attach = 1000, -- 10000 lines (with lazy loading)
		line_prettify = 5, -- Single line
		find_matches = 2, -- Pattern matching on one line
	}

	before_each(function()
		-- Reset modules
		package.loaded["sigil.benchmark"] = nil
		package.loaded["sigil.prettify"] = nil
		package.loaded["sigil.config"] = nil
		package.loaded["sigil.state"] = nil
		package.loaded["sigil.manager"] = nil
		package.loaded["sigil.extmark"] = nil

		benchmark = require("sigil.benchmark")
		config = require("sigil.config")
		manager = require("sigil.manager")
		state = require("sigil.state")
		prettify = require("sigil.prettify")

		config.setup({
			symbols = test_symbols,
			filetypes = { "lua" },
			lazy_prettify_threshold = 500,
		})
	end)

	describe("find_matches", function()
		it("should complete within threshold for typical line", function()
			local line = "lambda -> x != y <= z >= w alpha beta"

			local stats = benchmark.benchmark(function()
				prettify.find_matches(line, test_symbols)
			end, 100)

			assert.is_true(
				stats.avg < THRESHOLDS.find_matches,
				string.format(
					"find_matches avg %.3fms exceeds threshold %.3fms",
					stats.avg,
					THRESHOLDS.find_matches
				)
			)
		end)

		it("should scale reasonably with line length", function()
			local short_line = "lambda -> x"
			local long_line = string.rep("lambda -> x != y ", 20)

			local short_stats = benchmark.benchmark(function()
				prettify.find_matches(short_line, test_symbols)
			end, 50)

			local long_stats = benchmark.benchmark(function()
				prettify.find_matches(long_line, test_symbols)
			end, 50)

			-- Long line should not be more than 50x slower (allowing for overhead)
			local ratio = long_stats.avg / short_stats.avg
			assert.is_true(ratio < 50, string.format("Long line ratio %.1fx exceeds acceptable limit", ratio))
		end)
	end)

	describe("attach performance", function()
		local function create_test_buffer(line_count, symbols_per_line)
			-- Use non-scratch buffer (second param false) so manager.attach() doesn't skip it
			local buf = vim.api.nvim_create_buf(true, false)
			local lines = benchmark.generate_test_lines(line_count, symbols_per_line)
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
			vim.bo[buf].filetype = "lua"
			return buf
		end

		it("should attach to small file within threshold", function()
			local buf = create_test_buffer(100, 3)

			local elapsed = benchmark.profile_attach(buf)

			assert.is_true(
				elapsed < THRESHOLDS.small_file_attach,
				string.format(
					"Small file attach %.2fms exceeds threshold %dms",
					elapsed,
					THRESHOLDS.small_file_attach
				)
			)

			manager.detach(buf)
			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("should attach to medium file within threshold", function()
			local buf = create_test_buffer(1000, 3)

			local elapsed = benchmark.profile_attach(buf)

			assert.is_true(
				elapsed < THRESHOLDS.medium_file_attach,
				string.format(
					"Medium file attach %.2fms exceeds threshold %dms",
					elapsed,
					THRESHOLDS.medium_file_attach
				)
			)

			manager.detach(buf)
			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("should attach to large file within threshold (lazy loading)", function()
			local buf = create_test_buffer(10000, 3)

			local elapsed = benchmark.profile_attach(buf)

			assert.is_true(
				elapsed < THRESHOLDS.large_file_attach,
				string.format(
					"Large file attach %.2fms exceeds threshold %dms",
					elapsed,
					THRESHOLDS.large_file_attach
				)
			)

			-- Verify lazy loading: not all lines should have extmarks
			local marks = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, {})
			-- With 3 symbols per line and 10000 lines, full would be ~30000 marks
			-- Lazy should be much less (visible range only)
			assert.is_true(
				#marks < 5000,
				string.format("Expected lazy loading, but got %d extmarks (should be < 5000)", #marks)
			)

			-- Verify lazy mode is active
			assert.is_true(state.is_lazy_mode(buf), "Lazy mode should be active for large files")

			manager.detach(buf)
			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("should not use lazy mode for small files", function()
			local buf = create_test_buffer(100, 3)

			-- Manually set up state and prettify (bypassing manager.attach's filetype check)
			state.attach(buf)
			prettify.prettify_buffer(buf)

			-- Small file should not be in lazy mode
			assert.is_false(state.is_lazy_mode(buf), "Lazy mode should not be active for small files")

			-- Verify buffer is attached and enabled
			assert.is_true(state.is_attached(buf), "Buffer should be attached")
			assert.is_true(state.is_enabled(buf), "Buffer should be enabled")

			-- Check that symbols are configured
			local symbols = config.get_sorted_symbols("lua")
			assert.is_true(#symbols > 0, string.format("Should have symbols configured, got %d", #symbols))

			-- All symbols should be prettified
			local marks = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, {})
			-- 100 lines * 3 symbols = 300 marks expected
			assert.is_true(#marks >= 200, string.format("Expected ~300 extmarks, got %d", #marks))

			state.detach(buf)
			vim.api.nvim_buf_delete(buf, { force = true })
		end)
	end)

	describe("incremental update", function()
		it("should update single line quickly", function()
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
				"lambda -> x",
				"alpha beta",
				"test line",
			})
			vim.bo[buf].filetype = "lua"
			state.attach(buf)
			prettify.prettify_buffer(buf)

			-- Simulate line change
			local stats = benchmark.benchmark(function()
				state.clear_lines(buf, 1, 2)
				prettify.prettify_lines(buf, 1, 2, { clear = false })
			end, 50)

			assert.is_true(
				stats.avg < THRESHOLDS.line_prettify,
				string.format("Line update avg %.3fms exceeds threshold %dms", stats.avg, THRESHOLDS.line_prettify)
			)

			state.detach(buf)
			vim.api.nvim_buf_delete(buf, { force = true })
		end)
	end)

	describe("memory efficiency", function()
		it("should not leak extmarks after detach", function()
			-- Use non-scratch buffer
			local buf = vim.api.nvim_create_buf(true, false)
			local lines = benchmark.generate_test_lines(100, 3)
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
			vim.bo[buf].filetype = "lua"

			-- Manually attach and prettify
			state.attach(buf)
			prettify.prettify_buffer(buf)

			local marks_after_attach = #vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, {})
			assert.is_true(marks_after_attach > 0, "Should have extmarks after attach")

			state.detach(buf)
			local marks_after_detach = #vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, {})
			assert.equals(0, marks_after_detach, "Should have no extmarks after detach")

			vim.api.nvim_buf_delete(buf, { force = true })
		end)
	end)

	describe("state range tracking", function()
		it("should correctly merge adjacent ranges", function()
			local buf = vim.api.nvim_create_buf(false, true)
			state.attach(buf)
			state.enable_lazy_mode(buf)

			state.mark_prettified(buf, 0, 10)
			state.mark_prettified(buf, 10, 20)

			-- Should merge into one range
			local unprettified = state.get_unprettified_in_range(buf, 0, 20)
			assert.equals(0, #unprettified, "Merged ranges should cover full area")

			state.detach(buf)
			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("should correctly identify gaps", function()
			local buf = vim.api.nvim_create_buf(false, true)
			state.attach(buf)
			state.enable_lazy_mode(buf)

			state.mark_prettified(buf, 0, 10)
			state.mark_prettified(buf, 20, 30)

			-- Gap between 10-20 should be identified
			local unprettified = state.get_unprettified_in_range(buf, 0, 30)
			assert.equals(1, #unprettified)
			assert.equals(10, unprettified[1][1])
			assert.equals(20, unprettified[1][2])

			state.detach(buf)
			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("should handle range adjustments for line deletions", function()
			local buf = vim.api.nvim_create_buf(false, true)
			state.attach(buf)
			state.enable_lazy_mode(buf)

			state.mark_prettified(buf, 0, 100)

			-- Simulate deleting 10 lines at position 50
			state.adjust_ranges_for_edit(buf, 50, 10, 0)

			-- Range should now be 0-90 (shrunk by 10)
			local unprettified = state.get_unprettified_in_range(buf, 0, 90)
			assert.equals(0, #unprettified, "Range should still cover 0-90 after deletion")

			state.detach(buf)
			vim.api.nvim_buf_delete(buf, { force = true })
		end)
	end)
end)
