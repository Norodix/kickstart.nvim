local Numspect = {}

-- Default options
local options = {
  use_hover = true,    -- If true the inspection is shown in a hovering window, otherwise only printed
  mappings = {
    ['?'] = 'trigger', -- The main (and only atm) action that shows the number inspection
  },
}

local win = nil
local buf = nil

local dbprint = function(...) end
-- local dbprint = print

local iec = function(num)
  local prefix = { 'B', 'KiB', 'MiB', 'GiB', 'TiB', 'Pi', 'Ei' }
  -- prefix index
  local pi = 1
  local num_cpy = num
  while num_cpy >= 1024 do
    pi = pi + 1
    num_cpy = num_cpy / 1024
  end
  -- print(num_cpy)
  if pi <= #prefix then
    return string.format('%.3f%s', num_cpy, prefix[pi])
  end
end

local mult = {
  B = math.pow(1024, 0),
  K = math.pow(1024, 1),
  M = math.pow(1024, 2),
  G = math.pow(1024, 3),
  T = math.pow(1024, 4),
  P = math.pow(1024, 5),
}

local close_hover = function()
  if win ~= nil then
    vim.api.nvim_win_close(win, true)
    win = nil
  end
  if buf ~= nil then
    vim.api.nvim_buf_delete(buf, { force = true })
    buf = nil
  end
end

local close_hover_unless_same = function()
  if win ~= vim.api.nvim_get_current_win() then
    close_hover()
  end
end

local print_window = function(str)
  -- always close before trying to create
  close_hover()

  local opts = {
    relative = 'cursor',
    row = -1,
    col = 0,
    focusable = false,
    mouse = false,
    height = 1,
    width = string.len(str) + 2,
    style = 'minimal',
  }

  buf = vim.api.nvim_create_buf(false, true) -- non-listed scratch buffer
  win = vim.api.nvim_open_win(buf, false, opts)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { ' ' .. str })
  vim.api.nvim_create_autocmd({ 'CursorMoved' }, {
    once = true,
    callback = close_hover_unless_same,
  })
end

-- Position of the inspected number
local position = {
  valid = false,
  buffer = 0,
  line = 0,
  col_start = 0,
  col_end = 0,
}

local get_word = function()
  local m = vim.api.nvim_get_mode()['mode']
  if m == 'v' then
    local s_start = vim.fn.getpos '.'
    local s_end = vim.fn.getpos 'v'
    position.line = s_start[2]
    if s_start[2] == s_end[2] then
      -- Actuall use visual
      local from = math.min(s_start[3], s_end[3])
      local to = math.max(s_start[3], s_end[3])
      local line = vim.fn.getline(s_start[2])
      local ret = string.sub(line, from, to)
      dbprint(string.format('selected %d to %d in line %d: %s', s_start[3], s_end[3], s_start[2], ret))
      position.col_start = from
      position.col_end = to
      position.valid = true
      return ret
    else
      dbprint(string.format('different lines %d vs %d', s_start[2], s_end[2]))
    end
  else
    dbprint('Not visual mode ' .. m)
  end
  -- visual did not work for any reason, do non-visual

  -- save eventignore
  local oldignore = vim.opt.eventignore:get()
  vim.opt.eventignore:append 'CursorMoved'
  local oldpos = vim.api.nvim_win_get_cursor(0)

  local w = vim.fn.expand '<cword>'
  vim.fn.search(w, 'bc')
  -- Convert to 1 index because that is what is used in the above case
  position.col_start = vim.api.nvim_win_get_cursor(0)[2] + 1
  vim.fn.search(w, 'ce')
  position.col_end = vim.api.nvim_win_get_cursor(0)[2] + 1
  position.line = vim.api.nvim_win_get_cursor(0)[1]
  position.valid = true

  -- move cursor back to the original position
  vim.api.nvim_win_set_cursor(0, oldpos)
  -- restore eventignore
  vim.opt.eventignore = oldignore

  return w
end

-- Save the representations of the number so it can be yanked and replaced
local repr = {
  word = '',
  dec = '',
  hex = '',
  formatted = '',
}

-- Parse the input value, compute the conversions and display it
local bibytes = function(arg)
  -- Get word from argument, otherwise parse it from buffer
  repr.word = ''
  if type(arg) == 'string' then
    if string.len(arg) ~= 0 then
      repr.word = arg
    end
  end
  if string.len(repr.word) == 0 then
    repr.word = get_word()
  end

  -- handle all SI units MiB, M, MB as Mibi
  local unit = '%s*([BKMGTP]?)i?B?'
  local numpart, unitpart
  numpart, unitpart = string.match(repr.word, '([0x]*[.,0-9a-fA-F]+)' .. unit)

  repr.num = tonumber(numpart)
  if repr.num ~= nil then
    if unitpart then
      if string.len(unitpart) ~= 0 then
        repr.num = repr.num * mult[unitpart]
      end
    end
    -- Save the spelled out representations
    repr.formatted = iec(repr.num)
    repr.dec = string.format('%d', repr.num)
    repr.hex = string.format('0x%X', repr.num)
    local str = string.format('%s: h:%s   d:%s   i:%s', repr.word, repr.hex, repr.dec, repr.formatted)
    vim.print(str)
    if options.use_hover then
      print_window(str)
    end
  else
    vim.print('NaN ' .. repr.word)
  end
