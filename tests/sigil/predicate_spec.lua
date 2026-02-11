-- Tests for sigil.predicate module
describe("sigil.predicate", function()
	local predicate

	before_each(function()
		package.loaded["sigil.predicate"] = nil
		predicate = require("sigil.predicate")
		predicate.clear_cache()
	end)

	describe("create", function()
		it("should create predicate with default options", function()
			local pred = predicate.create({})
			assert.is_function(pred)
		end)

		it("should create predicate that can be called", function()
			local pred = predicate.create({ skip_strings = false, skip_comments = false })
			local ctx = {
				buf = 0,
				row = 0,
				col = 0,
				end_col = 6,
				pattern = "lambda",
				replacement = "λ",
			}
			-- With skip_strings=false and skip_comments=false, should return true
			local result = pred(ctx)
			assert.is_true(result)
		end)
	end)

	describe("always", function()
		it("should always return true", function()
			local ctx = {
				buf = 0,
				row = 0,
				col = 0,
				end_col = 6,
				pattern = "lambda",
				replacement = "λ",
			}
			assert.is_true(predicate.always(ctx))
		end)
	end)

	describe("never", function()
		it("should always return false", function()
			local ctx = {
				buf = 0,
				row = 0,
				col = 0,
				end_col = 6,
				pattern = "lambda",
				replacement = "λ",
			}
			assert.is_false(predicate.never(ctx))
		end)
	end)

	describe("has_treesitter", function()
		it("should return boolean", function()
			local result = predicate.has_treesitter(0)
			assert.is_boolean(result)
		end)

		it("should cache results", function()
			-- First call
			predicate.has_treesitter(0)
			-- Second call should use cache (we can't directly test this, but it shouldn't error)
			local result = predicate.has_treesitter(0)
			assert.is_boolean(result)
		end)
	end)

	describe("clear_cache", function()
		it("should clear the Tree-sitter cache", function()
			predicate.has_treesitter(0)
			predicate.clear_cache()
			-- Should work without error after cache clear
			local result = predicate.has_treesitter(0)
			assert.is_boolean(result)
		end)
	end)
end)

