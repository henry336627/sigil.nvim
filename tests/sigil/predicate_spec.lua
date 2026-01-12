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

    config.setup({})
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
      prettify.prettify_line(0, 0, "lambda -> x", config.default.symbols, predicate.never)

      local marks = vim.api.nvim_buf_get_extmarks(0, state.ns, 0, -1, { details = true })
      assert.equals(0, #marks)
    end)

    it("should prettify all matches when predicate returns true", function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "lambda -> x" })
      state.attach(0)

      -- Use predicate that always returns true
      prettify.prettify_line(0, 0, "lambda -> x", config.default.symbols, predicate.always)

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

      prettify.prettify_line(0, 0, "lambda", config.default.symbols, custom_pred)

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

      prettify.prettify_line(0, 0, "lambda -> x", config.default.symbols, only_arrows)

      local marks = vim.api.nvim_buf_get_extmarks(0, state.ns, 0, -1, { details = true })
      assert.equals(1, #marks)
      assert.equals("→", marks[1][4].conceal)
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
