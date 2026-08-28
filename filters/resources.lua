-- SPDX-FileCopyrightText: 2026 Marcus Baw
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Pandoc runs this filter over its parsed document tree before writing HTML.
-- It keeps generated files portable while enforcing the source-content boundary:
-- local presentation images are embedded, offline renders reject remote images,
-- required metadata is normalised, and executable attributes or unsafe links fail.
-- The bakedocs shell command supplies these environment variables for each render.
local embed_local_images = os.getenv('BAKEDOCS_EMBED_LOCAL_IMAGES') == '1'
local offline = os.getenv('BAKEDOCS_OFFLINE') == '1'
local brand_dir = os.getenv('BAKEDOCS_BRAND_DIR')

local function resource_kind(source)
  local lower_source = source:lower()
  local scheme = lower_source:match('^([a-z][a-z0-9+.-]*):')
  local remote = lower_source:match('^//') or (scheme ~= nil and scheme ~= 'data')
  return scheme, remote
end

-- Return the original resource, reject it under offline policy, or embed local
-- content as a data URI so moving the generated slide deck cannot break it.
local function transform_resource(source, embed)
  local scheme, remote = resource_kind(source)

  if remote then
    if offline then
      error('remote image is not permitted in offline mode: ' .. source)
    end
    return source
  end

  if embed and scheme ~= 'data' then
    local mime_type, contents = pandoc.mediabag.fetch(source)
    return pandoc.mediabag.make_data_uri(mime_type, contents)
  end

  return source
end

-- Pandoc supports attributes on many Markdown elements. Reject attributes that
-- could execute code or load resources outside the explicit Image policy.
local function validate_attributes(element)
  if element.attributes == nil then
    return
  end

  for name in pairs(element.attributes) do
    local lower_name = name:lower()

    if lower_name:match('^on[a-z]') then
      error('event-handler attributes are not permitted: ' .. name)
    end
    if lower_name == 'style' then
      error('source style attributes are not supported')
    end
    if lower_name == 'data-background-video' or lower_name == 'data-background-iframe' then
      error('Reveal background video and iframe attributes are not supported')
    end
  end
end

function Meta(meta)
  local changed = false

  if meta.title == nil or pandoc.utils.stringify(meta.title):match('^%s*$') then
    error('source metadata requires a non-empty title')
  end

  if meta.lang == nil and meta.language ~= nil then
    meta.lang = meta.language
    changed = true
  end

  -- Brand-relative logos become data URIs in document HTML and PDF intermediates.
  if meta.logo ~= nil then
    local logo = pandoc.utils.stringify(meta.logo)
    local scheme, remote = resource_kind(logo)

    if remote then
      if offline then
        error('remote logo is not permitted in offline mode: ' .. logo)
      end
    elseif scheme ~= 'data' then
      if logo:sub(1, 1) ~= '/' then
        logo = brand_dir .. '/' .. logo
      end
      local mime_type, contents = pandoc.mediabag.fetch(logo)
      meta.logo = pandoc.MetaString(pandoc.mediabag.make_data_uri(mime_type, contents))
      changed = true
    end
  end

  if changed then
    return meta
  end
end

function Image(image)
  validate_attributes(image)
  local transformed = transform_resource(image.src, embed_local_images)
  if transformed ~= image.src then
    image.src = transformed
    return image
  end
end

function Header(header)
  validate_attributes(header)
  -- Reveal.js background images live on heading attributes rather than Image nodes.
  local background_image = header.attributes['data-background-image']
  if background_image ~= nil then
    header.attributes['data-background-image'] = transform_resource(background_image, true)
    return header
  end
end

function Link(link)
  validate_attributes(link)
  local normalized_target = link.target:lower():gsub('[%z\1-\32]', '')
  local scheme = normalized_target:match('^([a-z][a-z0-9+.-]*):')
  if scheme ~= nil and scheme ~= 'http' and scheme ~= 'https' and scheme ~= 'mailto' and scheme ~= 'tel' then
    error('unsafe link scheme is not permitted: ' .. scheme)
  end
end

function Inline(element)
  validate_attributes(element)
end

function Block(element)
  validate_attributes(element)
end
