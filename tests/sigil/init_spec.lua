-- Tests for sigil main module
describe("sigil", function()
	local sigil

	before_each(function()
		-- Reset all module state
		package.loaded["sigil"] = nil
		package.loaded["sigil.config"] = nil
		package.loaded["sigil.state"] = nil
		package.loaded["sigil.prettify"] = nil
		package.loaded["sigil.extmark"] = nil
		package.loaded["sigil.manager"] = nil

		sigil = require("sigil")
	end)

	describe("setup", function()
		it("should initialize plugin", function()
			sigil.setup({})
			assert.is_true(sigil._initialized)
		end)

		it("should merge user config", function()
			sigil.setup({
				symbols = {
					["custom"] = "C",
					["lambda"] = "λ",
				},
			})

			local config = sigil.get_config()
			assert.equals("C", config.symbols["custom"])
			assert.equals("λ", config.symbols["lambda"])
		end)
	end)

	describe("api", function()
		it("should have enable function", function()
			assert.is_function(sigil.enable)
		end)

		it("should have disable function", function()
			assert.is_function(sigil.disable)
		end)

		it("should have toggle function", function()
			assert.is_function(sigil.toggle)
		end)

		it("should have refresh function", function()
			assert.is_function(sigil.refresh)
		end)

		it("should have get_config function", function()
			assert.is_function(sigil.get_config)
		end)
	end)
end)
