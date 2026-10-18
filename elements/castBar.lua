local _, EUI = ...

-- Cast timestamps and names are secret on Forever. The bar runs from a duration object via
-- StatusBar:SetTimerDuration; the name goes straight to SetText. No remaining-time text.

EUI.CastBar = {}
local CastBar = {}
CastBar.__index = CastBar

-- Blizzard's cast bar fades over 0.3s, 0.2s after a cast ends and straight after a failure hold.
local FADE_TIME = 0.3
local FADE_DELAY = 0.2
local SPARK_ATLAS = 'ui-castingbar-pip'
local SPARK_FALLBACK = { path = 'Interface\\CastingBar\\UI-CastingBar-Spark' }
local SPARK_SIZE = { 6, 14 }

-- spec = { bar, txtName = { ..., width }, channelColor, failure = { color, hold },
-- uninterruptible = { color, lock = { path, pos, size, color } } }.
-- channelColor (optional) tints the bar while the unit channels; sparkColor (optional) tints the
-- spark.
-- unit may be nil until SetUnit.
-- onVisibility(shown), when set, is called whenever the bar shows or hides (after the fade).
function EUI.CastBar.Create(parent, unit, spec, fonts, pos)
    local self = setmetatable({ unit = unit, spec = spec }, CastBar)
    self.bar = EUI.Bar.Create(parent, spec.bar, pos)
    self.name = EUI.Style.Text(self.bar.overlay, spec.txtName, fonts)
    if spec.txtName.width then
        self.name:SetWidth(spec.txtName.width)
        self.name:SetWordWrap(false)
    end
    local lockSpec = spec.uninterruptible and spec.uninterruptible.lock
    if lockSpec then
        self.lock = EUI.Style.Image(self.bar.overlay, 'OVERLAY', lockSpec)
        self.lock:SetAlpha(0)
    end

    -- The spark rides the fill's right edge, which the engine moves; the timing stays secret.
    local spark = self.bar.overlay:CreateTexture(nil, 'OVERLAY')
    EUI.Style.SetAtlas(spark, SPARK_ATLAS, SPARK_FALLBACK)
    spark:SetSize(SPARK_SIZE[1], SPARK_SIZE[2])
    -- The pip art is yellow; desaturated, it takes the tint.
    if spec.sparkColor then
        spark:SetDesaturated(true)
        spark:SetVertexColor(EUI.Style.Color(spec.sparkColor))
    end
    spark:SetPoint('CENTER', self.bar.status:GetStatusBarTexture(), 'RIGHT', 0, 0)
    spark:Hide()
    self.spark = spark

    local frame = self.bar.frame
    local fade = frame:CreateAnimationGroup()
    local alpha = fade:CreateAnimation('Alpha')
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0)
    alpha:SetDuration(FADE_TIME)
    fade:SetScript('OnFinished', function()
        frame:Hide()
        frame:SetAlpha(1)
        if self.onVisibility then
            self.onVisibility(false)
        end
    end)
    self.fade, self.fadeAlpha = fade, alpha

    frame:Hide()
    return self
end

function CastBar:SetUnit(unit)
    self.unit = unit
end

-- Shows the bar at once; hides it through the fade, after delay (default FADE_DELAY).
local function setVisible(self, shown, delay)
    local frame = self.bar.frame
    if shown then
        self.fade:Stop()
        frame:SetAlpha(1)
        frame:Show()
    elseif frame:IsShown() then
        if not self.fade:IsPlaying() then
            self.fadeAlpha:SetStartDelay(delay or FADE_DELAY)
            self.fade:Play()
        end
        return
    end
    if self.onVisibility then
        self.onVisibility(shown)
    end
end

-- The bar's fill and frame colours for the current spell: channelColor while channeling, else
-- the bar's own.
local function baseColor(self)
    return self.channeling and self.spec.channelColor or self.spec.bar.fill.color
end

