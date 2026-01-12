-- Tests for sigil.prettify module
describe("sigil.prettify", function()
	local prettify
	local config

	before_each(function()
		package.loaded["sigil.prettify"] = nil
		package.loaded["sigil.config"] = nil
		package.loaded["sigil.state"] = nil
		package.loaded["sigil.extmark"] = nil

		prettify = require("sigil.prettify")
		config = require("sigil.config")
		config.setup({})
	end)

	describe("find_matches", function()
		it("should find single symbol", function()
			local matches = prettify.find_matches("lambda", config.default.symbols)

			assert.equals(1, #matches)
			assert.equals(0, matches[1].col)
			assert.equals(6, matches[1].end_col)
			assert.equals("λ", matches[1].replacement)
		end)

		it("should find multiple symbols on same line", function()
			local matches = prettify.find_matches("lambda -> x", config.default.symbols)

			assert.equals(2, #matches)
			-- First match: lambda
			assert.equals("λ", matches[1].replacement)
			-- Second match: ->
			assert.equals("→", matches[2].replacement)
		end)

		it("should respect word boundaries for alphabetic patterns", function()
			local matches = prettify.find_matches("xlambda lambday", config.default.symbols)

			-- Neither should match (lambda is part of larger word)
			assert.equals(0, #matches)
		end)

		it("should match standalone word", function()
			local matches = prettify.find_matches("x lambda y", config.default.symbols)

			assert.equals(1, #matches)
			assert.equals("λ", matches[1].replacement)
		end)

		it("should handle operator symbols without word boundary", function()
			local matches = prettify.find_matches("x->y", config.default.symbols)

			assert.equals(1, #matches)
			assert.equals("→", matches[1].replacement)
		end)

		it("should handle multiple occurrences", function()
			local matches = prettify.find_matches("x -> y -> z", config.default.symbols)

			assert.equals(2, #matches)
			assert.equals("→", matches[1].replacement)
			assert.equals("→", matches[2].replacement)
		end)

		it("should prefer longer matches", function()
			local symbols = {
				["="] = "≡",
				["=>"] = "⇒",
			}
			local matches = prettify.find_matches("x => y", symbols)

			assert.equals(1, #matches)
			assert.equals("⇒", matches[1].replacement)
		end)

		it("should not overlap matches", function()
			local symbols = {
				["->"] = "→",
				[">"] = "›",
			}
			local matches = prettify.find_matches("x -> y", symbols)

			-- Should only match -> not both -> and >
			assert.equals(1, #matches)
			assert.equals("→", matches[1].replacement)
		end)

		it("should handle empty line", function()
			local matches = prettify.find_matches("", config.default.symbols)
			assert.equals(0, #matches)
		end)

		it("should handle line with no matches", function()
			local matches = prettify.find_matches("hello world", config.default.symbols)
			assert.equals(0, #matches)
		end)
	end)

	describe("prettify_buffer", function()
		local state

		before_each(function()
			state = require("sigil.state")
			-- Setup buffer
			vim.api.nvim_buf_set_lines(0, 0, -1, false, {
				"lambda -> x",
				"y != z",
			})
			state.attach(0)
		end)

		after_each(function()
			state.detach(0)
		end)

		it("should create extmarks for matches", function()
			prettify.prettify_buffer(0)

			local marks = vim.api.nvim_buf_get_extmarks(0, state.ns, 0, -1, { details = true })
			assert.is_true(#marks > 0)
		end)

		it("should create correct conceal values", function()
			prettify.prettify_buffer(0)

			local marks = vim.api.nvim_buf_get_extmarks(0, state.ns, 0, -1, { details = true })

			local replacements = {}
			for _, mark in ipairs(marks) do
				local details = mark[4]
				-- Check virt_text (overlay mode) or conceal (legacy mode)
				local replacement
				if details.virt_text and #details.virt_text > 0 then
					replacement = details.virt_text[1][1]
				else
					replacement = details.conceal
				end
				table.insert(replacements, replacement)
			end

			assert.is_true(vim.tbl_contains(replacements, "λ"))
			assert.is_true(vim.tbl_contains(replacements, "→"))
			assert.is_true(vim.tbl_contains(replacements, "≠"))
		end)
	end)
end)
