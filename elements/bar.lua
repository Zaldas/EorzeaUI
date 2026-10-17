local _, AV = ...

-- Layered bar: background frame art, a StatusBar fill, foreground frame art, and a glow
-- anchored to the fill's right edge so it tracks secret values without Lua arithmetic.

AV.Bar = {}
local Bar = {}
Bar.__index = Bar

local Style = AV.Style

local function frameLayer(owner, layer, spec, barSpec, subLevel)
    if barSpec.slice then
        local sliceSpec = { path = spec.path, color = spec.color, texSize = barSpec.slice.texSize, cap = barSpec.slice.cap }
        return Style.ThreeSlice(owner, layer, sliceSpec, barSpec.width, barSpec.height, subLevel)
    end
    return Style.Image(owner, layer, { path = spec.path, color = spec.color, pos = { 0, 0 }, size = { barSpec.width, barSpec.height } }, subLevel)
end

-- spec: see styles/xiv.lua (xivBar / wideBar)
function AV.Bar.Create(parent, spec, pos)
    local self = setmetatable({ spec = spec }, Bar)

    local frame = CreateFrame('Frame', nil, parent)
    frame:SetSize(spec.width, spec.height)
    Style.Place(frame, parent, pos or { 0, 0 })
    self.frame = frame

    self.bg = frameLayer(frame, 'BACKGROUND', spec.bg, spec)

    local status = CreateFrame('StatusBar', nil, frame)
    status:SetSize(spec.fill.width, spec.height)
    status:SetPoint('TOPLEFT', frame, 'TOPLEFT', spec.fill.x, 0)
    status:SetStatusBarTexture(Style.AssetPath(spec.fill.path))
    status:SetStatusBarColor(Style.Color(spec.fill.color))
    status:SetMinMaxValues(0, 1)
    status:SetValue(0)
    self.status = status

    -- Foreground art and glow sit above the fill.
    local overlay = CreateFrame('Frame', nil, frame)
    overlay:SetAllPoints(frame)
    overlay:SetFrameLevel(status:GetFrameLevel() + 1)
    self.overlay = overlay

    self.fg = frameLayer(overlay, 'ARTWORK', spec.fg, spec)

    if spec.glow then
        local glow = overlay:CreateTexture(nil, 'OVERLAY')
        glow:SetTexture(Style.AssetPath(spec.glow.path))
        glow:SetSize(spec.glow.width, spec.height)
        glow:SetPoint('RIGHT', status:GetStatusBarTexture(), 'RIGHT', 0, 0)
        glow:SetVertexColor(Style.Color(spec.glow.color))
        self.glow = glow
    end
    if spec.glowSides then
        local sides = overlay:CreateTexture(nil, 'OVERLAY')
        sides:SetTexture(Style.AssetPath(spec.glowSides.path))
        sides:SetSize(spec.glowSides.width, spec.height)
        sides:SetPoint('TOPLEFT', frame, 'TOPLEFT', spec.glowSides.x, 0)
        sides:SetVertexColor(Style.Color(spec.glowSides.color))
        self.glowSides = sides
    end

    return self
end

function Bar:SetRange(maxValue)
    pcall(self.status.SetMinMaxValues, self.status, 0, maxValue or 1)
end

-- value may be secret; easing runs engine-side.
function Bar:SetValue(value, smooth)
    local interpolation = smooth and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
    if interpolation then
        if pcall(self.status.SetValue, self.status, value, interpolation) then
            return
        end
    end
    pcall(self.status.SetValue, self.status, value)
end

-- duration: LuaDurationObject from UnitCastingDuration/UnitChannelDuration.
function Bar:SetTimer(duration, remaining)
    if not (self.status.SetTimerDuration and Enum.StatusBarTimerDirection) then
        return false
    end
    local direction = remaining and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime
    local interpolation = Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate
    return pcall(self.status.SetTimerDuration, self.status, duration, interpolation, direction)
end

function Bar:SetFrameColor(hex)
    local r, g, b, a = Style.Color(hex)
    self.bg:SetVertexColor(r, g, b, a)
    self.fg:SetVertexColor(r, g, b, a)
end

function Bar:SetFillColor(hex)
    self.status:SetStatusBarColor(Style.Color(hex))
end