-- Integration tests with prettify
describe("sigil.prettify with predicates", function()
	local prettify
	local config
	local state
	local predicate

	-- Test symbols (not dependent on default config)
	local test_symbols = {
		["lambda"] = "λ",
		["->"] = "→",
	}

	before_each(function()
		package.loaded["sigil.prettify"] = nil
		package.loaded["sigil.config"] = nil
		package.loaded["sigil.state"] = nil
		package.loaded["sigil.extmark"] = nil
		package.loaded["sigil.predicate"] = nil

		prettify = require("sigil.prettify")
		config = require("sigil.config")
		state = require("sigil.state")
		predicate = require("sigil.predicate")

		config.setup({ symbols = test_symbols })
	end)

	after_each(function()
		if state.is_attached(0) then
			state.detach(0)
		end
	end)

	describe("prettify_line with predicate", function()
		it("should skip matches when predicate returns false", function()
			vim.api.nvim_buf_set_lines(0, 0, -1, false, { "lambda -> x" })
			state.attach(0)

			-- Use predicate that always returns false
			prettify.prettify_line(0, 0, "lambda -> x", test_symbols, predicate.never)

			local marks = vim.api.nvim_buf_get_extmarks(0, state.ns, 0, -1, { details = true })
			assert.equals(0, #marks)
		end)

		it("should prettify all matches when predicate returns true", function()
			vim.api.nvim_buf_set_lines(0, 0, -1, false, { "lambda -> x" })
			state.attach(0)

			-- Use predicate that always returns true
			prettify.prettify_line(0, 0, "lambda -> x", test_symbols, predicate.always)

			local marks = vim.api.nvim_buf_get_extmarks(0, state.ns, 0, -1, { details = true })
			assert.is_true(#marks >= 2) -- lambda and ->
		end)

		it("should pass correct context to predicate", function()
			vim.api.nvim_buf_set_lines(0, 0, -1, false, { "lambda" })
			state.attach(0)

			local received_ctx = nil
			local custom_pred = function(ctx)
				received_ctx = ctx
				return true
			end

			prettify.prettify_line(0, 0, "lambda", test_symbols, custom_pred)

			assert.is_not_nil(received_ctx)
			assert.equals(0, received_ctx.buf)
			assert.equals(0, received_ctx.row)
			assert.equals(0, received_ctx.col)
			assert.equals(6, received_ctx.end_col)
			assert.equals("lambda", received_ctx.pattern)
			assert.equals("λ", received_ctx.replacement)
		end)

		it("should filter selectively based on predicate", function()
			vim.api.nvim_buf_set_lines(0, 0, -1, false, { "lambda -> x" })
			state.attach(0)

			-- Predicate that only allows arrows
			local only_arrows = function(ctx)
				return ctx.pattern == "->"
			end

			prettify.prettify_line(0, 0, "lambda -> x", test_symbols, only_arrows)

			local marks = vim.api.nvim_buf_get_extmarks(0, state.ns, 0, -1, { details = true })
			assert.equals(1, #marks)
			-- Check virt_text (overlay mode) or conceal (legacy mode)
			local details = marks[1][4]
			local replacement
			if details.virt_text and #details.virt_text > 0 then
				replacement = details.virt_text[1][1]
			else
				replacement = details.conceal
			end
			assert.equals("→", replacement)
		end)
	end)
end)

-- Config integration tests
describe("sigil.config predicates", function()
	local config
	local predicate

	before_each(function()
		package.loaded["sigil.config"] = nil
		package.loaded["sigil.predicate"] = nil

		config = require("sigil.config")
		predicate = require("sigil.predicate")
	end)

	describe("get_predicate", function()
		it("should return default predicate when no custom predicate set", function()
			config.setup({})
			local pred = config.get_predicate("lua")
			assert.is_function(pred)
		end)

		it("should return custom global predicate when set", function()
			local custom = function()
				return false
			end
			config.setup({ predicate = custom })
			local pred = config.get_predicate("lua")
			assert.equals(custom, pred)
		end)

		it("should return filetype-specific predicate when set", function()
			local lua_pred = function()
				return true
			end
			config.setup({
				filetype_predicates = {
					lua = lua_pred,
				},
			})
			local pred = config.get_predicate("lua")
			assert.equals(lua_pred, pred)
		end)

		it("should prefer filetype predicate over global", function()
			local global_pred = function()
				return false
			end
			local lua_pred = function()
				return true
			end
			config.setup({
				predicate = global_pred,
				filetype_predicates = {
					lua = lua_pred,
				},
			})
			local pred = config.get_predicate("lua")
			assert.equals(lua_pred, pred)

			-- Other filetypes should use global
			local other_pred = config.get_predicate("python")
			assert.equals(global_pred, other_pred)
		end)

		it("should respect skip_strings option", function()
			config.setup({ skip_strings = false, skip_comments = true })
			local pred = config.get_predicate("lua")
			assert.is_function(pred)
		end)

		it("should respect skip_comments option", function()
			config.setup({ skip_strings = true, skip_comments = false })
			local pred = config.get_predicate("lua")
			assert.is_function(pred)
		end)
	end)
end)

describe("sigil.config contexts", function()
	local config

	before_each(function()
		package.loaded["sigil.config"] = nil
		config = require("sigil.config")
	end)

	it("should respect math_only and text_only symbols with context predicate", function()
		config.setup({
			predicate = function()
				return true
			end,
			filetype_symbol_contexts = {
				lua = {
					math_only = { "->" },
					text_only = { "lambda" },
				},
			},
			filetype_context_predicates = {
				lua = function(ctx)
					return ctx.col == 0
				end,
			},
		})

		local pred = config.get_predicate("lua")

		local math_ctx = {
			buf = 0,
			row = 0,
			col = 0,
			end_col = 2,
			pattern = "->",
			replacement = "→",
		}
		assert.is_true(pred(math_ctx))

		math_ctx.col = 1
		assert.is_false(pred(math_ctx))

		local text_ctx = {
			buf = 0,
			row = 0,
			col = 0,
			end_col = 6,
			pattern = "lambda",
			replacement = "λ",
		}
		assert.is_false(pred(text_ctx))

		text_ctx.col = 1
		assert.is_true(pred(text_ctx))
	end)
end)

describe("sigil.config structured symbol subtables", function()
	local config

	before_each(function()
		package.loaded["sigil.config"] = nil
		config = require("sigil.config")
	end)

	it("should detect structured format and tag symbols with _context", function()
		config.setup({
			filetype_symbols = {
				typst = {
					math = {
						{ pattern = "alpha", replacement = "α", boundary = "left" },
						{ pattern = "sum", replacement = "∑", boundary = "left" },
					},
					text = {
						{ pattern = "emph", replacement = "𝑒", boundary = "left" },
					},
					any = {
						{ pattern = "->", replacement = "→" },
					},
				},
			},
		})

		local sorted = config.get_sorted_symbols("typst")
		-- All 4 symbols should be present
		assert.equals(4, #sorted)

		-- Build a lookup by pattern
		local by_pattern = {}
		for _, sym in ipairs(sorted) do
			by_pattern[sym.pattern] = sym
		end

		assert.equals("math", by_pattern["alpha"]._context)
		assert.equals("math", by_pattern["sum"]._context)
		assert.equals("text", by_pattern["emph"]._context)
		assert.is_nil(by_pattern["->"]._context)
	end)

	it("should filter math symbols based on context predicate", function()
		config.setup({
			predicate = function()
				return true
			end,
			filetype_symbols = {
				typst = {
					math = {
						{ pattern = "alpha", replacement = "α", boundary = "left" },
					},
					any = {
						{ pattern = "->", replacement = "→" },
					},
				},
			},
			filetype_context_predicates = {
				-- col == 0 means "in math context"
				typst = function(ctx)
					return ctx.col == 0
				end,
			},
		})

		local pred = config.get_predicate("typst")

		-- math symbol in math context (col=0) -> allowed
		assert.is_true(pred({
			buf = 0, row = 0, col = 0, end_col = 5,
			pattern = "alpha", replacement = "α",
		}))

		-- math symbol outside math context (col=1) -> blocked
		assert.is_false(pred({
			buf = 0, row = 0, col = 1, end_col = 6,
			pattern = "alpha", replacement = "α",
		}))

		-- any symbol in math context -> allowed
		assert.is_true(pred({
			buf = 0, row = 0, col = 0, end_col = 2,
			pattern = "->", replacement = "→",
		}))

		-- any symbol outside math context -> also allowed
		assert.is_true(pred({
			buf = 0, row = 0, col = 5, end_col = 7,
			pattern = "->", replacement = "→",
		}))
	end)

	it("should filter text symbols based on context predicate", function()
		config.setup({
			predicate = function()
				return true
			end,
			filetype_symbols = {
				typst = {
					text = {
						{ pattern = "emph", replacement = "𝑒", boundary = "left" },
					},
					any = {
						{ pattern = "->", replacement = "→" },
					},
				},
			},
			filetype_context_predicates = {
				typst = function(ctx)
					return ctx.col == 0
				end,
			},
		})

		local pred = config.get_predicate("typst")

		-- text symbol in math context (col=0) -> blocked
		assert.is_false(pred({
			buf = 0, row = 0, col = 0, end_col = 4,
			pattern = "emph", replacement = "𝑒",
		}))

		-- text symbol outside math context (col=1) -> allowed
		assert.is_true(pred({
			buf = 0, row = 0, col = 1, end_col = 5,
			pattern = "emph", replacement = "𝑒",
		}))
	end)

	it("should merge structured subtables with filetype_symbol_contexts", function()
		config.setup({
			predicate = function()
				return true
			end,
			filetype_symbols = {
				typst = {
					math = {
						{ pattern = "alpha", replacement = "α", boundary = "left" },
					},
					any = {
						{ pattern = "->", replacement = "→" },
						{ pattern = "beta", replacement = "β", boundary = "left" },
					},
				},
			},
			-- Legacy: also mark "beta" as math_only via filetype_symbol_contexts
			filetype_symbol_contexts = {
				typst = {
					math_only = { "beta" },
				},
			},
			filetype_context_predicates = {
				typst = function(ctx)
					return ctx.col == 0
				end,
			},
		})

		local pred = config.get_predicate("typst")

		-- "alpha" from structured math subtable: blocked outside math
		assert.is_false(pred({
			buf = 0, row = 0, col = 5, end_col = 10,
			pattern = "alpha", replacement = "α",
		}))

		-- "beta" from any subtable but overridden by filetype_symbol_contexts math_only:
		-- blocked outside math
		assert.is_false(pred({
			buf = 0, row = 0, col = 5, end_col = 9,
			pattern = "beta", replacement = "β",
		}))

		-- "beta" in math context -> allowed
		assert.is_true(pred({
			buf = 0, row = 0, col = 0, end_col = 4,
			pattern = "beta", replacement = "β",
		}))
	end)

	it("should still work with flat format", function()
		config.setup({
			filetype_symbols = {
				lua = {
					{ pattern = "lambda", replacement = "λ" },
					{ pattern = "->", replacement = "→" },
				},
			},
		})

		local sorted = config.get_sorted_symbols("lua")
		assert.equals(2, #sorted)

		-- No _context tags on flat format symbols
		for _, sym in ipairs(sorted) do
			assert.is_nil(sym._context)
		end
	end)

	it("should preserve boundary and other fields in structured format", function()
		config.setup({
			filetype_symbols = {
				typst = {
					math = {
						{ pattern = "alpha", replacement = "α", boundary = "left", hl_group = "Special" },
					},
				},
			},
		})

		local sorted = config.get_sorted_symbols("typst")
		assert.equals(1, #sorted)
		assert.equals("alpha", sorted[1].pattern)
		assert.equals("α", sorted[1].replacement)
		assert.equals("left", sorted[1].boundary)
		assert.equals("Special", sorted[1].hl_group)
		assert.equals("math", sorted[1]._context)
	end)

	it("should work with get_symbols for structured format", function()
		config.setup({
			filetype_symbols = {
				typst = {
					math = {
						{ pattern = "alpha", replacement = "α" },
					},
					any = {
						{ pattern = "->", replacement = "→" },
					},
				},
			},
		})

		local symbols = config.get_symbols("typst")
		assert.equals("α", symbols["alpha"])
		assert.equals("→", symbols["->"])
	end)
end)
