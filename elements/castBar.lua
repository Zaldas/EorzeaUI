local _, AV = ...

-- Cast timestamps and names are secret on Forever. The bar runs from a duration object via
-- StatusBar:SetTimerDuration; the name goes straight to SetText. No remaining-time text.

AV.CastBar = {}
local CastBar = {}
CastBar.__index = CastBar

-- spec = { bar, txtName = { ..., width }, failure = { color, hold },
-- uninterruptible = { color, lock = { path, pos, size, color } } }.
-- unit may be nil until SetUnit.
-- onVisibility(shown), when set, is called whenever the bar shows or hides.
function AV.CastBar.Create(parent, unit, spec, fonts, pos)
    local self = setmetatable({ unit = unit, spec = spec }, CastBar)
    self.bar = AV.Bar.Create(parent, spec.bar, pos)
    self.name = AV.Style.Text(self.bar.overlay, spec.txtName, fonts)
    if spec.txtName.width then
        self.name:SetWidth(spec.txtName.width)
        self.name:SetWordWrap(false)
    end
    local lockSpec = spec.uninterruptible and spec.uninterruptible.lock
    if lockSpec then
        self.lock = AV.Style.Image(self.bar.overlay, 'OVERLAY', lockSpec)
        self.lock:SetAlpha(0)
    end
    self.bar.frame:Hide()
    return self
end

function CastBar:SetUnit(unit)
    self.unit = unit
end

local function setVisible(self, shown)
    self.bar.frame:SetShown(shown)
    if self.onVisibility then
        self.onVisibility(shown)
    end
end

-- notInterruptible is secret for other units' casts; EvaluateColorFromBoolean picks the colour
-- engine-side, and SetAlphaFromBoolean shows the lock (default alphas: 255 true, 0 false).
local function applyInterruptible(self, notInterruptible)
    local spec = self.spec.uninterruptible
    if type(notInterruptible) == 'nil' then
        notInterruptible = false
    end
    if self.lock and self.lock.SetAlphaFromBoolean then
        local ok, err = pcall(self.lock.SetAlphaFromBoolean, self.lock, notInterruptible)
        if not ok then
            AV.LogOnce('cast:lock', 'SetAlphaFromBoolean failed: %s', tostring(err))
        end
    end
    if not (spec and C_CurveUtil and C_CurveUtil.EvaluateColorFromBoolean) then
        return
    end
    local ok, color = pcall(C_CurveUtil.EvaluateColorFromBoolean, notInterruptible,
        CreateColor(AV.Style.Color(spec.color)), CreateColor(AV.Style.Color(self.spec.bar.fill.color)))
    if not ok or not color then
        AV.LogOnce('cast:interruptible', 'EvaluateColorFromBoolean failed: %s', tostring(color))
        return
    end
    local bar = self.bar
    pcall(function()
        local r, g, b, a = color:GetRGBA()
        bar.status:SetStatusBarColor(r, g, b, a)
        bar.bg:SetVertexColor(r, g, b, a)
        bar.fg:SetVertexColor(r, g, b, a)
    end)
end

local function resetColors(self)
    local bar = self.bar
    bar:SetFillColor(self.spec.bar.fill.color)
    bar:SetFrameColor(self.spec.bar.bg.color)
    if self.lock then
        self.lock:SetAlpha(0)
    end
end

-- interruptIndex, castBarIndex: positions of notInterruptible and castBarID among infoFn's returns.
local function tryStart(self, durationFn, infoFn, remaining, interruptIndex, castBarIndex)
    if type(durationFn) ~= 'function' then
        return false
    end
    -- type() works on secret values; == nil comparisons may not.
    local info = { infoFn(self.unit) }
    local name = info[1]
    if type(name) == 'nil' then
        return false
    end
    local unitKind = self.unit:gsub('%d', '')
    local ok, duration = pcall(durationFn, self.unit)
    if not ok then
        AV.LogOnce('cast:duration:' .. unitKind, 'cast duration failed for %s: %s', unitKind, tostring(duration))
        return false
    end
    if not self.bar:SetTimer(duration, remaining) then
        AV.LogOnce('cast:timer:' .. unitKind, 'cast bar timer rejected for %s', unitKind)
        return false
    end
    pcall(self.name.SetText, self.name, name)
    applyInterruptible(self, info[interruptIndex])
    self.castBarID = info[castBarIndex]
    return true
end

local function isCasting(unit)
    return type(UnitCastingInfo(unit)) ~= 'nil' or type(UnitChannelInfo(unit)) ~= 'nil'
end

function CastBar:Update()
    if self.preview then
        return
    end
    local live = self.unit ~= nil and UnitExists(self.unit)
        and (tryStart(self, UnitCastingDuration, UnitCastingInfo, false, 8, 10)
            or tryStart(self, UnitChannelDuration, UnitChannelInfo, true, 7, 12))
    -- A failure hold outlasts the STOP events that follow it; only a new cast ends it early.
    if self.failing then
        if not live then
            return
        end
        self:EndFailure()
    end
    setVisible(self, live)
end

-- Holds the showing bar full with label in spec.failure's colour. No-op without spec.failure.
-- castBarID: the failure event's, when it has one; a different cast's failure is ignored.
-- UNIT_SPELLCAST_FAILED also fires for a spell pressed during a cast that carries on, so
-- failed = true ignores the event while the unit is still casting.
function CastBar:ShowFailure(label, castBarID, failed)
    local failure = self.spec.failure
    if not failure or self.preview or self.failing or not self.bar.frame:IsShown() then
        return
    end
    if castBarID ~= nil and self.castBarID ~= nil and castBarID ~= self.castBarID then
        return
    end
    if failed and isCasting(self.unit) then
        return
    end
    self.failing = true
    resetColors(self)
    self.bar:SetRange(1)
    self.bar:SetValue(1)
    self.bar:SetFillColor(failure.color)
    self.name:SetText(label)
    C_Timer.After(failure.hold, function()
        if self.failing then
            self:EndFailure()
            self:Update()
        end
    end)
end

function CastBar:EndFailure()
    if not self.failing then
        return
    end
    self.failing = nil
    resetColors(self)
    setVisible(self, false)
end

-- Demo: a static bar at progress (0..1) showing spellName, tinted as uninterruptible when
-- notInterruptible; nil spellName restores live updates.
function CastBar:SetPreview(spellName, progress, notInterruptible)
    self.preview = spellName ~= nil
    resetColors(self)
    if self.preview then
        self.bar:SetRange(1)
        self.bar:SetValue(progress or 0.5)
        self.name:SetText(spellName)
        applyInterruptible(self, notInterruptible == true)
        setVisible(self, true)
    else
        self:Update()
    end
end
