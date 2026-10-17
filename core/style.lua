local addonName, AV = ...

-- Style coordinates are VanaVista's: pixels at 1440p, origin top-left, y grows downward.
-- Root frames are scaled so one style pixel is one screen pixel at 1440p.

AV.Style = {}
local Style = AV.Style

local ASSET_ROOT = string.format('Interface\\AddOns\\%s\\assets\\', addonName)
local FONT_ROOT = string.format('Interface\\AddOns\\%s\\fonts\\', addonName)

function Style.AssetPath(relative)
    return ASSET_ROOT .. relative:gsub('/', '\\')
end

-- Paths under the game's own Fonts\ folder are used as-is; anything else ships with the addon.
function Style.FontPath(file)
    if file:find('^Fonts\\') then
        return file
    end
    return FONT_ROOT .. file
end

-- '#RRGGBBAA' -> r, g, b, a in 0..1
function Style.Color(hex)
    if not hex then
        return 1, 1, 1, 1
    end
    local r, g, b, a = hex:match('#(%x%x)(%x%x)(%x%x)(%x?%x?)')
    if not r then
        return 1, 1, 1, 1
    end
    a = (a ~= '' and a) or 'FF'
    return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255, tonumber(a, 16) / 255
end

function Style.Place(region, parent, pos)
    region:ClearAllPoints()
    region:SetPoint('TOPLEFT', parent, 'TOPLEFT', pos[1], -pos[2])
end

-- spec = { path, pos = {x, y}, size = {w, h}, color }
function Style.Image(parent, layer, spec, subLevel)
    local texture = parent:CreateTexture(nil, layer, nil, subLevel)
    texture:SetTexture(Style.AssetPath(spec.path))
    texture:SetSize(spec.size[1], spec.size[2])
    Style.Place(texture, parent, spec.pos or { 0, 0 })
    texture:SetVertexColor(Style.Color(spec.color))
    return texture
end

function Style.HasAtlas(atlas)
    return C_Texture and C_Texture.GetAtlasInfo and AV.SafeValue(C_Texture.GetAtlasInfo, atlas) ~= nil
end

-- Applies a Blizzard atlas, or fallback = { path, coords = {l, r, t, b} } when the client lacks it.
-- Returns true when the atlas was used.
function Style.SetAtlas(texture, atlas, fallback)
    if Style.HasAtlas(atlas) and pcall(texture.SetAtlas, texture, atlas) then
        return true
    end
    AV.LogOnce('atlas:' .. atlas, 'atlas %s missing; using fallback', atlas)
    if fallback then
        texture:SetTexture(fallback.path)
        if fallback.coords then
            texture:SetTexCoord(unpack(fallback.coords))
        end
    end
    return false
end

-- Horizontal three-slice: caps keep their aspect, the middle stretches.
-- spec = { path, texSize = {w, h}, cap = texture pixels per cap, color }
function Style.ThreeSlice(parent, layer, spec, width, height, subLevel)
    local texW, texH = spec.texSize[1], spec.texSize[2]
    local capTex = spec.cap
    local capWidth = capTex * height / texH
    local path = Style.AssetPath(spec.path)
    local u1, u2 = capTex / texW, 1 - capTex / texW

    local pieces = {}
    local function piece(left, right, x, w)
        local texture = parent:CreateTexture(nil, layer, nil, subLevel)
        texture:SetTexture(path)
        texture:SetTexCoord(left, right, 0, 1)
        texture:SetSize(w, height)
        texture:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, 0)
        pieces[#pieces + 1] = texture
    end
    piece(0, u1, 0, capWidth)
    piece(u1, u2, capWidth, width - capWidth * 2)
    piece(u2, 1, width - capWidth, capWidth)

    local slice = { pieces = pieces }
    function slice:SetVertexColor(r, g, b, a)
        for _, texture in ipairs(self.pieces) do
            texture:SetVertexColor(r, g, b, a)
        end
    end
    slice:SetVertexColor(Style.Color(spec.color))
    return slice
end

local FALLBACK_FONT = 'Fonts\\FRIZQT__.TTF'
local pendingFonts = {}

-- On a fresh login an addon's font files can still be loading when frames are built, so
-- SetFont fails (and SetText on a font-less string errors). Friz Quadrata, a game font that is
-- always loaded, stands in until the loading screen ends; then the real font is retried.
function Style.SetFont(fontString, file, size, flags)
    if fontString:SetFont(Style.FontPath(file), size, flags) then
        return
    end
    fontString:SetFont(FALLBACK_FONT, size, flags)
    pendingFonts[#pendingFonts + 1] = { fontString = fontString, file = file, size = size, flags = flags }
    AV.LogOnce('font:' .. file, 'font %s not ready; Friz Quadrata until the loading screen ends', file)
end

local fontRetry = CreateFrame('Frame')
fontRetry:RegisterEvent('PLAYER_ENTERING_WORLD')
fontRetry:SetScript('OnEvent', function()
    local failed = {}
    for _, pending in ipairs(pendingFonts) do
        if pending.fontString:SetFont(Style.FontPath(pending.file), pending.size, pending.flags) then
            AV.LogOnce('fontRetry:' .. pending.file, 'font %s loaded on retry', pending.file)
        else
            failed[#failed + 1] = pending
            AV.LogOnce('fontFail:' .. pending.file, 'font %s still failed after the loading screen', pending.file)
        end
    end
    pendingFonts = failed
end)

-- spec = { pos, size, color, stroke, font = 'name'|'number', alignRight | alignCenter, outline }
-- outline: font flags, default 'OUTLINE'; '' gives a plain face (shadow only, as GameFontNormal).
-- The stroke colour becomes the drop shadow; FontStrings only support a black outline.
function Style.Text(parent, spec, fonts)
    local text = parent:CreateFontString(nil, 'OVERLAY')
    local file = fonts[spec.font or 'name'] or fonts.name
    Style.SetFont(text, file, spec.size or 12, spec.outline or 'OUTLINE')
    text:SetTextColor(Style.Color(spec.color))
    if spec.stroke then
        text:SetShadowColor(Style.Color(spec.stroke))
        text:SetShadowOffset(1, -1)
    end
    local pos = spec.pos or { 0, 0 }
    text:ClearAllPoints()
    if spec.alignRight then
        text:SetPoint('TOPRIGHT', parent, 'TOPLEFT', pos[1], -pos[2])
        text:SetJustifyH('RIGHT')
    elseif spec.alignCenter then
        text:SetPoint('TOP', parent, 'TOPLEFT', pos[1], -pos[2])
        text:SetJustifyH('CENTER')
    else
        text:SetPoint('TOPLEFT', parent, 'TOPLEFT', pos[1], -pos[2])
        text:SetJustifyH('LEFT')
    end
    return text
end

-- Scale that maps one style pixel to one screen pixel at 1440p, for a frame parented to UIParent.
function Style.RootScale()
    local height = UIParent:GetHeight()
    if not height or height <= 0 then
        return 1
    end
    return height / 1440 * ((AV.db and AV.db.scale) or 1)
end
