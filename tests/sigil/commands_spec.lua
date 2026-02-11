-- Tests for sigil commands and public API (Phase 5)
describe("sigil commands", function()
	local sigil
	local state
	local config
	local prettify
	local buf

	local test_symbols = {
		["->"] = "→",
		["lambda"] = "λ",
	}

	before_each(function()
		-- Clear module cache
		package.loaded["sigil"] = nil
		package.loaded["sigil.config"] = nil
		package.loaded["sigil.state"] = nil
		package.loaded["sigil.extmark"] = nil
		package.loaded["sigil.prettify"] = nil
		package.loaded["sigil.manager"] = nil
		package.loaded["sigil.motions"] = nil
		package.loaded["sigil.visual"] = nil
		package.loaded["sigil.unprettify"] = nil

		sigil = require("sigil")
		state = require("sigil.state")
		config = require("sigil.config")
		prettify = require("sigil.prettify")

		-- Create a test buffer with filetype
		buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(buf)
		vim.bo[buf].filetype = "lua"

		-- Setup with test symbols
		config.setup({
			symbols = test_symbols,
			filetypes = { "lua" },
		})
	end)

	after_each(function()
		-- Cleanup buffer state
		if state.is_attached(buf) then
			state.detach(buf)
		end
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end)

	describe(":Sigil toggle command", function()
		it("should disable when enabled", function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x -> y" })
			state.attach(buf)
			prettify.prettify_buffer(buf)

			-- Verify initially enabled
			assert.is_true(state.is_enabled(buf))

			-- Toggle off
			sigil.toggle(buf)

			-- Should be disabled
			assert.is_false(state.is_enabled(buf))
		end)

		it("should enable when disabled", function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x -> y" })
			state.attach(buf)
			state.disable(buf)

			assert.is_false(state.is_enabled(buf))

			-- Toggle on
			sigil.toggle(buf)

			assert.is_true(state.is_enabled(buf))
		end)

		it("should clear extmarks when toggling off", function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x -> y" })
			state.attach(buf)
			prettify.prettify_buffer(buf)

			local marks_before = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, {})
			assert.is_true(#marks_before > 0)

			-- Toggle off
			sigil.toggle(buf)

			local marks_after = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, {})
			assert.equals(0, #marks_after)
		end)

		it("should restore extmarks when toggling on", function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x -> y" })
			state.attach(buf)
			prettify.prettify_buffer(buf)

			-- Toggle off then on
			sigil.toggle(buf)
			sigil.toggle(buf)

			local marks = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, {})
			assert.is_true(#marks > 0)
		end)
	end)

	describe(":SigilEnable command", function()
		it("should enable prettification on attached buffer", function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x -> y" })
			state.attach(buf)
			state.disable(buf)

			assert.is_false(state.is_enabled(buf))

			sigil.enable(buf)

			assert.is_true(state.is_enabled(buf))
		end)

		it("should create extmarks when enabling", function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "lambda x -> y" })
			state.attach(buf)
			state.disable(buf)

			local marks_disabled = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, {})
			assert.equals(0, #marks_disabled)

			sigil.enable(buf)

			local marks_enabled = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, {})
			assert.is_true(#marks_enabled > 0)
		end)

		it("should be idempotent when already enabled", function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x -> y" })
			state.attach(buf)
			prettify.prettify_buffer(buf)

			local marks_before = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, {})
			assert.is_true(state.is_enabled(buf))

			-- Enable again
			sigil.enable(buf)

			assert.is_true(state.is_enabled(buf))
			local marks_after = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, {})
			assert.is_true(#marks_after > 0)
		end)
	end)

	describe(":SigilDisable command", function()
		it("should disable prettification", function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x -> y" })
			state.attach(buf)
			prettify.prettify_buffer(buf)

			assert.is_true(state.is_enabled(buf))

			sigil.disable(buf)

			assert.is_false(state.is_enabled(buf))
		end)

		it("should clear all extmarks", function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "lambda x -> y" })
			state.attach(buf)
			prettify.prettify_buffer(buf)

			local marks_before = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, {})
			assert.is_true(#marks_before > 0)

			sigil.disable(buf)

			local marks_after = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, {})
			assert.equals(0, #marks_after)
		end)

		it("should be idempotent when already disabled", function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x -> y" })
			state.attach(buf)
			state.disable(buf)

			-- Disable again should not error
			sigil.disable(buf)

			assert.is_false(state.is_enabled(buf))
		end)
	end)

	describe("public API", function()
		describe("sigil.enable()", function()
			it("should accept buffer argument", function()
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x -> y" })
				state.attach(buf)
				state.disable(buf)

				sigil.enable(buf)

				assert.is_true(state.is_enabled(buf))
			end)
		end)

		describe("sigil.disable()", function()
			it("should accept buffer argument", function()
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x -> y" })
				state.attach(buf)

				sigil.disable(buf)

				assert.is_false(state.is_enabled(buf))
			end)
		end)

		describe("sigil.toggle()", function()
			it("should toggle state each call", function()
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x -> y" })
				state.attach(buf)
				prettify.prettify_buffer(buf)

				assert.is_true(state.is_enabled(buf))

				sigil.toggle(buf)
				assert.is_false(state.is_enabled(buf))

				sigil.toggle(buf)
				assert.is_true(state.is_enabled(buf))

				sigil.toggle(buf)
				assert.is_false(state.is_enabled(buf))
			end)
		end)

		describe("sigil.refresh()", function()
			it("should re-prettify buffer content", function()
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x -> y" })
				state.attach(buf)
				prettify.prettify_buffer(buf)

				-- Manually clear extmarks
				vim.api.nvim_buf_clear_namespace(buf, state.ns, 0, -1)
				local marks_cleared = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, {})
				assert.equals(0, #marks_cleared)

				-- Refresh should re-create them
				sigil.refresh(buf)

				local marks_refreshed = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, {})
				assert.is_true(#marks_refreshed > 0)
			end)

			it("should handle changed content after refresh", function()
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x -> y" })
				state.attach(buf)
				prettify.prettify_buffer(buf)

				-- Change buffer content
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "lambda -> x -> y" })

				-- Refresh should match new content
				sigil.refresh(buf)

				local marks = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, { details = true })
				-- Should have 3 symbols: lambda, ->, ->
				assert.equals(3, #marks)
			end)
		end)

		describe("sigil.get_config()", function()
			it("should return current config", function()
				sigil.setup({ symbols = test_symbols })

				local cfg = sigil.get_config()
				assert.is_not_nil(cfg)
				assert.equals("→", cfg.symbols["->"])
				assert.equals("λ", cfg.symbols["lambda"])
			end)

			it("should reflect setup options", function()
				sigil.setup({
					symbols = test_symbols,
					conceal_cursor = "nc",
					skip_strings = false,
				})

				local cfg = sigil.get_config()
				assert.equals("nc", cfg.conceal_cursor)
				assert.is_false(cfg.skip_strings)
			end)
		end)

		describe("sigil.setup()", function()
			it("should initialize plugin", function()
				sigil.setup({ symbols = test_symbols })
				assert.is_true(sigil._initialized)
			end)

			it("should not reinitialize on empty opts", function()
				sigil.setup({ symbols = test_symbols })
				assert.is_true(sigil._initialized)

				-- Call again with no opts
				sigil.setup()
				-- Should still be initialized
				assert.is_true(sigil._initialized)
			end)
		end)
	end)

	describe("enable/disable cycle", function()
		it("should preserve buffer content through cycles", function()
			local content = { "lambda x -> y", "a != b" }
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
			state.attach(buf)
			prettify.prettify_buffer(buf)

			-- Cycle enable/disable multiple times
			sigil.disable(buf)
			sigil.enable(buf)
			sigil.disable(buf)
			sigil.enable(buf)

			-- Buffer content should be unchanged
			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			assert.equals(content[1], lines[1])
			assert.equals(content[2], lines[2])
		end)

		it("should have extmarks only when enabled", function()
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x -> y" })
			state.attach(buf)
			prettify.prettify_buffer(buf)

			-- Enabled: has marks
			assert.is_true(#vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, {}) > 0)

			-- Disable: no marks
			sigil.disable(buf)
			assert.equals(0, #vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, {}))

			-- Enable: marks restored
			sigil.enable(buf)
			assert.is_true(#vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, {}) > 0)
		end)
	end)
end)
