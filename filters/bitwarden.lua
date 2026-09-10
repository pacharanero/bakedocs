-- SPDX-FileCopyrightText: 2026 Marcus Baw
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Also used by `pandoc lua` before rendering. Only the select operation reads
-- vault data, from a bounded pipe; its output goes directly to the render filter.
local M = {}
local limit = 1024 * 1024

local function check(condition)
  if not condition then error('invalid Bitwarden input', 0) end
end

local function read_file(path, bound)
  local file = assert(io.open(path, 'rb'))
  local text = file:read(bound + 1) or ''
  file:close()
  check(#text <= bound)
  return text
end

-- A deliberately small mapping-YAML grammar: block maps with two-space
-- indentation, or flow maps. No aliases, tags, multiline scalars or coercion.
local function mapping(path)
  local text = read_file(path, 65536)
  check(not text:find('[%z\1-\9\11\12\14-\31]'))
  local position = 1
  local function space()
    while true do
      local _, last = text:find('^%s+', position)
      if last then position = last + 1 end
      if text:sub(position, position) ~= '#' then break end
      position = (text:find('\n', position, true) or #text) + 1
    end
  end
  local function scalar()
    space()
    local start = position
    local quote = text:sub(position, position)
    if quote == '"' or quote == "'" then
      position = position + 1
      local value = {}
      while position <= #text do
        local char = text:sub(position, position)
        check(char ~= '\n' and char ~= '\r')
        position = position + 1
        if char == quote then
          if quote == "'" and text:sub(position, position) == "'" then
            value[#value + 1] = "'"
            position = position + 1
          else
            if quote == '"' then
              return pandoc.json.decode(text:sub(start, position - 1))
            end
            return table.concat(value)
          end
        else
          value[#value + 1] = char
          if quote == '"' and char == '\\' then position = position + 1 end
        end
      end
      check(false)
    end
    local _, last = text:find('^[^%s{},:#][^\n\r{},:#]*', position)
    check(last ~= nil)
    position = last + 1
    local value = text:sub(start, last):match('^(.-)%s*$')
    check(value:match('^[A-Za-z0-9_]') ~= nil)
    return value
  end
  local flow
  flow = function(depth)
    check(depth <= 3)
    space()
    check(text:sub(position, position) == '{')
    position = position + 1
    local result = {}
    space()
    while text:sub(position, position) ~= '}' do
      local key = scalar()
      space()
      check(text:sub(position, position) == ':' and result[key] == nil)
      position = position + 1
      space()
      result[key] = text:sub(position, position) == '{' and flow(depth + 1) or scalar()
      space()
      local next_char = text:sub(position, position)
      check(next_char == ',' or next_char == '}')
      if next_char == ',' then position = position + 1; space() end
    end
    position = position + 1
    return result
  end
  local result
  space()
  if text:sub(position, position) == '{' then
    result = flow(1)
    space()
    check(position > #text)
  else
    result = {}
    local parents = {[0] = result}
    local previous = -1
    for line in (text .. '\n'):gmatch('(.-)\n') do
      if not line:match('^%s*$') and not line:match('^%s*#') then
        local indent = #(line:match('^( *)'))
        check(indent % 2 == 0 and indent <= 4 and indent <= previous + 2)
        text, position = line:sub(indent + 1), 1
        local key = scalar()
        space()
        check(text:sub(position, position) == ':')
        position = position + 1
        space()
        local parent = parents[indent]
        check(parent ~= nil and parent[key] == nil)
        if position > #text then
          parent[key] = {}
          parents[indent + 2] = parent[key]
        else
          parent[key] = text:sub(position, position) == '{' and flow(indent / 2 + 2) or scalar()
          space()
          check(position > #text)
          parents[indent + 2] = nil
        end
        previous = indent
      end
    end
  end
  check(type(result.bitwarden) == 'table')
  for key in pairs(result) do check(key == 'bitwarden') end
  local config = result.bitwarden
  for key in pairs(config) do check(key == 'item-id' or key == 'fields') end
  local id = config['item-id']
  check(type(id) == 'string' and #id == 36 and
    id:match('^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$'))
  check(type(config.fields) == 'table')
  local count, names = 0, {}
  for destination, name in pairs(config.fields) do
    check(type(name) == 'string' and #name > 0 and #name <= 256 and not name:find('%c'))
    check(not names[name])
    names[name] = true
    check(#destination <= 256 and destination:find('.', 1, true) ~= nil and
      not destination:match('%.%.') and not destination:match('^%.') and not destination:match('%.$'))
    local segments = 0
    for part in destination:gmatch('[^.]+') do
      check(part:match('^[A-Za-z_][A-Za-z0-9_-]*$'))
      segments = segments + 1
      check(segments <= 32)
    end
    for other in pairs(config.fields) do
      check(other == destination or other:sub(1, #destination + 1) ~= destination .. '.')
    end
    count = count + 1
    check(count <= 128)
  end
  check(count > 0 and count <= 128)
  return config
end

-- Reject duplicate JSON keys and excessive nesting before using Pandoc's JSON
-- decoder. Strings are skipped lexically so braces inside secrets are inert.
local function json(text)
  local stack, position = {}, 1
  while position <= #text do
    local char = text:sub(position, position)
    if char == '"' then
      local start = position
      position = position + 1
      while position <= #text and text:sub(position, position) ~= '"' do
        if text:sub(position, position) == '\\' then position = position + 1 end
        position = position + 1
      end
      check(position <= #text)
      local finish = position
      position = position + 1
      local following = text:sub(position):match('^%s*(.)')
      if following == ':' then
        local keys = stack[#stack]
        check(keys ~= nil)
        local key = pandoc.json.decode(text:sub(start, finish))
        check(not keys[key])
        keys[key] = true
      end
    else
      if char == '{' or char == '[' then
        stack[#stack + 1] = {}
        check(#stack <= 32)
      elseif char == '}' or char == ']' then
        check(#stack > 0)
        stack[#stack] = nil
      end
      position = position + 1
    end
  end
  return pandoc.json.decode(text)
end

function M.plan()
  local layers, ids = {{kind = 'values', path = arg[2]}}, {}
  for index = 3, #arg, 2 do
    check(arg[index] == 'values' or arg[index] == 'bitwarden')
    layers[#layers + 1] = {kind = arg[index], path = arg[index + 1]}
    if arg[index] == 'bitwarden' then ids[#ids + 1] = mapping(arg[index + 1])['item-id'] end
  end
  io.write(pandoc.json.encode(layers), '\n')
  for _, id in ipairs(ids) do io.write(id, '\n') end
end

function M.select()
  local config = mapping(arg[2])
  local text = io.read(limit + 1) or ''
  check(#text <= limit)
  local item = json(text)
  check(type(item) == 'table' and type(item.id) == 'string' and
    item.id:lower() == config['item-id']:lower() and type(item.fields) == 'table')
  local fields, count = {}, 0
  for index, field in pairs(item.fields) do
    check(type(index) == 'number' and index >= 1 and index % 1 == 0 and type(field) == 'table')
    check(type(field.name) == 'string' and fields[field.name] == nil)
    fields[field.name] = field
    count = count + 1
    check(count <= 1024)
  end
  local selected = {}
  for destination, name in pairs(config.fields) do
    local field = fields[name]
    check(field ~= nil and (field.type == 0 or field.type == 1) and
      type(field.value) == 'string' and #field.value <= 65536 and
      not field.value:find('[%z\1-\8\11\12\14-\31]'))
    selected[destination] = field.value
  end
  local encoded = pandoc.json.encode(selected)
  io.write(tostring(#encoded), '\n', encoded)
end

function M.layers(source_meta)
  local layers = pandoc.json.decode(os.getenv('BAKEDOCS_LAYERS'))
  local metadata, public, secrets = {}, {}, {}
  local function merge(meta, vault)
    for key, value in pairs(meta) do
      metadata[key] = value
      if vault then public[key] = nil else public[key] = value end
      for path in pairs(secrets) do
        if path:match('^[^.]+') == key then secrets[path] = nil end
      end
    end
  end
  for _, layer in ipairs(layers) do
    if layer.kind == 'bitwarden' then
      -- Length framing keeps both reads bounded, including a broken producer.
      local digits = ''
      while true do
        local char = io.read(1)
        check(char ~= nil)
        if char == '\n' then break end
        check(char:match('%d') and #digits < 7)
        digits = digits .. char
      end
      local size = tonumber(digits)
      check(size ~= nil and size > 0 and size <= 2 * limit)
      local text = io.read(size)
      check(text ~= nil and #text == size)
      local selected = json(text)
      local meta = {}
      for path, value in pairs(selected) do
        local parent, parts = meta, {}
        for part in path:gmatch('[^.]+') do parts[#parts + 1] = part end
        for index = 1, #parts - 1 do
          parent[parts[index]] = parent[parts[index]] or {}
          parent = parent[parts[index]]
        end
        parent[parts[#parts]] = pandoc.MetaString(value)
      end
      merge(meta, true)
      for path, value in pairs(selected) do secrets[path] = value end
    else
      local text = read_file(layer.path, limit)
      -- Metadata files may include optional YAML document delimiters. JSON
      -- objects are also YAML and go through the same Pandoc metadata reader.
      text = text:gsub('^\239\187\191', ''):gsub('^%s*%-%-%-%s*\n', '')
      text = text:gsub('\n%-%-%-%s*$', ''):gsub('\n%.%.%.%s*$', '')
      local document = pandoc.read('---\n' .. text .. '\n---\n', 'markdown-raw_html-raw_attribute')
      check(#document.blocks == 0)
      merge(document.meta, false)
    end
  end
  check(io.read(1) == nil)
  merge(source_meta, false)
  return metadata, public, secrets
end

if PANDOC_SCRIPT_FILE == nil then
  local ok = pcall(function()
    check(arg[1] == 'plan' or arg[1] == 'select')
    M[arg[1]]()
  end)
  if not ok then os.exit(1) end
else
  return M
end
