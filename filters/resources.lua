-- SPDX-FileCopyrightText: 2026 Marcus Baw
-- SPDX-License-Identifier: GPL-3.0-or-later

-- Pandoc runs this filter over its parsed document tree before writing HTML.
-- It keeps generated files portable while enforcing the source-content boundary:
-- local presentation images are embedded, offline renders reject remote images,
-- required metadata is normalised, and executable attributes or unsafe links fail.
-- The bakedocs shell command supplies these environment variables for each render.
if pandoc.mediabag.make_data_uri == nil then
  error('bakedocs requires Pandoc 3.7.1 or later')
end

local embed_local_images = os.getenv('BAKEDOCS_EMBED_LOCAL_IMAGES') == '1'
local offline = os.getenv('BAKEDOCS_OFFLINE') == '1'
local brand_logo = os.getenv('BAKEDOCS_BRAND_LOGO') or ''
local output_mode = os.getenv('BAKEDOCS_OUTPUT_MODE') or ''
local document_header = os.getenv('BAKEDOCS_DOCUMENT_HEADER') or ''
local reveal_header = os.getenv('BAKEDOCS_REVEAL_HEADER') or ''
local revealjs_url = os.getenv('BAKEDOCS_REVEALJS_URL') or ''
local supported_languages = {
  af = true, alt = true, am = true, ar = true, ['as'] = true, ast = true,
  az = true, be = true, bg = true, bn = true, bo = true, br = true, bs = true,
  bua = true, ca = true, ckb = true, cs = true, cu = true, cy = true,
  cz = true, da = true, de = true, dsb = true, el = true, en = true,
  eo = true, es = true, et = true, eu = true, fa = true, fi = true,
  fil = true, fr = true, fur = true, ga = true, gd = true, gl = true,
  grc = true, gu = true, ha = true, he = true, hi = true, hr = true,
  hsb = true, hu = true, hy = true, ia = true, id = true, ['is'] = true,
  it = true, ja = true, ka = true, km = true, kmr = true, kn = true,
  ko = true, la = true, lb = true, lo = true, lt = true, lv = true,
  mk = true, ml = true, mn = true, mr = true, ms = true, nb = true,
  nko = true, nl = true, nn = true, no = true, oc = true, ['or'] = true,
  pa = true, pl = true, pms = true, pt = true, rm = true, ro = true,
  ru = true, se = true, si = true, sk = true, sl = true, sq = true,
  sr = true, sv = true, ta = true, te = true, th = true, tk = true,
  tr = true, ua = true, ug = true, uk = true, ur = true, vi = true,
  zh = true,
}

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
      error('remote image is not permitted in offline mode')
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

  pandoc.Pandoc({}, meta):walk({
    Image = function()
      error('images are not permitted in document metadata')
    end,
    RawInline = function()
      error('raw content is not permitted in document metadata')
    end,
    RawBlock = function()
      error('raw content is not permitted in document metadata')
    end,
  })

  meta['header-includes'] = nil
  meta['include-before'] = nil
  meta['include-after'] = nil
  meta.css = nil
  if output_mode == 'document' then
    local file = io.open(document_header, 'rb')
    if file == nil then
      error('trusted document style header could not be loaded')
    end
    local contents = file:read('*a')
    file:close()
    meta['header-includes'] = pandoc.MetaBlocks({pandoc.RawBlock('html', contents)})
  elseif output_mode == 'slides' then
    local file = io.open(reveal_header, 'rb')
    if file == nil then
      error('trusted Reveal style header could not be loaded')
    end
    local contents = file:read('*a')
    file:close()
    meta['header-includes'] = pandoc.MetaBlocks({pandoc.RawBlock('html', contents)})
    meta['revealjs-url'] = pandoc.MetaString(revealjs_url)
  else
    error('bakedocs output mode is invalid')
  end

  if brand_logo == '' then
    meta.logo = nil
  else
    meta.logo = pandoc.MetaString(brand_logo)
  end

  if meta.title == nil or pandoc.utils.stringify(meta.title):match('^%s*$') then
    error('source metadata requires a non-empty title')
  end

  if meta.lang == nil and meta.language ~= nil then
    meta.lang = meta.language
    changed = true
  end
  if meta.lang ~= nil then
    local language = pandoc.utils.stringify(meta.lang)
    local primary = language:match('^([A-Za-z]+)')
    if not language:match('^[A-Za-z][A-Za-z0-9]*[-A-Za-z0-9]*$') or language:match('%-%-') or language:sub(-1) == '-' or primary == nil or not supported_languages[primary:lower()] then
      error('document language is invalid')
    end
  end

  -- Brand-selected local logos become data URIs in document HTML and PDF intermediates.
  if meta.logo ~= nil then
    local logo = pandoc.utils.stringify(meta.logo)
    local scheme, remote = resource_kind(logo)

    if remote then
      if offline then
        error('remote logo is not permitted in offline mode')
      end
    elseif scheme ~= 'data' then
      local loaded, mime_type, contents = pcall(pandoc.mediabag.fetch, logo)
      if not loaded then
        error('logo resource could not be loaded')
      end
      if not mime_type:match('^image/') or #contents > 10 * 1024 * 1024 then
        error('logo resource is not a supported image within the 10 MiB limit')
      end
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
    error('unsafe link scheme is not permitted')
  end
end

function Inline(element)
  validate_attributes(element)
end

function Block(element)
  validate_attributes(element)
end
