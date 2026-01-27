# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Project Overview

**sigil** — Neovim plugin for visual symbol replacement (prettify-symbols).
Replaces text patterns with Unicode symbols while editing (e.g., `lambda` → `λ`, `->` → `→`).

Inspired by Emacs `prettify-symbols-mode`.

## Architecture

- `lua/sigil/` — main plugin code
- `plugin/sigil.lua` — entry point
- `tests/` — plenary.nvim tests
- `examples/` — working examples for each implemented phase

## Examples

The `examples/` directory contains working Lua files demonstrating each phase's functionality.
Use these to understand how features work in practice:

- `phase_3.lua` — Context-aware prettification (predicates, skip strings/comments)
- `phase_4.lua` — Atomic symbol motions (h/l, w/b/e, x/X, s/c)

To test an example:
```bash
nvim examples/phase_3.lua
:lua require("sigil").setup()
:set conceallevel=2
```

**IMPORTANT:** After implementing parts of a Phase, always add or update examples in the `examples/` directory:
- Create `examples/phase_N.lua` if it doesn't exist
- Add demonstration code for each implemented feature (4.1, 4.2, etc.)
- Include usage instructions and expected behavior in comments
- Examples serve as both documentation and manual testing aid

## Verification Commands

After making code changes, Claude Code MUST run these commands to verify correctness:

```bash
# Run all tests
nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

# Quick smoke test (extmarks work)
nvim --headless -u NONE -l tests/smoke.lua

# Lint (if stylua installed)
stylua --check lua/
```

**IMPORTANT:** Always run verification after code changes. Do not skip this step.

## Planning Files

When working on complex tasks, check these files:
- `task_plan.md` — phases and current status
- `architecture.md` — detailed module design
- `notes.md` — **ALWAYS CHECK** for error history and past decisions

## Reference Materials

- Emacs source: `/usr/local/Cellar/emacs-plus@30/30.2/share/emacs/30.2/lisp/progmodes/prog-mode.el`
- [GNU Emacs Manual — prettify-symbols](http://www.gnu.org/s/emacs/manual/html_node/emacs/Misc-for-Programs.html)
- [Emacs Wiki — PrettySymbol](https://www.emacswiki.org/emacs/PrettySymbol)
- [plenary.nvim tests](https://github.com/nvim-lua/plenary.nvim/blob/master/TESTS_README.md)
