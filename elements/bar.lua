local _, EUI = ...

-- Layered bar: background frame art, a StatusBar fill and foreground frame art. Values may be
-- secret, so the StatusBar sizes the fill without Lua arithmetic.

EUI.Bar = {}
local Bar = {}
Bar.__index = Bar

local Style = EUI.Style

local function frameLayer(owner, layer, spec, barSpec, subLevel)
    if barSpec.slice then
        local sliceSpec = { path = spec.path, color = spec.color, texSize = barSpec.slice.texSize, cap = barSpec.slice.cap }
        return Style.ThreeSlice(owner, layer, sliceSpec, barSpec.width, barSpec.height, subLevel)
    end
    return Style.Image(owner, layer, { path = spec.path, color = spec.color, pos = { 0, 0 }, size = { barSpec.width, barSpec.height } }, subLevel)
end

local function predictionSegment(clip, spec, anchor, color)
    local bar = CreateFrame('StatusBar', nil, clip)
    bar:SetSize(spec.fill.width, spec.height)
    bar:SetPoint('TOPLEFT', anchor, 'TOPRIGHT', 0, 0)
    bar:SetStatusBarTexture(Style.AssetPath(spec.fill.path))
    bar:SetStatusBarColor(Style.Color(color))
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    return bar
end

-- Incoming-heal and absorb segments chained from the fill's right edge. Amounts and max health
-- may be secret, so the engine sizes them: StatusBars the width of the fill, clipped to the
-- fill area. The calculator clamps absorbs to missing health minus incoming heals.
local function createPrediction(self, frame, spec, predictionSpec)
    if not (CreateUnitHealPredictionCalculator and UnitGetDetailedHealPrediction) then
        EUI.LogOnce('prediction:missing', 'heal prediction: API missing')
        return
    end
    local ok, calculator = pcall(CreateUnitHealPredictionCalculator)
    if not ok or not calculator then
        EUI.LogOnce('prediction:create', 'heal prediction: calculator failed: %s', tostring(calculator))
        return
    end
    local clip = CreateFrame('Frame', nil, frame)
    clip:SetSize(spec.fill.width, spec.height)
    clip:SetPoint('TOPLEFT', frame, 'TOPLEFT', spec.fill.x, 0)
    clip:SetFrameLevel(self.status:GetFrameLevel() + 1)
    if clip.SetClipsChildren then
        clip:SetClipsChildren(true)
    end
    local heals = predictionSegment(clip, spec, self.status:GetStatusBarTexture(), predictionSpec.color)
    local absorbs = predictionSegment(clip, spec, heals:GetStatusBarTexture(), predictionSpec.absorbColor)
    local missingHealth = Enum.UnitDamageAbsorbClampMode and Enum.UnitDamageAbsorbClampMode.MissingHealth or 0
    if not pcall(calculator.SetDamageAbsorbClampMode, calculator, missingHealth) then
        EUI.LogOnce('prediction:clamp', 'absorbs: SetDamageAbsorbClampMode failed')
    end
    self.prediction = { bar = heals, absorbs = absorbs, calculator = calculator, spec = predictionSpec }
end

-- Spell-cost segment ending at the fill's right edge: a reverse-filling StatusBar the width of
-- the fill, so the engine sizes the cost against a possibly secret maximum.
local function createCostPreview(self, frame, spec, costSpec)
    local clip = CreateFrame('Frame', nil, frame)
    clip:SetSize(spec.fill.width, spec.height)
    clip:SetPoint('TOPLEFT', frame, 'TOPLEFT', spec.fill.x, 0)
    clip:SetFrameLevel(self.status:GetFrameLevel() + 1)
    if clip.SetClipsChildren then
        clip:SetClipsChildren(true)
    end
    local bar = CreateFrame('StatusBar', nil, clip)
    bar:SetSize(spec.fill.width, spec.height)
    bar:SetPoint('TOPRIGHT', self.status:GetStatusBarTexture(), 'TOPRIGHT', 0, 0)
    bar:SetStatusBarTexture(Style.AssetPath(spec.fill.path))
    bar:SetStatusBarColor(Style.Color(costSpec.color))
    if bar.SetReverseFill then
        bar:SetReverseFill(true)
    end
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    -- On a successful cast the segment fades while the real fill drops to its new value.
    local fade = bar:CreateAnimationGroup()
    local alpha = fade:CreateAnimation('Alpha')
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0)
    alpha:SetDuration(costSpec.fade or 0.25)
    fade:SetScript('OnFinished', function()
        bar:SetValue(0)
        bar:SetAlpha(1)
    end)
    self.cost = { bar = bar, fade = fade }