local function baseFrameColor(self)
    return self.channeling and self.spec.channelColor or self.spec.bar.bg.color
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
            EUI.LogOnce('cast:lock', 'SetAlphaFromBoolean failed: %s', tostring(err))
        end
    end
    if not (spec and C_CurveUtil and C_CurveUtil.EvaluateColorFromBoolean) then
        return
    end
    local tint = CreateColor(EUI.Style.Color(spec.color))
    local ok, fill = pcall(C_CurveUtil.EvaluateColorFromBoolean, notInterruptible, tint, CreateColor(EUI.Style.Color(baseColor(self))))
    local frameOk, frame = pcall(C_CurveUtil.EvaluateColorFromBoolean, notInterruptible, tint,
        CreateColor(EUI.Style.Color(baseFrameColor(self))))
    if not (ok and fill and frameOk and frame) then
        EUI.LogOnce('cast:interruptible', 'EvaluateColorFromBoolean failed: %s', tostring(ok and frame or fill))
        return
    end
    local bar = self.bar
    pcall(function()
        bar.status:SetStatusBarColor(fill:GetRGBA())
        bar.bg:SetVertexColor(frame:GetRGBA())
        bar.fg:SetVertexColor(frame:GetRGBA())
    end)
end

local function resetColors(self)
    local bar = self.bar
    bar:SetFillColor(baseColor(self))
    bar:SetFrameColor(baseFrameColor(self))
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
        EUI.LogOnce('cast:duration:' .. unitKind, 'cast duration failed for %s: %s', unitKind, tostring(duration))
        return false
    end
    if not self.bar:SetTimer(duration, remaining) then
        EUI.LogOnce('cast:timer:' .. unitKind, 'cast bar timer rejected for %s', unitKind)
        return false
    end
    pcall(self.name.SetText, self.name, name)
    self.channeling = remaining
    resetColors(self)
    self.spark:Show()
    applyInterruptible(self, info[interruptIndex])
    self.castBarID = info[castBarIndex]
    return true
end

-- The info functions return nothing at all when idle; the parentheses make that one nil.
local function isCasting(unit)
    return type((UnitCastingInfo(unit))) ~= 'nil' or type((UnitChannelInfo(unit))) ~= 'nil'
end

function CastBar:Update()
    if self.preview then
        return
    end
    -- A failure hold outlasts the STOP events that follow it; only a new cast ends it early.
    -- Dropping the hold first keeps the new cast's colours, which tryStart sets.
    if self.failing then
        if not (self.unit and isCasting(self.unit)) then
            return
        end
        self.failing = nil
    end
    local live = self.unit ~= nil and UnitExists(self.unit)
        and (tryStart(self, UnitCastingDuration, UnitCastingInfo, false, 8, 10)
            or tryStart(self, UnitChannelDuration, UnitChannelInfo, true, 7, 11))
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
    -- Each hold gets its own token, so an earlier hold's timer cannot end a later one.
    local token = {}
    self.failing = token
    self.channeling = false
    resetColors(self)
    self.bar:SetRange(1)
    self.bar:SetValue(1)
    self.bar:SetFillColor(failure.color)
    self.spark:Hide()
    self.name:SetText(label)
    C_Timer.After(failure.hold, function()
        if self.failing == token then
            self:EndFailure()
            self:Update()
        end
    end)
end

-- Ends a failure hold, fading the bar out in the failure colour; the next cast resets colours.
function CastBar:EndFailure()
    if not self.failing then
        return
    end
    self.failing = nil
    setVisible(self, false, 0)
end

-- Hides the bar at once, without the fade (the unit changed).
function CastBar:Clear()
    self.failing = nil
    self.fade:Stop()
    self.bar.frame:Hide()
    self.bar.frame:SetAlpha(1)
    if self.onVisibility then
        self.onVisibility(false)
    end
end

-- Demo: a static bar at progress (0..1) showing spellName, tinted as uninterruptible when
-- notInterruptible and as a channel when channel. false keeps the preview with the bar hidden;
-- nil restores live updates.
function CastBar:SetPreview(spellName, progress, notInterruptible, channel)
    self:EndFailure()
    self.preview = spellName ~= nil
    self.channeling = self.preview and channel == true
    resetColors(self)
    if spellName then
        self.bar:SetRange(1)
        self.bar:SetValue(progress or 0.5)
        self.name:SetText(spellName)
        applyInterruptible(self, notInterruptible == true)
        self.spark:Show()
        setVisible(self, true)
    elseif self.preview then
        setVisible(self, false)
    else
        self:Update()
    end
end
