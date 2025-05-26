--- @class blink.cmp.SignatureWindow
--- @field win blink.cmp.Window
--- @field context? blink.cmp.SignatureHelpContext
---
--- @field open_with_signature_help fun(context: blink.cmp.SignatureHelpContext, signature_help?: lsp.SignatureHelp)
--- @field close fun()
--- @field scroll_up fun(amount: number)
--- @field scroll_down fun(amount: number)
--- @field update_position fun()

local config = require('blink.cmp.config').signature.window
local sources = require('blink.cmp.sources.lib')
local menu = require('blink.cmp.completion.windows.menu')

local signature = {
  win = require('blink.cmp.lib.window').new('signature', {
    min_width = config.min_width,
    max_width = config.max_width,
    max_height = config.max_height,
    default_border = 'padded',
    border = config.border,
    winblend = config.winblend,
    winhighlight = config.winhighlight,
    scrollbar = config.scrollbar,
    wrap = true,
    filetype = 'blink-cmp-signature',
  }),
  context = nil,
}

-- todo: deduplicate this
menu.position_update_emitter:on(function() signature.update_position() end)
vim.api.nvim_create_autocmd({ 'CursorMovedI', 'WinScrolled', 'WinResized' }, {
  callback = function()
    if signature.context then signature.update_position() end
  end,
})

--- @param context blink.cmp.SignatureHelpContext
--- @param signature_help lsp.SignatureHelp | nil
function signature.open_with_signature_help(context, signature_help)
  signature.context = context
  -- check if there are any signatures in signature_help, since
  -- convert_signature_help_to_markdown_lines errors with no signatures
  if
    signature_help == nil
    or #signature_help.signatures == 0
    or signature_help.signatures[(signature_help.activeSignature or 0) + 1] == nil
  then
    signature.win:close()
    return
  end

  local active_signature = signature_help.signatures[(signature_help.activeSignature or 0) + 1]

  local labels = vim.tbl_map(function(signature) return signature.label end, signature_help.signatures)

  if signature.shown_signature ~= active_signature then
    require('blink.cmp.lib.window.docs').render_detail_and_documentation({
      bufnr = signature.win:get_buf(),
      detail = labels,
      documentation = config.show_documentation and active_signature.documentation or nil,
      max_width = config.max_width,
      use_treesitter_highlighting = config.treesitter_highlighting,
    })
  end
  signature.shown_signature = active_signature

  -- highlight active parameter
  local _, active_highlight = vim.lsp.util.convert_signature_help_to_markdown_lines(
    signature_help,
    vim.bo.filetype,
    sources.get_signature_help_trigger_characters().trigger_characters
  )
  if active_highlight ~= nil then
    -- TODO: nvim 0.11+ returns the start and end line which we should use
    local start_region = vim.fn.has('nvim-0.11.0') == 1 and active_highlight[2] or active_highlight[1]
    local end_region = vim.fn.has('nvim-0.11.0') == 1 and active_highlight[4] or active_highlight[2]

    vim.api.nvim_buf_add_highlight(
      signature.win:get_buf(),
      require('blink.cmp.config').appearance.highlight_ns,
      'BlinkCmpSignatureHelpActiveParameter',
      0,
      start_region,
      end_region
    )
  end

  signature.win:open()
  signature.update_position()
end

function signature.close()
  if not signature.win:is_open() then return end
  signature.win:close()
end

function signature.scroll_up(amount)
  local winnr = signature.win:get_win()
  local top_line = math.max(1, vim.fn.line('w0', winnr) - 1)
  local desired_line = math.max(1, top_line - amount)

  vim.api.nvim_win_set_cursor(signature.win:get_win(), { desired_line, 0 })
end

function signature.scroll_down(amount)
  local winnr = signature.win:get_win()
  local line_count = vim.api.nvim_buf_line_count(signature.win:get_buf())
  local bottom_line = math.max(1, vim.fn.line('w$', winnr) + 1)
  local desired_line = math.min(line_count, bottom_line + amount)

  vim.api.nvim_win_set_cursor(signature.win:get_win(), { desired_line, 0 })
end

function signature.update_position()
  local win = signature.win
  if not win:is_open() then return end
  local winnr = win:get_win()

  win:update_size()
  local height = win:get_height()

  vim.api.nvim_win_set_height(winnr, height)

  vim.api.nvim_win_set_config(winnr, {
    relative = 'editor',
    row = vim.o.lines - height,
    col = 0,
    width = vim.o.columns,
    height = height,
    anchor = 'NW',
    focusable = false,
    zindex = 200,
  })
end


return signature
