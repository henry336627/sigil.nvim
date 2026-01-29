-- Phase 8: Performance Optimization Example
-- This file demonstrates lazy prettification and benchmarking features

--[[
  LAZY PRETTIFICATION (8.4)

  For large files (> 500 lines by default), sigil only prettifies
  the visible range initially. Off-screen lines are prettified
  lazily as you scroll.

  Configuration options:
  - lazy_prettify_threshold: Line count to enable lazy mode (default: 500, 0 to disable)
  - lazy_prettify_buffer: Extra lines around visible area (default: 50)
  - lazy_prettify_debounce_ms: Scroll debounce delay (default: 50ms)

  Example setup:

  require("sigil").setup({
    symbols = {
      ["lambda"] = "λ",
      ["->"] = "→",
      ["!="] = "≠",
    },
    filetypes = { "lua", "python" },
    -- Performance options
    lazy_prettify_threshold = 500,  -- Enable lazy mode for files > 500 lines
    lazy_prettify_buffer = 50,      -- Prettify 50 extra lines above/below visible
    lazy_prettify_debounce_ms = 50, -- 50ms debounce on scroll
  })

--]]

-- Test patterns for benchmarking:
-- Each line below contains symbols that will be prettified
-- lambda -> x, alpha != beta, gamma <= delta

-- Function using lambda symbol
local f = function(x) return x + 1 end -- lambda -> shorthand

-- Comparison operators
local a = 5
local b = 10
if a ~= b then -- ~= stays as-is (not in default symbols)
  print("not equal")
end

if a <= b then -- <= becomes ≤
  print("less or equal")
end

if a >= b then -- >= becomes ≥
  print("greater or equal")
end

-- Arrow functions
local arrow = function(x) -- ->
  return x * 2
end

--[[
  BENCHMARKING (8.5)

  Run :SigilBenchmark to measure attach performance across different file sizes.

  The benchmark module (require("sigil.benchmark")) provides:

  - generate_test_lines(count, symbols_per_line) - Create test content
  - time_it(fn, ...) - Measure function execution time
  - benchmark(fn, iterations, ...) - Run multiple times, get statistics
  - profile_attach(buf) - Measure attach time for a buffer
  - run_suite() - Full benchmark (100/1000/5000/10000/20000 lines)
  - print_results(results) - Display results in a table

  Example output from :SigilBenchmark:

  Lines      Attach (ms)  Extmarks
  -----------------------------------
  100        2.45         294
  1000       23.12        2940
  5000       45.67        1470      (lazy mode kicks in)
  10000      48.23        1500
  20000      51.89        1530

  With lazy mode, attach time stays constant for large files because
  only the visible range (~150 lines + 50 buffer = ~600 symbols max)
  is processed initially.

--]]

--[[
  PERFORMANCE TESTS (8.6)

  Run tests with:
  nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

  Performance tests verify:
  - find_matches completes within threshold (< 2ms per line)
  - Small file attach < 100ms (100 lines)
  - Medium file attach < 500ms (1000 lines)
  - Large file attach < 1000ms (10000 lines, with lazy loading)
  - Single line update < 5ms
  - Lazy loading correctly limits extmarks for large files
  - No extmark leaks after detach
  - Range tracking correctly merges/splits intervals

--]]

-- More test patterns for manual testing:
-- Open this file with sigil enabled and scroll around to see
-- lazy prettification in action.

-- alpha beta gamma delta epsilon zeta eta theta iota kappa
-- lambda -> mu, alpha != xi, beta <= pi, gamma >= sigma
-- tau upsilon phi chi psi omega

return {
  description = "Phase 8: Performance Optimization",
  features = {
    "Lazy prettification for large files (visible range only)",
    "Configurable lazy threshold and buffer zone",
    "Debounced scroll handler for smooth performance",
    "Benchmark module with :SigilBenchmark command",
    "Performance tests with time thresholds",
  },
}
