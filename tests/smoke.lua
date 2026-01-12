-- Smoke test for sigil.nvim
-- Usage: nvim --headless -u NONE -l tests/smoke.lua

-- Add sigil to runtimepath
vim.opt.runtimepath:prepend(vim.fn.getcwd())

print("=== sigil.nvim smoke test ===")
print("")

-- Test 1: Module loads
local ok, sigil = pcall(require, "sigil")
if not ok then
  print("FAIL: Could not load sigil module")
  print("Error: " .. tostring(sigil))
  vim.cmd("cq 1")
end
print("OK: sigil module loaded")

-- Test 2: Setup function exists
if type(sigil.setup) ~= "function" then
  print("FAIL: sigil.setup is not a function")
  vim.cmd("cq 1")
end
print("OK: sigil.setup exists")

-- Test 3: Config module loads
local config_ok, config = pcall(require, "sigil.config")
if not config_ok then
  print("FAIL: Could not load sigil.config")
  print("Error: " .. tostring(config))
  vim.cmd("cq 1")
end
print("OK: sigil.config loaded")

-- Test 4: Default symbols exist
if not config.default.symbols["lambda"] then
  print("FAIL: default symbol 'lambda' not found")
  vim.cmd("cq 1")
end
print("OK: default symbols exist")

-- Test 5: Prettify module loads
local prettify_ok, prettify = pcall(require, "sigil.prettify")
if not prettify_ok then
  print("FAIL: Could not load sigil.prettify")
  print("Error: " .. tostring(prettify))
  vim.cmd("cq 1")
end
print("OK: sigil.prettify loaded")

-- Test 6: Pattern matching works
local matches = prettify.find_matches("lambda -> x", config.default.symbols)
if #matches < 2 then
  print("FAIL: expected at least 2 matches, got " .. #matches)
  vim.cmd("cq 1")
end
print("OK: pattern matching works (" .. #matches .. " matches)")

-- Test 7: Extmarks with conceal work
local state = require("sigil.state")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "lambda -> x" })

local extmark_ok, extmark_id = pcall(function()
  return vim.api.nvim_buf_set_extmark(0, state.ns, 0, 0, {
    end_col = 6,
    conceal = "λ",
  })
end)

if not extmark_ok then
  print("FAIL: extmark with conceal not supported")
  print("Error: " .. tostring(extmark_id))
  vim.cmd("cq 1")
end
print("OK: extmarks with conceal work")

-- Test 8: Full integration test
vim.api.nvim_buf_clear_namespace(0, state.ns, 0, -1)
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "local function test()",
  "  local lambda = function(x) return x end",
  "  if x != y && z >= 0 then",
  "    return x -> y",
  "  end",
  "end",
})

-- Setup config
config.setup({})

-- Attach and prettify
state.attach(0)
prettify.prettify_buffer(0)

-- Check extmarks were created
local marks = vim.api.nvim_buf_get_extmarks(0, state.ns, 0, -1, { details = true })
if #marks == 0 then
  print("FAIL: no extmarks created after prettify")
  vim.cmd("cq 1")
end
print("OK: prettify_buffer created " .. #marks .. " extmarks")

-- Verify conceal values
local found_lambda = false
local found_arrow = false
for _, mark in ipairs(marks) do
  local conceal = mark[4].conceal
  if conceal == "λ" then found_lambda = true end
  if conceal == "→" then found_arrow = true end
end

if not found_lambda then
  print("FAIL: lambda -> λ replacement not found")
  vim.cmd("cq 1")
end
print("OK: lambda -> λ replacement works")

if not found_arrow then
  print("FAIL: -> -> → replacement not found")
  vim.cmd("cq 1")
end
print("OK: -> -> → replacement works")

print("")
print("=== All smoke tests passed ===")
vim.cmd("qa!")
