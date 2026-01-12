-- Tests for sigil.motions module
describe("sigil.motions", function()
	local motions
	local config
	local state
	local prettify
	local buf

	before_each(function()
		-- Clear module cache
		package.loaded["sigil.motions"] = nil
		package.loaded["sigil.config"] = nil
		package.loaded["sigil.state"] = nil
		package.loaded["sigil.extmark"] = nil
		package.loaded["sigil.prettify"] = nil

		motions = require("sigil.motions")
		config = require("sigil.config")
		state = require("sigil.state")
		prettify = require("sigil.prettify")

		config.setup({})

		-- Use current buffer
		buf = vim.api.nvim_get_current_buf()
	end)

	after_each(function()
		-- Cleanup buffer state
		if state.is_attached(buf) then
			state.detach(buf)
		end
	end)

	describe("get_symbol_at", function()
		before_each(function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x -> y" })
			state.attach(buf)
			prettify.prettify_buffer(buf)
		end)

		it("should return nil when not on a symbol", function()
			-- Position 0 is 'x', not on a symbol
			local symbol = motions.get_symbol_at(buf, 0, 0)
			assert.is_nil(symbol)
		end)

		it("should return symbol info when on a symbol", function()
			-- Position 2 is start of '->'
			local symbol = motions.get_symbol_at(buf, 0, 2)

			assert.is_not_nil(symbol)
			assert.equals(2, symbol.start_col)
			assert.equals(4, symbol.end_col)
			assert.equals("→", symbol.replacement)
		end)

		it("should return symbol info when inside a symbol", function()
			-- Position 3 is inside '->'
			local symbol = motions.get_symbol_at(buf, 0, 3)

			assert.is_not_nil(symbol)
			assert.equals(2, symbol.start_col)
			assert.equals(4, symbol.end_col)
		end)

		it("should return nil when sigil is disabled", function()
			state.disable(buf)
			local symbol = motions.get_symbol_at(buf, 0, 2)
			assert.is_nil(symbol)
		end)
	end)

	describe("get_next_symbol", function()
		before_each(function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x -> y -> z" })
			state.attach(buf)
			prettify.prettify_buffer(buf)
		end)

		it("should find next symbol after position", function()
			-- After 'x', next symbol is '->' at col 2
			local symbol = motions.get_next_symbol(buf, 0, 0)

			assert.is_not_nil(symbol)
			assert.equals(2, symbol.start_col)
		end)

		it("should find second symbol when past first", function()
			-- After first '->' (col 4), next symbol is second '->' at col 7
			local symbol = motions.get_next_symbol(buf, 0, 4)

			assert.is_not_nil(symbol)
			assert.equals(7, symbol.start_col)
		end)

		it("should return nil when no more symbols", function()
			-- After second '->' at col 9, no more symbols
			local symbol = motions.get_next_symbol(buf, 0, 9)
			assert.is_nil(symbol)
		end)
	end)

	describe("get_prev_symbol", function()
		before_each(function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x -> y -> z" })
			state.attach(buf)
			prettify.prettify_buffer(buf)
		end)

		it("should find previous symbol before position", function()
			-- Before 'z' (col 10), prev symbol is second '->' ending at col 9
			local symbol = motions.get_prev_symbol(buf, 0, 10)

			assert.is_not_nil(symbol)
			assert.equals(7, symbol.start_col)
		end)

		it("should return nil when no previous symbols", function()
			-- At col 0, no previous symbols
			local symbol = motions.get_prev_symbol(buf, 0, 0)
			assert.is_nil(symbol)
		end)
	end)

	describe("move_right", function()
		before_each(function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x -> y" })
			state.attach(buf)
			prettify.prettify_buffer(buf)
		end)

		it("should skip over symbol when cursor is on it", function()
			-- Start on '->' at col 2
			vim.api.nvim_win_set_cursor(0, { 1, 2 })
			motions.move_right()

			local cursor = vim.api.nvim_win_get_cursor(0)
			-- Should be at col 4 (after '->'), which is space before 'y'
			assert.equals(4, cursor[2])
		end)

		it("should skip over symbol when cursor is inside it", function()
			-- Start inside '->' at col 3 (on '>')
			vim.api.nvim_win_set_cursor(0, { 1, 3 })
			motions.move_right()

			local cursor = vim.api.nvim_win_get_cursor(0)
			-- Should be at col 4 (after '->')
			assert.equals(4, cursor[2])
		end)

		it("should move normally when not on symbol", function()
			-- Start at col 0 ('x')
			vim.api.nvim_win_set_cursor(0, { 1, 0 })
			motions.move_right()

			local cursor = vim.api.nvim_win_get_cursor(0)
			-- Should be at col 1 (space)
			assert.equals(1, cursor[2])
		end)

		it("should move normally to symbol start when before symbol", function()
			-- Start at col 1 (space before '->')
			vim.api.nvim_win_set_cursor(0, { 1, 1 })
			motions.move_right()

			local cursor = vim.api.nvim_win_get_cursor(0)
			-- Should be at col 2 (start of '->'), NOT col 4
			assert.equals(2, cursor[2])
		end)
	end)

	describe("move_left", function()
		before_each(function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x -> y" })
			state.attach(buf)
			prettify.prettify_buffer(buf)
		end)

		it("should skip to start of symbol when inside it", function()
			-- Start inside '->' at col 3
			vim.api.nvim_win_set_cursor(0, { 1, 3 })
			motions.move_left()

			local cursor = vim.api.nvim_win_get_cursor(0)
			-- Should be at col 2 (start of '->')
			assert.equals(2, cursor[2])
		end)

		it("should skip over symbol when immediately after it", function()
			-- Start at col 4 (space after '->')
			vim.api.nvim_win_set_cursor(0, { 1, 4 })
			motions.move_left()

			local cursor = vim.api.nvim_win_get_cursor(0)
			-- Should be at col 2 (start of '->')
			assert.equals(2, cursor[2])
		end)

		it("should move normally when not near symbol", function()
			-- Start at col 5 ('y')
			vim.api.nvim_win_set_cursor(0, { 1, 5 })
			motions.move_left()

			local cursor = vim.api.nvim_win_get_cursor(0)
			-- Should be at col 4 (space before 'y')
			assert.equals(4, cursor[2])
		end)
	end)

	describe("keymaps", function()
		it("should setup keymaps for buffer", function()
			motions.setup_keymaps(buf)

			-- Check that keymaps exist
			local keymaps = vim.api.nvim_buf_get_keymap(buf, "n")
			local has_l = false
			local has_h = false

			for _, map in ipairs(keymaps) do
				if map.lhs == "l" then
					has_l = true
				end
				if map.lhs == "h" then
					has_h = true
				end
			end

			assert.is_true(has_l, "l keymap should be set")
			assert.is_true(has_h, "h keymap should be set")

			-- Cleanup
			motions.remove_keymaps(buf)
		end)

		it("should remove keymaps from buffer", function()
			motions.setup_keymaps(buf)
			motions.remove_keymaps(buf)

			local keymaps = vim.api.nvim_buf_get_keymap(buf, "n")
			local has_l = false
			local has_h = false

			for _, map in ipairs(keymaps) do
				if map.lhs == "l" then
					has_l = true
				end
				if map.lhs == "h" then
					has_h = true
				end
			end

			assert.is_false(has_l, "l keymap should be removed")
			assert.is_false(has_h, "h keymap should be removed")
		end)
	end)
end)