end

-- Yank the selected representation to the clipboard
local function yank_repr(r)
  dbprint('Yanking ' .. r)
  -- set clipboard to repr[r]
  local copyreg = '@'
  if vim.opt.clipboard._value == 'unnamed' then
    copyreg = '*'
  end
  if vim.opt.clipboard._value == 'unnamedplus' then
    copyreg = '+'
  end
  if repr[r] then
    vim.fn.setreg(copyreg, repr[r])
  end
end

-- Replace the text with the selected representation
local function replace_repr(r)
  if not position.valid then
    vim.print("No valid source position found")
    return
  end
  dbprint('replacing ' .. r)
  -- Needed for 0 indexing
  local line = position.line - 1
  local start = position.col_start - 1
  vim.api.nvim_buf_set_text(position.buffer, line, start, line, position.col_end, { repr[r] })
end

Numspect.trigger = function(arg)
  -- Set to false by default
  if win == nil then
    position.valid = false
    bibytes(arg)
  else
    position.buffer = vim.api.nvim_get_current_buf()
    vim.api.nvim_set_current_win(win)
    vim.api.nvim_buf_set_keymap(0, 'n', '<Esc>', '', { callback = close_hover })
    vim.api.nvim_buf_set_keymap(0, 'n', '<leader>', '', { callback = close_hover })
    vim.api.nvim_buf_set_keymap(0, 'n', '<CR>', '', { callback = close_hover })
    vim.api.nvim_buf_set_keymap(0, 'n', 'j', '', { callback = close_hover })
    vim.api.nvim_buf_set_keymap(0, 'n', 'k', '', { callback = close_hover })
    vim.api.nvim_buf_set_keymap(0, 'n', 'q', '', { callback = close_hover })

    vim.api.nvim_buf_set_keymap(0, 'n', 'yh', '', {
      callback = function()
        yank_repr 'hex'
        close_hover()
      end,
      desc = '[Y]ank [H]ex representation',
    })
    vim.api.nvim_buf_set_keymap(0, 'n', 'yi', '', {
      callback = function()
        yank_repr 'formatted'
        close_hover()
      end,
      desc = '[Y]ank [I]EC binary representation',
    })
    vim.api.nvim_buf_set_keymap(0, 'n', 'yd', '', {
      callback = function()
        yank_repr 'dec'
        close_hover()
      end,
      desc = '[Y]ank [d]ecimal representation',
    })

    vim.api.nvim_buf_set_keymap(0, 'n', 'rh', '', {
      callback = function()
        replace_repr 'hex'
        close_hover()
      end,
      desc = '[R]eplace [H]ex representation',
    })
    vim.api.nvim_buf_set_keymap(0, 'n', 'ri', '', {
      callback = function()
        replace_repr 'formatted'
        close_hover()
      end,
      desc = '[R]eplace [I]EC binary representation',
    })
    vim.api.nvim_buf_set_keymap(0, 'n', 'rd', '', {
      callback = function()
        replace_repr 'dec'
        close_hover()
      end,
      desc = '[R]eplace [d]ecimal representation',
    })
  end
end

-- Lua functions are called with a single table argument containing arguments and modifiers. The most important are:
-- name: a string with the command name
-- fargs: a table containing the command arguments split by whitespace (see <f-args>)
-- bang: true if the command was executed with a ! modifier (see <bang>)
-- line1: the starting line number of the command range (see <line1>)
-- line2: the final line number of the command range (see <line2>)
-- range: the number of items in the command range: 0, 1, or 2 (see <range>)
-- count: any count supplied (see <count>)
-- smods: a table containing the command modifiers (see <mods>)
local user_command = function(t)
  local arg = table.concat(t.fargs, ' ')
  Numspect.trigger(arg)
end

-- Test values
-- 10G
-- 1MB
-- 1GiB
-- 1Mib
-- 1Ma
-- 1.1M
-- 0 1000 0x1000 0x2000+3
-- 0x1000
-- 100
-- 0xDC0
-- 0x100f001
-- 0x1000000g
-- 123g
-- 0x1000000000
-- 0x1000000000000
-- 10T

Numspect.setup = function(opts)
  -- Merge the option tables
  for k, v in pairs(opts) do
    options[k] = v
  end
  -- Set up key mappings
  for k, v in pairs(options.mappings) do
    vim.keymap.set('n', k, Numspect[v])
    vim.keymap.set('v', k, Numspect[v])
  end
  vim.api.nvim_create_user_command('Numspect', user_command, { nargs = '*' })
end

return Numspect
