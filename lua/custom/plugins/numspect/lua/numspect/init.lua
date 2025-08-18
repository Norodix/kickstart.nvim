-- TODO make it an actual plugin
-- TODO display it nicely in a hovering window

local Numspect = {}

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
    return string.format('%.3f %s', num_cpy, prefix[pi])
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

local get_word = function()
  local m = vim.api.nvim_get_mode()['mode']
  if m == 'v' then
    local s_start = vim.fn.getpos '.'
    local s_end = vim.fn.getpos 'v'
    if s_start[2] == s_end[2] then
      -- Actuall use visual
      local from = math.min(s_start[3], s_end[3])
      local to = math.max(s_start[3], s_end[3])
      local line = vim.fn.getline(s_start[2])
      ret = string.sub(line, from, to)
      dbprint(string.format('selected %d to %d in line %d: %s', s_start[3], s_end[3], s_start[2], ret))
      return ret
    else
      dbprint(string.format('different lines %d vs %d', s_start[2], s_end[2]))
    end
  else
    dbprint('Not visual mode ' .. m)
  end
  -- visual did not work for any reason, do non-visual
  return vim.fn.expand '<cword>'
end

Numspect.config = function(opts) end

-- 100000
Numspect.bibytes = function()
  local word = get_word()
  -- TODO expand as number + SI unit
  -- handle all SI units MiB, M, MB as Mibi
  local unit = '([B|K|M|G|T|P]?)i?B?'
  local numpart, unitpart
  numpart, unitpart = string.match(word, '([0x]*[.,0-9a-fA-F]+)' .. unit)

  local num = tonumber(numpart)
  if num ~= nil then
    if unitpart then
      if string.len(unitpart) ~= 0 then
        num = num * mult[unitpart]
      end
    end
    local formatted = iec(num)
    print(string.format('%s: 0x%X     %d     %s', word, num, num, iec(num)))
  else
    print('NaN ' .. word)
  end
end

-- Test values
-- 10G
-- 1GiB
-- 1Mib
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
  print 'Hello from numspect setup'
  vim.keymap.set('n', '?', Numspect.bibytes)
  vim.keymap.set('v', '?', Numspect.bibytes)
end

return Numspect
