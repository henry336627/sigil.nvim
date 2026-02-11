-- Tests for sigil.nvim unprettify at point module

local unprettify = require("sigil.unprettify")
local config = require("sigil.config")
local state = require("sigil.state")
local prettify = require("sigil.prettify")

describe("sigil.unprettify", function()
	local buf

	before_each(function()
		-- Create a test buffer
		buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(buf)
		vim.bo[buf].filetype = "lua"

		-- Setup config with unprettify enabled
		config.setup({
			enabled = true,
			symbols = {
				["lambda"] = "λ",
				["->"] = "→",
			},
			filetypes = { "lua" },
			unprettify_at_point = true,
		})

		-- Attach state
		state.attach(buf)
	end)

	after_each(function()
		-- Cleanup: clear unprettify first (while extmarks still exist)
		unprettify.clear(buf)
		state.detach(buf)
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end)

	describe("symbol mode (true)", function()
		it("should hide symbol when cursor is on it", function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local f = lambda x -> x" })
			prettify.prettify_buffer(buf)

			-- Get extmarks before
			local marks_before = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, { details = true })
			assert.equals(2, #marks_before) -- lambda and ->

			-- Check that lambda has virt_text
			local lambda_mark = marks_before[1]
			assert.is_not_nil(lambda_mark[4].virt_text)
			assert.equals("λ", lambda_mark[4].virt_text[1][1])

			-- Move cursor to lambda position (col 10)
			vim.api.nvim_win_set_cursor(0, { 1, 10 })
			unprettify.update(buf)

			-- Lambda extmark should now have no virt_text (unprettified)
			local marks_after = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, { details = true })
			local lambda_after = marks_after[1]
			assert.is_nil(lambda_after[4].virt_text)
		end)

		it("should restore symbol when cursor moves away", function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local f = lambda x -> x" })
			prettify.prettify_buffer(buf)

			-- Move cursor to lambda
			vim.api.nvim_win_set_cursor(0, { 1, 10 })
			unprettify.update(buf)

			-- Verify unprettified
			assert.is_not_nil(unprettify._state[buf])

			-- Move cursor away (to beginning of line)
			vim.api.nvim_win_set_cursor(0, { 1, 0 })
			unprettify.update(buf)

			-- Verify restored
			assert.is_nil(unprettify._state[buf])

			-- Check extmark has virt_text again
			local marks = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, { details = true })
			local lambda_mark = marks[1]
			assert.is_not_nil(lambda_mark[4].virt_text)
			assert.equals("λ", lambda_mark[4].virt_text[1][1])
		end)

		it("should do nothing when unprettify_at_point is disabled", function()
			config.current.unprettify_at_point = nil

			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local f = lambda x -> x" })
			prettify.prettify_buffer(buf)

			vim.api.nvim_win_set_cursor(0, { 1, 10 })
			unprettify.update(buf)

			assert.is_nil(unprettify._state[buf])
		end)

		it("should switch between symbols correctly", function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local f = lambda x -> x" })
			prettify.prettify_buffer(buf)

			-- Move to lambda
			vim.api.nvim_win_set_cursor(0, { 1, 10 })
			unprettify.update(buf)

			local state1 = unprettify._state[buf]
			assert.is_not_nil(state1)
			assert.equals("symbol", state1.mode)
			assert.equals("λ", state1.symbols[1].replacement)

			-- Move to -> (col 19)
			vim.api.nvim_win_set_cursor(0, { 1, 19 })
			unprettify.update(buf)

			local state2 = unprettify._state[buf]
			assert.is_not_nil(state2)
			assert.equals("→", state2.symbols[1].replacement)

			-- Verify lambda is restored
			local marks = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, { details = true })
			local lambda_mark = marks[1]
			assert.is_not_nil(lambda_mark[4].virt_text)
			assert.equals("λ", lambda_mark[4].virt_text[1][1])
		end)

		it("should only unprettify symbol under cursor, not others", function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local f = lambda x -> x" })
			prettify.prettify_buffer(buf)

			-- Move cursor to lambda (col 10)
			vim.api.nvim_win_set_cursor(0, { 1, 10 })
			unprettify.update(buf)

			-- Lambda should be unprettified, -> should stay prettified
			local marks = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, { details = true })
			local lambda_mark = marks[1]
			local arrow_mark = marks[2]

			assert.is_nil(lambda_mark[4].virt_text) -- unprettified
			assert.is_not_nil(arrow_mark[4].virt_text) -- still prettified
			assert.equals("→", arrow_mark[4].virt_text[1][1])
		end)
	end)

	describe("line mode", function()
		before_each(function()
			config.current.unprettify_at_point = "line"
		end)

		it("should unprettify all symbols on cursor line", function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local f = lambda x -> x" })
			prettify.prettify_buffer(buf)

			-- Move cursor anywhere on the line
			vim.api.nvim_win_set_cursor(0, { 1, 0 })
			unprettify.update(buf)

			-- Both symbols should be unprettified
			local marks = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, { details = true })
			for _, mark in ipairs(marks) do
				assert.is_nil(mark[4].virt_text)
			end

			-- State should track all symbols
			local st = unprettify._state[buf]
			assert.is_not_nil(st)
			assert.equals("line", st.mode)
			assert.equals(2, #st.symbols)
		end)

		it("should restore all symbols when moving to different line", function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
				"local f = lambda x -> x",
				"local y = 42",
			})
			prettify.prettify_buffer(buf)

			-- Move to first line
			vim.api.nvim_win_set_cursor(0, { 1, 0 })
			unprettify.update(buf)

			-- Both symbols unprettified
			assert.is_not_nil(unprettify._state[buf])

			-- Move to second line (no symbols)
			vim.api.nvim_win_set_cursor(0, { 2, 0 })
			unprettify.update(buf)

			-- State should be cleared
			assert.is_nil(unprettify._state[buf])

			-- First line symbols should be restored
			local marks = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, { details = true })
			for _, mark in ipairs(marks) do
				assert.is_not_nil(mark[4].virt_text)
			end
		end)

		it("should switch between lines correctly", function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
				"lambda x -> x",
				"lambda y -> y",
			})
			prettify.prettify_buffer(buf)

			-- Move to first line
			vim.api.nvim_win_set_cursor(0, { 1, 0 })
			unprettify.update(buf)

			local st1 = unprettify._state[buf]
			assert.is_not_nil(st1)
			assert.equals(0, st1.row)

			-- Move to second line
			vim.api.nvim_win_set_cursor(0, { 2, 0 })
			unprettify.update(buf)

			local st2 = unprettify._state[buf]
			assert.is_not_nil(st2)
			assert.equals(1, st2.row)

			-- First line symbols should be restored
			local marks_line1 = vim.api.nvim_buf_get_extmarks(buf, state.ns, { 0, 0 }, { 0, -1 }, { details = true })
			for _, mark in ipairs(marks_line1) do
				assert.is_not_nil(mark[4].virt_text)
			end

			-- Second line symbols should be unprettified
			local marks_line2 = vim.api.nvim_buf_get_extmarks(buf, state.ns, { 1, 0 }, { 1, -1 }, { details = true })
			for _, mark in ipairs(marks_line2) do
				assert.is_nil(mark[4].virt_text)
			end
		end)

		it("should handle line with no symbols", function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local y = 42" })
			prettify.prettify_buffer(buf)

			vim.api.nvim_win_set_cursor(0, { 1, 0 })
			unprettify.update(buf)

			-- No state because no symbols on line
			assert.is_nil(unprettify._state[buf])
		end)

		it("should not affect symbols on other lines", function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
				"lambda x -> x",
				"lambda y -> y",
			})
			prettify.prettify_buffer(buf)

			-- Move to first line
			vim.api.nvim_win_set_cursor(0, { 1, 0 })
			unprettify.update(buf)

			-- Second line symbols should remain prettified
			local marks_line2 = vim.api.nvim_buf_get_extmarks(buf, state.ns, { 1, 0 }, { 1, -1 }, { details = true })
			for _, mark in ipairs(marks_line2) do
				assert.is_not_nil(mark[4].virt_text)
			end
		end)
	end)

	describe("clear", function()
		it("should restore symbol and clear state", function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local f = lambda x -> x" })
			prettify.prettify_buffer(buf)

			-- Unprettify lambda
			vim.api.nvim_win_set_cursor(0, { 1, 10 })
			unprettify.update(buf)

			assert.is_not_nil(unprettify._state[buf])

			-- Clear
			unprettify.clear(buf)

			-- State should be nil
			assert.is_nil(unprettify._state[buf])

			-- Symbol should be restored
			local marks = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, { details = true })
			local lambda_mark = marks[1]
			assert.is_not_nil(lambda_mark[4].virt_text)
		end)

		it("should restore all line-mode symbols and clear state", function()
			config.current.unprettify_at_point = "line"

			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local f = lambda x -> x" })
			prettify.prettify_buffer(buf)

			vim.api.nvim_win_set_cursor(0, { 1, 0 })
			unprettify.update(buf)

			assert.is_not_nil(unprettify._state[buf])
			assert.equals(2, #unprettify._state[buf].symbols)

			-- Clear
			unprettify.clear(buf)

			assert.is_nil(unprettify._state[buf])

			-- All symbols should be restored
			local marks = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, { details = true })
			for _, mark in ipairs(marks) do
				assert.is_not_nil(mark[4].virt_text)
			end
		end)
	end)
end)
