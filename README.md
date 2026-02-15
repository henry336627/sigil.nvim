# sigil

[![Mentioned in Awesome Neovim](https://awesome.re/mentioned-badge.svg)](https://github.com/rockerBOO/awesome-neovim)

Prettify symbols for Neovim. Visually replaces text patterns with Unicode
symbols while you edit. The file on disk is never modified.

`\alpha` displays as `α`, `\to` as `→`, `->` as `→`, and so on.

Based on the idea of Emacs [`prettify-symbols-mode`](https://www.gnu.org/software/emacs/manual/html_node/emacs/Misc-for-Programs.html), extended with context awareness, word boundary analysis, atomic motions, and math region support.

## Demo

### Atomic motions (default, no unprettify)

Symbols stay prettified at all times. Navigation and editing work as if
each symbol were a single character.

![Atomic motions demo](https://github.com/Prgebish/sigil.nvim/releases/download/v0.1.0/default_mode.gif)

### Unprettify at point (`unprettify_at_point = true`)

The symbol under the cursor reverts to original text. Other symbols on
the line remain prettified.

![Unprettify at point demo](https://github.com/Prgebish/sigil.nvim/releases/download/v0.1.0/unprett_1.gif)

### Unprettify line (`unprettify_at_point = "line"`)

All symbols on the cursor line revert to original text. When the cursor
moves to another line, the previous line is re-prettified.

![Unprettify line demo](https://github.com/Prgebish/sigil.nvim/releases/download/v0.1.0/unprett_2.gif)

## Features

- **Pattern → symbol replacement** using extmarks (no file modification)
- **Context awareness** -- skip strings and comments via Tree-sitter (with syntax fallback)
- **Math context** -- restrict symbols to math regions in LaTeX/Typst (`$...$`, `\[...\]`, etc.)
- **Atomic motions** -- `h`, `l`, `w`, `b`, `e`, `x`, `s`, `c` treat symbols as single characters
- **Unprettify at point** -- reveal original text under cursor or on cursor line
- **Per-symbol highlight groups** -- color symbols by category
- **Lazy prettification** -- large files are prettified on demand (visible area only)
- **Word boundaries** -- automatic boundary checks prevent partial matches (`in` won't match inside `integral`)

## Requirements

- Neovim >= 0.9.0
- A font with Unicode symbol support
- Tree-sitter parsers (optional, for context-aware filtering)

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "Prgebish/sigil.nvim",
  config = function()
    require("sigil").setup({
      filetypes = { "tex", "plaintex", "latex", "typst" },
      filetype_symbols = {
        tex = {
          { pattern = "\\alpha", replacement = "α", boundary = "left" },
          { pattern = "\\beta",  replacement = "β", boundary = "left" },
          { pattern = "\\to",    replacement = "→" },
          { pattern = "\\leq",   replacement = "≤" },
        },
      },
    })
  end,
}
```

## Quick start

Minimal LaTeX setup:

```lua
require("sigil").setup({
  filetypes = { "tex", "plaintex", "latex" },
  filetype_symbols = {
    tex = {
      { pattern = "\\alpha", replacement = "α", boundary = "left" },
      { pattern = "\\to",    replacement = "→" },
      { pattern = "\\infty", replacement = "∞" },
    },
  },
})
```

Open a `.tex` file -- every `\alpha` displays as `α`, `\to` as `→`,
`\infty` as `∞`.

## Symbol formats

**Map format** -- simple pattern → replacement:

```lua
symbols = {
  ["\\to"]  = "→",
  ["\\leq"] = "≤",
}
```

**List format** -- allows `boundary` and `hl_group` per symbol:

```lua
symbols = {
  { pattern = "\\alpha", replacement = "α", boundary = "left" },
  { pattern = "\\sum",   replacement = "∑", boundary = "left", hl_group = "Special" },
}
```

**Structured format** -- organize symbols by math context:

```lua
filetype_symbols = {
  typst = {
    math = {
      -- Only prettified inside $...$
      { pattern = "alpha", replacement = "α", boundary = "left" },
      { pattern = "sum",   replacement = "∑", boundary = "left" },
    },
    text = {
      -- Only prettified outside math
    },
    any = {
      -- Prettified everywhere
      { pattern = "->", replacement = "→" },
    },
  },
}
```

## Boundary modes

The `boundary` field controls word boundary checks:

| Value | Description |
|-------|-------------|
| `"both"` (default) | Check left and right boundaries |
| `"left"` | Check only left boundary. Allows subscripts on the right: `\sum_{i=0}`, `alpha_1` |
| `"right"` | Check only right boundary |
| `"none"` | No boundary checks |

## Commands

| Command | Description |
|---------|-------------|
| `:Sigil` | Toggle sigil on/off for current buffer |
| `:SigilEnable` | Enable for current buffer |
| `:SigilDisable` | Disable for current buffer |
| `:SigilBenchmark` | Run performance benchmark |

## Configuration

```lua
require("sigil").setup({
  enabled = true,
  symbols = {},                  -- global symbols (all filetypes)
  filetype_symbols = {},         -- per-filetype symbols
  filetypes = {},                -- filetypes to enable (or "*" for all)
  excluded_filetypes = {},       -- filetypes to exclude
  conceal_cursor = "nvic",       -- modes where cursor line stays concealed
  update_debounce_ms = 30,       -- debounce for incremental updates
  skip_strings = true,           -- skip inside string literals
  skip_comments = true,          -- skip inside comments
  atomic_motions = true,         -- symbols behave as single chars for motions
  unprettify_at_point = nil,     -- nil | true | "line"
  hl_group = nil,                -- default highlight group for symbols
  -- Performance (large files)
  lazy_prettify_threshold = 500, -- lazy mode for files > N lines
  lazy_prettify_buffer = 50,     -- extra lines around visible area
  lazy_prettify_debounce_ms = 50,
})
```

See `:help sigil` for full documentation.

## Like it?

If you find sigil useful, please star the repository -- it helps others discover the plugin.


## License

MIT
