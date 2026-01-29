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

	describe("update", function()
		it("should hide symbol when cursor is on it", function()
			-- Set buffer content with a pattern
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local f = lambda x -> x" })

			-- Prettify the buffer
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

			-- Call update
			unprettify.update(buf)

			-- Get extmarks after
			local marks_after = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, { details = true })

			-- Lambda extmark should now have no virt_text (unprettified)
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
			local state_after = unprettify._state[buf]
			assert.is_not_nil(state_after)

			-- Move cursor away (to beginning of line)
			vim.api.nvim_win_set_cursor(0, { 1, 0 })
			unprettify.update(buf)

			-- Verify restored
			local state_restored = unprettify._state[buf]
			assert.is_nil(state_restored)

			-- Check extmark has virt_text again
			local marks = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, { details = true })
			local lambda_mark = marks[1]
			assert.is_not_nil(lambda_mark[4].virt_text)
			assert.equals("λ", lambda_mark[4].virt_text[1][1])
		end)

		it("should do nothing when unprettify_at_point is disabled", function()
			-- Disable unprettify
			config.current.unprettify_at_point = nil

			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local f = lambda x -> x" })
			prettify.prettify_buffer(buf)

			-- Move cursor to lambda
			vim.api.nvim_win_set_cursor(0, { 1, 10 })
			unprettify.update(buf)

			-- Verify no state change (nothing unprettified)
			local state_after = unprettify._state[buf]
			assert.is_nil(state_after)
		end)

		it("should switch between symbols correctly", function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local f = lambda x -> x" })
			prettify.prettify_buffer(buf)

			-- Move to lambda
			vim.api.nvim_win_set_cursor(0, { 1, 10 })
			unprettify.update(buf)

			local state1 = unprettify._state[buf]
			assert.is_not_nil(state1)
			assert.equals("λ", state1.replacement)

			-- Move to -> (col 19)
			vim.api.nvim_win_set_cursor(0, { 1, 19 })
			unprettify.update(buf)

			local state2 = unprettify._state[buf]
			assert.is_not_nil(state2)
			assert.equals("→", state2.replacement)

			-- Verify lambda is restored
			local marks = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, { details = true })
			local lambda_mark = marks[1]
			assert.is_not_nil(lambda_mark[4].virt_text)
			assert.equals("λ", lambda_mark[4].virt_text[1][1])
		end)
	end)

	describe("right-edge mode", function()
		before_each(function()
			config.current.unprettify_at_point = "right-edge"
		end)

		it("should not unprettify when cursor is at symbol start", function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local f = lambda x -> x" })
			prettify.prettify_buffer(buf)

			-- Move cursor to start of lambda (col 10)
			vim.api.nvim_win_set_cursor(0, { 1, 10 })
			unprettify.update(buf)

			-- Should not unprettify because cursor is at start
			local state_after = unprettify._state[buf]
			assert.is_nil(state_after)
		end)

		it("should unprettify when cursor is past symbol start", function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local f = lambda x -> x" })
			prettify.prettify_buffer(buf)

			-- Move cursor inside lambda (col 11, one past start)
			vim.api.nvim_win_set_cursor(0, { 1, 11 })
			unprettify.update(buf)

			-- Should unprettify
			local state_after = unprettify._state[buf]
			assert.is_not_nil(state_after)
			assert.equals("λ", state_after.replacement)
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
	end)
end)
