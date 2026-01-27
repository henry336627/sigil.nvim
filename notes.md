# Notes: sigil

## Error Log

*No errors yet — project just started*

---

## Non-Obvious Decisions

### Extmarks vs syntax conceal
**Decision:** Use extmarks with `conceal` option instead of syntax-based conceal.
**Why:**
- Extmarks are more flexible and don't require syntax files
- Easier to update dynamically on text change
- Better integration with modern Neovim features
- Following render-markdown.nvim pattern

### Plain string matching vs regex
**Decision:** Start with plain string matching, not regex.
**Why:**
- Emacs prettify-symbols uses plain strings
- Simpler and faster for exact matches
- Regex can be added later as extension

### Namespace per plugin, not per buffer
**Decision:** Single global namespace for all sigil extmarks.
**Why:**
- Simpler management
- Can still filter by buffer when needed
- Consistent with other plugins (render-markdown, etc.)

---

## Unexpected Findings

### nvim__screenshot requires UI
Found during testing that `nvim__screenshot` only works when UI is attached.
For headless testing, use extmark inspection instead.

### Typst math context requires Tree-sitter parser
Math-only prettification for Typst relies on Tree-sitter. Ensure Typst parser is installed:
`:TSInstall typst`

### Emacs prettify uses font-lock
Emacs implementation ties into font-lock (syntax highlighting system).
Neovim equivalent is using TextChanged autocmds + manual extmark management.

### Headless buffer numbering
In headless mode (`nvim --headless`), `vim.api.nvim_get_current_buf()` returns 1, not 0.
Tests that use buffer 0 explicitly may fail because extmarks are created in buffer 0
but `move_right()`/`move_left()` use the current buffer (1).
**Solution:** Always use `vim.api.nvim_get_current_buf()` in tests instead of hardcoded buffer numbers.

---

## Reference Code Locations

- Emacs prettify-symbols: `/usr/local/Cellar/emacs-plus@30/30.2/share/emacs/30.2/lisp/progmodes/prog-mode.el` (lines 179-335)
- render-markdown extmark wrapper: `~/.local/share/nvim/lazy/render-markdown.nvim/lua/render-markdown/lib/extmark.lua`
- mini.hipatterns: `~/.local/share/nvim/lazy/mini.nvim/lua/mini/hipatterns.lua`
