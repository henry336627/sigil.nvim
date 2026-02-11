# Task Plan: sigil — Neovim prettify-symbols plugin

## Goal
Create a Neovim plugin that visually replaces text patterns with Unicode symbols (like Emacs `prettify-symbols-mode`), with extensibility for future features.

## Phases

- [x] Phase 1: Project Setup
  - [x] 1.1 Create plugin directory structure
  - [x] 1.2 Create minimal plugin entry point (`plugin/sigil.lua`)
  - [x] 1.3 Setup test infrastructure (minimal_init.lua, smoke test)
  - [x] 1.4 Verify tests run correctly

- [x] Phase 2: Core MVP (Emacs parity)
  - [x] 2.1 Create config module with default symbols alist
  - [x] 2.2 Create namespace manager module
  - [x] 2.3 Create extmark wrapper module
  - [x] 2.4 Create core prettify logic (pattern matching + extmark placement)
  - [x] 2.5 Create buffer attach/detach logic with autocmds
  - [x] 2.6 Implement `setup()` function
  - [x] 2.7 Write unit tests for core logic

- [x] Phase 3: Context-Aware Prettification
  - [x] 3.1 Add predicate system (like `prettify-symbols-compose-predicate`)
  - [x] 3.2 Implement Tree-sitter context detection (strings/comments)
  - [x] 3.3 Implement syntax API fallback when Tree-sitter unavailable
  - [x] 3.4 Allow custom predicates per filetype
  - [x] 3.5 Write tests for predicate system

- [x] Phase 4: Atomic Symbol Motions
  - [x] 4.1 Create module for cursor position detection on prettified symbols
  - [x] 4.2 Implement motion remaps (`l`, `h`) to skip over entire symbol
  - [x] 4.3 Implement word motions (`w`, `b`, `e`) awareness of symbol boundaries
  - [x] 4.4 Implement delete (`x`, `X`) to delete entire prettified symbol
  - [x] 4.5 Implement change (`s`, `c`) to replace entire prettified symbol
  - [x] 4.6 Handle visual mode selections across prettified symbols
  - [x] 4.7 Write tests for atomic motions

- [x] Phase 5: Commands and API
  - [x] 5.1 Add `:Sigil` toggle command
  - [x] 5.2 Add `:SigilEnable` / `:SigilDisable` commands
  - [x] 5.3 Expose public API for programmatic control
  - [x] 5.4 Write tests for commands

- [ ] Phase 6: Documentation and Polish
  - [ ] 6.1 Write vimdoc help file (`doc/sigil.txt`)
  - [ ] 6.2 Add README.md with usage examples
  - [ ] 6.3 Final review and cleanup

- [x] Phase 7: Optional - Unprettify at Point
  - [x] 7.1 Implement cursor position tracking
  - [x] 7.2 Show original text when cursor is on prettified symbol
  - [x] 7.3 Add `unprettify_at_point` config option (nil, true, 'right-edge')
  - [x] 7.4 Write tests for unprettify behavior

- [x] Phase 8: Performance Optimization
  - [x] 8.1 Use `nvim_buf_attach` for incremental updates (only changed lines)
  - [x] 8.2 Add debounce for incremental updates (avoid excessive updates while typing)
  - [x] 8.3 Cache sorted symbols list (avoid re-sorting on every line)
  - [x] 8.4 Optimize visible range only (defer off-screen lines)
  - [x] 8.5 Benchmark and profile on large files (10,000+ lines)
  - [x] 8.6 Write performance tests

## Blocked / Open Questions
(none)

## Decisions Made
- Use extmarks with `conceal` option for symbol replacement (standard Neovim approach)
- Use plenary.nvim for testing (already installed)
- Follow render-markdown.nvim patterns for plugin structure
- Tree-sitter for context detection with syntax API fallback
- MVP first, extensions later
- Unprettify-at-point is optional (default: symbols stay prettified under cursor)
- Symbols stay concealed in all modes (concealcursor = "nvic")
- Atomic symbol motions: prettified symbols behave as single characters for navigation/editing
- Single-char replacements only (Emacs parity: compose-region → one glyph; multi-char breaks motions/cursor positioning)

## Status
**Phase 8 COMPLETE** — Lazy prettification for large files (visible range only), benchmark module (:SigilBenchmark), and performance tests implemented

## Files
- `task_plan.md` — this file
- `architecture.md` — solution structure
- `notes.md` — error log and decisions
