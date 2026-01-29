-- Phase 7: Unprettify at Point
-- Demonstrates showing original text when cursor is on a prettified symbol.

-- Setup instructions:
-- 1. Open this file in Neovim
-- 2. Run: :lua require("sigil").setup({ filetypes = { "lua" }, unprettify_at_point = true })
-- 3. Run: :set conceallevel=2
-- 4. Move cursor onto the prettified symbols below

-- Test patterns:
local arrow_func = function(x) return x end --> should show original "->" when cursor is on the arrow
local lambda_test = "lambda" --> shows original "lambda" when cursor is on it

-- Try these cursor movements:
-- 1. Move cursor to the arrow (→) - original "->" should appear
-- 2. Move cursor away - arrow should be prettified again (→)
-- 3. Move to "lambda" (λ) - original text appears
-- 4. Move away - prettified again

-- Configuration options:
--
-- unprettify_at_point = nil (default)
--   Symbols stay prettified even when cursor is on them.
--   Atomic motions are ENABLED: h/l/w/b/x treat symbols as single chars.
--
-- unprettify_at_point = true
--   Show original text when cursor is anywhere on the symbol.
--   Atomic motions are DISABLED: normal Vim navigation/editing.
--
-- unprettify_at_point = "right-edge"
--   Show original text only when cursor moves past the first character.
--   Atomic motions are DISABLED: normal Vim navigation/editing.
--   (Emacs-like behavior)

-- Example config with right-edge mode:
-- require("sigil").setup({
--     filetypes = { "lua" },
--     symbols = {
--         ["->"] = "→",
--         ["lambda"] = "λ",
--     },
--     unprettify_at_point = "right-edge",
-- })

-- Test with right-edge mode:
-- When cursor is on first char of "lambda" (l), it stays prettified (λ)
-- When cursor moves to second char (a), original "lambda" appears

-- More test patterns:
local test_arrow = "-> value"    --> arrow at start
local test_lambda = "lambda x"   --> lambda at start
local mixed = "lambda x -> x"    --> both patterns

-- Visual comparison:
-- Original:  local f = lambda x -> x
-- Prettified: local f = λ x → x
-- With cursor on λ: local f = lambda x → x
-- With cursor on →: local f = λ x -> x
