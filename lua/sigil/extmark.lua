-- sigil.nvim - Extmark wrapper module

local state = require("sigil.state")

local M = {}

---Create a conceal extmark
---@param buf integer Buffer number
---@param row integer 0-indexed row
---@param col integer 0-indexed start column
---@param end_col integer 0-indexed end column (exclusive)
---@param replacement string Single character to display
---@return integer|nil Extmark ID or nil on failure
function M.create(buf, row, col, end_col, replacement)
  local ok, id = pcall(vim.api.nvim_buf_set_extmark, buf, state.ns, row, col, {
    end_col = end_col,
    conceal = replacement,
    priority = 100,
  })

  if ok then
    state.add_mark(buf, row, id)
    return id
  end

  return nil
end

---Delete a specific extmark
---@param buf integer
---@param id integer
function M.delete(buf, id)
  pcall(vim.api.nvim_buf_del_extmark, buf, state.ns, id)
end

---Clear extmarks in a range
---@param buf integer
---@param start_row? integer 0-indexed start row (default 0)
---@param end_row? integer 0-indexed end row exclusive (default -1 for end)
function M.clear(buf, start_row, end_row)
  start_row = start_row or 0
  end_row = end_row or -1
  vim.api.nvim_buf_clear_namespace(buf, state.ns, start_row, end_row)
end

---Get extmark at position
---@param buf integer
---@param row integer
---@param col integer
---@return table|nil Extmark info or nil
function M.get_at(buf, row, col)
  local marks = vim.api.nvim_buf_get_extmarks(
    buf,
    state.ns,
    { row, col },
    { row, col + 1 },
    { details = true }
  )

  if #marks > 0 then
    return {
      id = marks[1][1],
      row = marks[1][2],
      col = marks[1][3],
      details = marks[1][4],
    }
  end

  return nil
end

---Get all extmarks in buffer
---@param buf integer
---@return table[] List of extmarks
function M.get_all(buf)
  return vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, { details = true })
end

return M