end

-- spec: see styles/shared.lua (rowBar / wideBar / allyBar).
-- opts = { prediction = { color }, cost = { color, fade } }
function EUI.Bar.Create(parent, spec, pos, opts)
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

    if opts and opts.prediction then
        createPrediction(self, frame, spec, opts.prediction)
    end
    if opts and opts.cost then
        createCostPreview(self, frame, spec, opts.cost)
    end

    -- Foreground art sits above the fill and the heal prediction.
    local overlay = CreateFrame('Frame', nil, frame)
    overlay:SetAllPoints(frame)
    overlay:SetFrameLevel(status:GetFrameLevel() + 2)
    self.overlay = overlay

    self.fg = frameLayer(overlay, 'ARTWORK', spec.fg, spec)

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

-- amount: plain spell cost, or nil/0 to clear. maxValue may be secret.
-- Clearing is ignored while a commit fade runs, since the cast's STOP follows its SUCCEEDED.
function Bar:SetCost(amount, maxValue)
    local cost = self.cost
    if not cost then
        return
    end
    if not amount or amount <= 0 then
        if not cost.fade:IsPlaying() then
            cost.bar:SetValue(0)
        end
        return
    end
    cost.fade:Stop()
    cost.bar:SetAlpha(1)
    pcall(cost.bar.SetMinMaxValues, cost.bar, 0, maxValue or 1)
    cost.bar:SetValue(amount)
end

function Bar:CommitCost()
    if self.cost then
        self.cost.fade:Play()
    end
end

-- amount: incoming heals; absorbs: damage absorb shields. amount, maxValue and absorbs may be
-- secret.
function Bar:SetIncoming(amount, maxValue, absorbs)
    local prediction = self.prediction
    if not prediction then
        return
    end
    for _, pair in ipairs({ { prediction.bar, amount }, { prediction.absorbs, absorbs } }) do
        local bar = pair[1]
        pcall(bar.SetMinMaxValues, bar, 0, maxValue or 1)
        pcall(bar.SetValue, bar, pair[2] or 0)
    end
end

-- Incoming heals and absorbs on unit from everyone, via the engine-side calculator.
function Bar:ShowIncomingHeals(unit, maxValue)
    local prediction = self.prediction
    if not prediction then
        return
    end
    if prediction.spec.hidden then
        self:SetIncoming(0)
        return
    end
    local ok, err = pcall(UnitGetDetailedHealPrediction, unit, 'player', prediction.calculator)
    if not ok then
        EUI.LogOnce('prediction:populate', 'heal prediction: populate failed: %s', tostring(err))
        self:SetIncoming(0)
        return
    end
    local okIncoming, incoming = pcall(prediction.calculator.GetIncomingHeals, prediction.calculator)
    if not okIncoming then
        EUI.LogOnce('prediction:read', 'heal prediction: GetIncomingHeals failed: %s', tostring(incoming))
        self:SetIncoming(0)
        return
    end
    local okAbsorbs, absorbs = pcall(prediction.calculator.GetDamageAbsorbs, prediction.calculator)
    if not okAbsorbs then
        EUI.LogOnce('prediction:absorbs', 'absorbs: GetDamageAbsorbs failed: %s', tostring(absorbs))
        absorbs = 0
    end
    self:SetIncoming(incoming, maxValue, absorbs)
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
