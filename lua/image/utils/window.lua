local debug = require("image.utils.logger").debug

---@param opts { normal: boolean, floating: boolean, with_masks: boolean, ignore_masking_filetypes: string[] }
---@return Window[]
local get_windows = function(opts)
  local windows = {} ---@type Window[]
  for _, id in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buffer = vim.api.nvim_win_get_buf(id)
    local columns = vim.api.nvim_win_get_width(id)
    local rows = vim.api.nvim_win_get_height(id)
    local pos = vim.api.nvim_win_get_position(id)
    local config = vim.api.nvim_win_get_config(id)
    local buffer_filetype = vim.bo[buffer].filetype
    local bufinfo = vim.fn.getbufinfo(buffer)[1]
    local buffer_is_listed = bufinfo and bufinfo.listed == 1
    local scroll_x = 0 -- TODO
    local scroll_y = tonumber(vim.fn.win_execute(id, "echo line('w0')")) - 1
    local is_visible = true

    local window = {
      id = id,
      buffer = buffer,
      buffer_filetype = buffer_filetype,
      buffer_is_listed = buffer_is_listed,
      x = pos[2],
      y = pos[1],
      scroll_x = scroll_x,
      scroll_y = scroll_y,
      width = columns,
      height = rows,
      is_visible = is_visible,
      is_normal = config.relative == "",
      is_floating = config.relative ~= "",
      zindex = config.zindex or 0,
      rect = {
        top = pos[1],
        right = pos[2] + columns,
        bottom = pos[1] + rows,
        left = pos[2],
      },
      masks = {},
    }
    table.insert(windows, window)
  end

  -- compute masks for normal windows
  if opts.with_masks then
    local ignore_masking_filetypes = opts.ignore_masking_filetypes or {}

    for _, window in ipairs(windows) do
      local masks = {}
      if not window.is_normal then goto continue end

      for _, other_window in ipairs(windows) do
        if window.id == other_window.id or not other_window.is_floating then goto continue_inner end
        if vim.tbl_contains(ignore_masking_filetypes, other_window.buffer_filetype) then goto continue_inner end

        debug("comparing windows", ("\n  %s\n  %s"):format(vim.inspect(window), vim.inspect(other_window)))

        local left = math.max(window.rect.left, other_window.rect.left)
        local right = math.min(window.rect.right, other_window.rect.right)
        local top = math.max(window.rect.top, other_window.rect.top)
        local bottom = math.min(window.rect.bottom, other_window.rect.bottom)

        if other_window.zindex > window.zindex and left < right and top < bottom then
          table.insert(masks, {
            x = left - window.rect.left,
            y = top - window.rect.top,
            width = right - left,
            height = bottom - top,
          })
        end

        ::continue_inner::
      end

      for _, mask in ipairs(masks) do
        if mask.x == 0 and mask.y == 0 and mask.width == window.width and mask.height == window.height then
          window.is_visible = false
          goto continue
        end
        -- TODO: merge masks, recompute is_visible
      end

      ::continue::
      window.masks = masks
    end
  end

  local result = {}
  for _, window in ipairs(windows) do
    if opts.normal and window.is_normal then table.insert(result, window) end
    if opts.floating and window.is_floating then table.insert(result, window) end
  end
  return result
end

---@param opts? { with_masks: boolean, ignore_masking_filetypes: string[] }
---@return Window|nil
local get_window = function(id, opts)
  if not vim.api.nvim_win_is_valid(id) then return nil end
  local windows = get_windows(vim.tbl_extend("force", opts or {}, { normal = true, floating = true }))
  for _, window in ipairs(windows) do
    if window.id == id then return window end
  end
  return nil
end

return {
  get_window = get_window,
  get_windows = get_windows,
}
