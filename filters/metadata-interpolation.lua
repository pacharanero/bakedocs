-- SPDX-FileCopyrightText: 2026 Marcus Baw
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Metadata interpolation is intentionally smaller than a template language.
-- It resolves scalar metadata paths into already-parsed Pandoc text nodes; it
-- never evaluates expressions or reparses a value as Markdown or HTML.

local metadata
local secrets = {}
local in_metadata = false
local resolved = {}
local resolving = {}
local errors = {}
local resolution_depth = 0
local expanded_bytes = 0
local max_resolution_depth = 32
local max_expanded_bytes = 1024 * 1024

local function record_error(message)
  errors[message] = true
end

local function valid_path(path)
  if path == '' then
    return false
  end
  for part in path:gmatch('[^.]+') do
    if not part:match('^[A-Za-z_][A-Za-z0-9_-]*$') then
      return false
    end
  end
  return not path:match('%.%.') and path:sub(1, 1) ~= '.' and path:sub(-1) ~= '.'
end

local interpolate_text

local function scalar_text(value, value_type)
  if value_type ~= 'MetaBlocks' then
    return pandoc.utils.stringify(value):gsub('%s+', ' ')
  end

  local blocks = {}
  for _, block in ipairs(value) do
    table.insert(blocks, pandoc.utils.stringify(block))
  end
  return table.concat(blocks, ' '):gsub('%s+', ' ')
end

local function metadata_value(path)
  if secrets[path] ~= nil then
    if in_metadata then
      record_error('Bitwarden values cannot be referenced from document metadata')
      return ''
    end
    return secrets[path]
  end
  if resolved[path] ~= nil then
    return resolved[path]
  end
  if resolving[path] then
    record_error('cyclic metadata path: ' .. path)
    return ''
  end
  if resolution_depth >= max_resolution_depth then
    record_error('metadata interpolation depth exceeded: ' .. path)
    return ''
  end

  local value = metadata
  for part in path:gmatch('[^.]+') do
    if type(value) ~= 'table' or value[part] == nil then
      record_error('unresolved metadata path: ' .. path)
      return ''
    end
    value = value[part]
  end

  local value_type = pandoc.utils.type(value)
  if value_type == 'MetaMap' or value_type == 'MetaList' or value_type == 'List' or value_type == 'table' then
    record_error('metadata path is not scalar: ' .. path)
    return ''
  end

  resolving[path] = true
  resolution_depth = resolution_depth + 1
  local text = scalar_text(value, value_type)
  text = interpolate_text(text)
  resolution_depth = resolution_depth - 1
  resolving[path] = nil
  resolved[path] = text
  return text
end

interpolate_text = function(text)
  local output = {}
  local position = 1
  local changed = false

  while true do
    local opening = text:find('{{', position, true)
    if opening == nil then
      table.insert(output, text:sub(position))
      break
    end

    table.insert(output, text:sub(position, opening - 1))
    if text:sub(opening, opening + 3) == '{{{{' then
      local closing = text:find('}}}}', opening + 4, true)
      if closing == nil then
        record_error('malformed metadata placeholder')
        table.insert(output, text:sub(opening))
        break
      end
      table.insert(output, '{{' .. text:sub(opening + 4, closing - 1) .. '}}')
      position = closing + 4
      changed = true
    else
      local closing = text:find('}}', opening + 2, true)
      if closing == nil then
        record_error('malformed metadata placeholder')
        table.insert(output, text:sub(opening))
        break
      end
      local path = text:sub(opening + 2, closing - 1):match('^%s*(.-)%s*$')
      if not valid_path(path) then
        record_error('malformed metadata placeholder')
      else
        local value = metadata_value(path)
        if expanded_bytes + #value > max_expanded_bytes then
          record_error('metadata expansion limit exceeded')
        else
          expanded_bytes = expanded_bytes + #value
          table.insert(output, value)
        end
      end
      position = closing + 2
      changed = true
    end
  end

  return table.concat(output), changed
end

