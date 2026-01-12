# Architecture: sigil

## Overview

sigil is a Neovim plugin that replaces text patterns with Unicode symbols using extmarks with conceal. The plugin watches buffer changes and applies visual replacements without modifying the actual text.

## File Structure

```
sigil/
├── plugin/
│   └── sigil.lua           # Entry point, lazy load trigger
├── lua/
│   └── sigil/
│       ├── init.lua        # Main module, setup(), public API
│       ├── config.lua      # Configuration and defaults
│       ├── state.lua       # Buffer state management
│       ├── extmark.lua     # Extmark wrapper (create/delete/update)
│       ├── prettify.lua    # Core prettification logic
│       ├── unprettify.lua  # Cursor tracking, show original at point
│       ├── predicate.lua   # Context predicates (skip strings/comments)
│       └── motions.lua     # Atomic symbol motions (h/l skip symbols)
├── tests/
│   ├── minimal_init.lua    # Test environment setup
│   ├── smoke.lua           # Quick smoke test
│   └── sigil/
│       ├── config_spec.lua
│       ├── extmark_spec.lua
│       ├── prettify_spec.lua
│       └── unprettify_spec.lua
└── doc/
    └── sigil.txt           # Vimdoc help
```

## Modules

### Module: init.lua
- Purpose: Main entry point, public API
- Exports:
  - `setup(opts)` — initialize plugin with user config
  - `enable(buf?)` — enable for buffer
  - `disable(buf?)` — disable for buffer
  - `toggle(buf?)` — toggle state
  - `refresh(buf?)` — force refresh

### Module: config.lua
- Purpose: Configuration management
- Exports:
  - `default` — default configuration table
  - `get()` — get merged config
  - `get_symbols(ft)` — get symbols for filetype
- Default config structure:
  ```lua
  {
    enabled = true,
    filetypes = { "*" },           -- or { "lua", "python", ... }
    excluded_filetypes = {},
    unprettify_at_point = true,    -- nil | true | "right-edge"
    symbols = {
      -- Global symbols (all filetypes)
      ["lambda"] = "λ",
      ["->"]     = "→",
      ["=>"]     = "⇒",
      ["!="]     = "≠",
      ["<="]     = "≤",
      [">="]     = "≥",
      ["&&"]     = "∧",
      ["||"]     = "∨",
    },
    filetype_symbols = {
      -- Filetype-specific overrides/additions
      lua = {
        ["function"] = "ƒ",
      },
      python = {
        ["lambda"] = "λ",
        ["None"]   = "∅",
      },
    },
    predicate = nil,  -- custom predicate function(buf, row, col, match) -> bool
  }
  ```

### Module: state.lua
- Purpose: Track per-buffer state
- Exports:
  - `attach(buf)` — attach to buffer
  - `detach(buf)` — detach from buffer
  - `is_attached(buf)` — check if attached
  - `get(buf)` — get buffer state
- State structure:
  ```lua
  {
    buf = bufnr,
    enabled = true,
    namespace = ns_id,
    marks = {},        -- extmark ids by position
  }
  ```

### Module: extmark.lua
- Purpose: Wrapper around nvim_buf_set_extmark
- Exports:
  - `create(buf, ns, row, col, end_col, replacement)` — create conceal extmark
  - `delete(buf, ns, id)` — delete extmark
  - `clear(buf, ns, start_row?, end_row?)` — clear extmarks in range
  - `get_at(buf, ns, row, col)` — get extmark at position

### Module: prettify.lua
- Purpose: Core prettification logic
- Exports:
  - `prettify_buffer(buf)` — prettify entire buffer
  - `prettify_lines(buf, start_row, end_row)` — prettify line range
  - `find_matches(line, symbols)` — find pattern matches in line
- Algorithm:
  1. For each line in range
  2. Find all symbol matches (using plain string search, longest first)
  3. Check predicate for each match
  4. Create extmark with conceal for valid matches

### Module: unprettify.lua
- Purpose: Show original text at cursor
- Exports:
  - `setup_autocmds(buf)` — setup CursorMoved autocmd
  - `update(buf)` — check cursor and show/hide original
- Logic:
  1. On CursorMoved, get cursor position
  2. If cursor on prettified symbol, temporarily hide extmark
  3. When cursor moves away, restore extmark

### Module: predicate.lua
- Purpose: Context-aware filtering
- Exports:
  - `default(buf, row, col, match)` — default predicate
  - `in_string(buf, row, col)` — check if in string
  - `in_comment(buf, row, col)` — check if in comment
  - `has_treesitter(buf)` — check if Tree-sitter available
- Default predicate:
  - Returns false if in string or comment (don't prettify)
  - Returns true otherwise (do prettify)
- Context detection strategy:
  1. If Tree-sitter parser available for buffer filetype → use TS queries
  2. Else fallback to `vim.treesitter.get_captures_at_pos()` or syntax API

### Module: motions.lua
- Purpose: Atomic symbol motions (prettified symbols behave as single chars)
- Exports:
  - `get_symbol_at(buf, row, col)` — get extmark info at position
  - `get_next_symbol(buf, row, col)` — find next symbol after position
  - `get_prev_symbol(buf, row, col)` — find previous symbol before position
  - `move_right()` — move cursor right, skipping over entire symbol
  - `move_left()` — move cursor left, skipping over entire symbol
  - `setup_keymaps(buf)` — setup h/l keymaps for buffer
  - `remove_keymaps(buf)` — remove h/l keymaps from buffer
- Logic:
  - On `l`: if on symbol, jump to end; else normal movement
  - On `h`: if inside or after symbol, jump to start; else normal movement
- Configuration: `atomic_motions` option (default: true)

## Data Flow

```
User calls setup(opts)
        ↓
Config merged with defaults
        ↓
Autocmds created for FileType/BufEnter
        ↓
On buffer enter:
   state.attach(buf)
        ↓
   prettify.prettify_buffer(buf)
        ↓
   For each line:
      find_matches() → predicate() → extmark.create()
        ↓
   unprettify.setup_autocmds(buf)
        ↓
On text change (TextChanged/TextChangedI):
   prettify.prettify_lines(buf, changed_start, changed_end)
        ↓
On cursor move:
   unprettify.update(buf)
```

## Key Design Decisions

- **Extmarks with conceal**: Standard Neovim approach, works with conceallevel
- **Per-buffer state**: Each buffer has independent state and extmarks
- **Lazy prettification**: Only prettify visible/changed lines for performance
- **Predicate system**: Extensible filtering like Emacs
- **Filetype symbols**: Allow different symbols per language
