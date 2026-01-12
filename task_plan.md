# Task Plan: sigil — Neovim prettify-symbols plugin

## Goal
Create a Neovim plugin that visually replaces text patterns with Unicode symbols (like Emacs `prettify-symbols-mode`), with extensibility for future features.

## Phases

- [ ] Phase 1: Project Setup
  - [ ] 1.1 Create plugin directory structure
  - [ ] 1.2 Create minimal plugin entry point (`plugin/sigil.lua`)
  - [ ] 1.3 Setup test infrastructure (minimal_init.lua, smoke test)
  - [ ] 1.4 Verify tests run correctly

- [ ] Phase 2: Core MVP (Emacs parity)
  - [ ] 2.1 Create config module with default symbols alist
  - [ ] 2.2 Create namespace manager module
  - [ ] 2.3 Create extmark wrapper module
  - [ ] 2.4 Create core prettify logic (pattern matching + extmark placement)
  - [ ] 2.5 Create buffer attach/detach logic with autocmds
  - [ ] 2.6 Implement `setup()` function
  - [ ] 2.7 Write unit tests for core logic

- [ ] Phase 3: Unprettify at Point
  - [ ] 3.1 Implement cursor position tracking
  - [ ] 3.2 Show original text when cursor is on prettified symbol
  - [ ] 3.3 Add `unprettify_at_point` config option (nil, true, 'right-edge')
  - [ ] 3.4 Write tests for unprettify behavior

- [ ] Phase 4: Context-Aware Prettification
  - [ ] 4.1 Add predicate system (like `prettify-symbols-compose-predicate`)
  - [ ] 4.2 Implement Tree-sitter context detection (strings/comments)
  - [ ] 4.3 Implement syntax API fallback when Tree-sitter unavailable
  - [ ] 4.4 Allow custom predicates per filetype
  - [ ] 4.5 Write tests for predicate system

- [ ] Phase 5: Commands and API
  - [ ] 5.1 Add `:Sigil` toggle command
  - [ ] 5.2 Add `:SigilEnable` / `:SigilDisable` commands
  - [ ] 5.3 Expose public API for programmatic control
  - [ ] 5.4 Write tests for commands

- [ ] Phase 6: Documentation and Polish
  - [ ] 6.1 Write vimdoc help file (`doc/sigil.txt`)
  - [ ] 6.2 Add README.md with usage examples
  - [ ] 6.3 Final review and cleanup

## Blocked / Open Questions
- [ ] Multi-character replacement display (compose vs single char)?

## Decisions Made
- Use extmarks with `conceal` option for symbol replacement (standard Neovim approach)
- Use plenary.nvim for testing (already installed)
- Follow render-markdown.nvim patterns for plugin structure
- Tree-sitter for context detection with syntax API fallback
- MVP first, extensions later

## Status
**Phase 1.1** — Ready to start project setup

## Files
- `task_plan.md` — this file
- `architecture.md` — solution structure
- `notes.md` — error log and decisions