local function decode_link_placeholders(target)
  local output = {}
  local position = 1

  while true do
    local raw_opening = target:find('{{', position, true)
    local encoded_opening = target:find('%%7[Bb]%%7[Bb]', position)
    local opening
    local encoded
    if raw_opening ~= nil and (encoded_opening == nil or raw_opening < encoded_opening) then
      opening = raw_opening
      encoded = false
    else
      opening = encoded_opening
      encoded = true
    end
    if opening == nil then
      table.insert(output, target:sub(position))
      break
    end

    table.insert(output, target:sub(position, opening - 1))
    local closing_start
    local closing_end
    if encoded then
      if target:sub(opening):match('^%%7[Bb]%%7[Bb]%%7[Bb]%%7[Bb]') then
        closing_start, closing_end = target:find('%%7[Dd]%%7[Dd]%%7[Dd]%%7[Dd]', opening + 12)
      else
        closing_start, closing_end = target:find('%%7[Dd]%%7[Dd]', opening + 6)
      end
    else
      if target:sub(opening, opening + 3) == '{{{{' then
        closing_start, closing_end = target:find('}}}}', opening + 4, true)
      else
        closing_start, closing_end = target:find('}}', opening + 2, true)
      end
    end
    if closing_start == nil then
      table.insert(output, target:sub(opening))
      break
    end

    local placeholder = target:sub(opening, closing_end):gsub('%%7[Bb]', '{'):gsub('%%7[Dd]', '}'):gsub('%%20', ' ')
    table.insert(output, placeholder)
    position = closing_end + 1
  end

  return table.concat(output)
end

local function interpolate_inlines(inlines)
  local output = pandoc.List()
  local run = pandoc.List()

  local function flush()
    if #run == 0 then
      return
    end
    local text_parts = {}
    for _, inline in ipairs(run) do
      if inline.t == 'Str' then
        table.insert(text_parts, inline.text)
      else
        table.insert(text_parts, ' ')
      end
    end
    local text, changed = interpolate_text(table.concat(text_parts))
    if changed then
      output:extend(pandoc.Inlines(text))
    else
      output:extend(run)
    end
    run = pandoc.List()
  end

  for _, inline in ipairs(inlines) do
    if inline.t == 'Str' or inline.t == 'Space' or inline.t == 'SoftBreak' then
      run:insert(inline)
    else
      flush()
      output:insert(inline)
    end
  end
  flush()
  return output
end

local function interpolate_link(link)
  local target = decode_link_placeholders(link.target)
  local changed
  target, changed = interpolate_text(target)
  if changed then
    link.target = target
  end
  if link.title ~= '' then
    link.title = interpolate_text(link.title)
  end
  return link
end

-- Infer before interpolation so a heading cannot move vault values into metadata.
-- Copy plain text only: heading links, images, and attributes remain in the body.
local function default_title(document, meta)
  if meta.title ~= nil and not pandoc.utils.stringify(meta.title):match('^%s*$') then
    return
  end
  local title
  pandoc.Pandoc(document.blocks):walk({Header = function(header)
    local text = pandoc.utils.stringify(header.content)
    if title == nil and header.level == 1 and not text:match('^%s*$') then
      title = text
    end
  end})
  if title == nil then
    local source = PANDOC_STATE.input_files[1] or 'document'
    title = source:match('([^/]+)$') or 'document'
    title = title:gsub('%.[^.]+$', '')
    if title == '' then title = 'document' end
  end
  meta.title = pandoc.MetaInlines({pandoc.Str(title)})
end

function Pandoc(document)
  metadata = document.meta
  local protected = os.getenv('BAKEDOCS_BITWARDEN') == 'true'
  if protected then
    local provider = dofile(PANDOC_SCRIPT_FILE:gsub('metadata%-interpolation.lua$', 'bitwarden.lua'))
    local public
    metadata, public, secrets = provider.layers(document.meta)
    default_title(document, public)
    -- The writer never sees vault metadata. Reject indirect references from
    -- public metadata too, including otherwise unused metadata fields.
    in_metadata = true
    public = pandoc.Pandoc({}, public):walk({Inlines = interpolate_inlines, Link = interpolate_link}).meta
    in_metadata = false
    document.meta = {}
    document = document:walk({Inlines = interpolate_inlines, Link = interpolate_link})
    document.meta = public
  else
    default_title(document, document.meta)
    document = document:walk({
      Inlines = interpolate_inlines,
      Link = interpolate_link,
    })
  end

  local messages = {}
  for message in pairs(errors) do
    table.insert(messages, message)
  end
  table.sort(messages)
  if #messages > 0 then
    error('metadata interpolation failed: ' .. table.concat(messages, '; '))
  end
  return document
end
