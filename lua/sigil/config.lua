-- sigil.nvim - Configuration module

local M = {}

---@class sigil.Config
---@field enabled boolean Enable prettify-symbols
---@field symbols table<string, string> Global symbol mappings
---@field filetype_symbols table<string, table<string, string>> Per-filetype symbols
---@field filetypes string[]|"*" Filetypes to enable (or "*" for all)
---@field excluded_filetypes string[] Filetypes to exclude
---@field conceal_cursor string Modes where cursor line stays concealed

---Default configuration
---@type sigil.Config
M.default = {
  enabled = true,
  symbols = {
    -- Greek letters
    ["lambda"] = "λ",
    ["Lambda"] = "Λ",
    ["alpha"] = "α",
    ["beta"] = "β",
    ["gamma"] = "γ",
    ["delta"] = "δ",
    ["pi"] = "π",
    -- Arrows
    ["->"] = "→",
    ["<-"] = "←",
    ["=>"] = "⇒",
    ["<=>"] = "⇔",
    -- Comparison
    ["!="] = "≠",
    ["~="] = "≠",
    ["/="] = "≠",
    ["<="] = "≤",
    [">="] = "≥",
    ["=="] = "≡",
    -- Logic
    ["&&"] = "∧",
    ["||"] = "∨",
    ["!"] = "¬",
    ["not"] = "¬",
    -- Math
    ["sqrt"] = "√",
    ["sum"] = "∑",
    ["prod"] = "∏",
    ["inf"] = "∞",
    ["..."] = "…",
    -- Sets
    ["in"] = "∈",
    ["nil"] = "∅",
    ["null"] = "∅",
    ["None"] = "∅",
  },
  filetype_symbols = {
    -- Lua-specific
    lua = {
      ["function"] = "λ",
      ["local"] = "ℓ",
    },
    -- Python-specific
    python = {
      ["def"] = "λ",
      ["True"] = "⊤",
      ["False"] = "⊥",
    },
    -- Haskell-specific
    haskell = {
      ["\\"] = "λ",
      ["forall"] = "∀",
      ["exists"] = "∃",
    },
  },
  filetypes = "*",
  excluded_filetypes = { "help", "qf", "netrw", "lazy", "mason" },
  conceal_cursor = "nvic", -- all modes: normal, visual, insert, command
}

---Current merged configuration
---@type sigil.Config
M.current = vim.deepcopy(M.default)

---Merge user config with defaults
---@param opts? sigil.Config
function M.setup(opts)
  M.current = vim.tbl_deep_extend("force", vim.deepcopy(M.default), opts or {})
end

---Get symbols for a specific filetype
---@param ft string
---@return table<string, string>
function M.get_symbols(ft)
  local symbols = vim.deepcopy(M.current.symbols)

  -- Merge filetype-specific symbols
  local ft_symbols = M.current.filetype_symbols[ft]
  if ft_symbols then
    symbols = vim.tbl_extend("force", symbols, ft_symbols)
  end

  return symbols
end

---Check if filetype should be prettified
---@param ft string
---@return boolean
function M.is_enabled_for_filetype(ft)
  -- Check excluded filetypes
  if vim.tbl_contains(M.current.excluded_filetypes, ft) then
    return false
  end

  -- Check if all filetypes enabled
  if M.current.filetypes == "*" then
    return true
  end

  -- Check specific filetypes
  return vim.tbl_contains(M.current.filetypes, ft)
end

return M
