local _, EUI = ...

-- The page list's Heart crystal backdrop (canvas board "Crystal backdrop", variant A): still art,
-- a bobbing crystal, twinkling glints, rising motes and three spirits spiralling into its tip.
-- Art and paths come from tools/crystalArt.py, in page list units (200 x 704).

EUI.Config = EUI.Config or {}
local Config = EUI.Config
local Style = EUI.Style

local STRENGTH = 0.6
local UNITS_W, UNITS_H = 200, 704
local GEM_TOP, GEM_HEIGHT = 140, 512
-- The motes texture is one 200 x 800 tile, wrapped; they rise one page list height in 50 s.
local MOTE_TILE, MOTE_SPEED = 800, 704 / 50
-- Each spirit is a streak of glow sprites over this share of its path.
local STREAK = { 0.07, 0.055, 0.045 }
local STREAK_SPRITES = 8
local SPIRIT_SIZE = 12
local SPIRIT_COLOR = '#BFF3FFFF'
local GLINT_COLOR = '#EAFDFF'

local function asset(name)
    return Style.AssetPath('settings/' .. name)
end

-- points: { { x, y }, ... } -> sample(u) giving the point at share u (0..1) of the path's length.
local function pathSampler(points)
    local lengths, total = { 0 }, 0
    for i = 2, #points do
        local dx, dy = points[i][1] - points[i - 1][1], points[i][2] - points[i - 1][2]
        total = total + math.sqrt(dx * dx + dy * dy)
        lengths[i] = total
    end
    return function(u)
        local target = u * total
        for i = 2, #points do
            if lengths[i] >= target then
                local span = lengths[i] - lengths[i - 1]
                local t = span > 0 and (target - lengths[i - 1]) / span or 0
                local a, b = points[i - 1], points[i]
                return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t
            end
        end
        local last = points[#points]
        return last[1], last[2]
    end
end

function Config.CreateCrystal(parent)
    local data = EUI.CrystalData
    local frame = CreateFrame('Frame', nil, parent)
    frame:SetClipsChildren(true)
    frame:SetAlpha(STRENGTH)

    local back = frame:CreateTexture(nil, 'BACKGROUND')
    back:SetTexture(asset('crystalBack'))
    back:SetTexCoord(0, 400 / 512, 0, 1408 / 2048)
    back:SetAllPoints()

    local motes = frame:CreateTexture(nil, 'BACKGROUND', nil, 1)
    motes:SetTexture(asset('crystalMotes'), 'REPEAT', 'REPEAT')
    motes:SetAllPoints()

    local gem = frame:CreateTexture(nil, 'BORDER')
    gem:SetTexture(asset('crystalGem'))
    gem:SetTexCoord(0, 400 / 512, 0, 1)
    local bob = gem:CreateAnimationGroup()
    bob:SetLooping('BOUNCE')
    local rise = bob:CreateAnimation('Translation')
    rise:SetOffset(0, 6)
    rise:SetDuration(3.5)
    rise:SetSmoothing('IN_OUT')
    bob:Play()

    local glints = {}
    local r, g, b = Style.Color(GLINT_COLOR .. 'FF')
    for i, glint in ipairs(data.glints) do
        local texture = frame:CreateTexture(nil, 'ARTWORK')
        texture:SetTexture(asset('crystalGlint'))
        texture:SetVertexColor(r, g, b, glint[4] and 0.5 or 0.45)
        local twinkle = texture:CreateAnimationGroup()
        twinkle:SetLooping('BOUNCE')
        local fade = twinkle:CreateAnimation('Alpha')
        fade:SetFromAlpha(0.2)
        fade:SetToAlpha(1)
        fade:SetSmoothing('IN_OUT')
        if glint[4] then
            fade:SetDuration(2.5)
            fade:SetStartDelay(1.4)
        else
            fade:SetDuration(1.7)
        end
        twinkle:Play()
        glints[i] = texture
    end

    local spirits = {}
    for i, orbit in ipairs(data.orbits) do
        local sprites = {}
        for k = 1, STREAK_SPRITES do
            local sprite = frame:CreateTexture(nil, 'OVERLAY')
            sprite:SetTexture(asset('crystalSpirit'))
            sprite:SetBlendMode('ADD')
            local cr, cg, cb = Style.Color(SPIRIT_COLOR)
            -- Brightest at the leading end.
            sprite:SetVertexColor(cr, cg, cb, 0.08 + 0.32 * (k / STREAK_SPRITES))
            sprites[k] = sprite
        end
        spirits[i] = { sample = pathSampler(orbit.points), period = orbit.period, reverse = orbit.reverse,
            streak = STREAK[i] or 0.05, sprites = sprites }
    end

    local function place(region, x, y, sx, sy)
        region:SetPoint('CENTER', frame, 'TOPLEFT', x * sx, -y * sy)
    end

    local function layout()
        local sx, sy = frame:GetWidth() / UNITS_W, frame:GetHeight() / UNITS_H
        gem:ClearAllPoints()
        gem:SetPoint('TOPLEFT', frame, 'TOPLEFT', 0, -GEM_TOP * sy)
        gem:SetSize(UNITS_W * sx, GEM_HEIGHT * sy)
        for i, glint in ipairs(data.glints) do
            glints[i]:SetSize(glint[3] * 2 * sx, glint[3] * 2 * sx)
            glints[i]:ClearAllPoints()
            place(glints[i], glint[1], glint[2], sx, sy)
        end
        for _, spirit in ipairs(spirits) do
            for _, sprite in ipairs(spirit.sprites) do
                sprite:SetSize(SPIRIT_SIZE * sx, SPIRIT_SIZE * sx)
            end
        end
    end
    frame:SetScript('OnSizeChanged', layout)

    local clock = 0
    frame:SetScript('OnUpdate', function(_, elapsed)
        clock = clock + elapsed
        local sx, sy = frame:GetWidth() / UNITS_W, frame:GetHeight() / UNITS_H
        local offset = (clock * MOTE_SPEED / MOTE_TILE) % 1
        motes:SetTexCoord(0, 1, offset, offset + UNITS_H / MOTE_TILE)
        for _, spirit in ipairs(spirits) do
            local head = (clock / spirit.period) % 1
            for k, sprite in ipairs(spirit.sprites) do
                -- k = STREAK_SPRITES is the leading sprite.
                local along = spirit.streak * (k - 1) / (STREAK_SPRITES - 1)
                local u = spirit.reverse and (1 - head - along) or (head + along)
                local x, y = spirit.sample(u % 1)
                sprite:ClearAllPoints()
                place(sprite, x, y, sx, sy)
            end
        end
    end)
    return frame
end
