local _, AV = ...

-- Cast timestamps and names are secret on Forever. The bar runs from a duration object via
-- StatusBar:SetTimerDuration; the name goes straight to SetText. No remaining-time text.

AV.CastBar = {}
local CastBar = {}
CastBar.__index = CastBar

-- spec = { bar, txtName = { ..., width } }. unit may be nil until SetUnit.
-- onVisibility(shown), when set, is called whenever the bar shows or hides.
function AV.CastBar.Create(parent, unit, spec, fonts, pos)
    local self = setmetatable({ unit = unit }, CastBar)
    self.bar = AV.Bar.Create(parent, spec.bar, pos)
    self.name = AV.Style.Text(self.bar.overlay, spec.txtName, fonts)
    if spec.txtName.width then
        self.name:SetWidth(spec.txtName.width)
        self.name:SetWordWrap(false)
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

local function tryStart(self, durationFn, infoFn, remaining)
    if type(durationFn) ~= 'function' then
        return false
    end
    -- type() works on secret values; == nil comparisons may not.
    local name = infoFn(self.unit)
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
    return true
end

function CastBar:Update()
    if self.preview then
        return
    end
    setVisible(self, self.unit ~= nil and UnitExists(self.unit)
        and (tryStart(self, UnitCastingDuration, UnitCastingInfo, false)
            or tryStart(self, UnitChannelDuration, UnitChannelInfo, true)))
end

-- Demo: a static bar at progress (0..1) showing spellName; nil spellName restores live updates.
function CastBar:SetPreview(spellName, progress)
    self.preview = spellName ~= nil
    if self.preview then
        self.bar:SetRange(1)
        self.bar:SetValue(progress or 0.5)
        self.name:SetText(spellName)
        setVisible(self, true)
    else
        self:Update()
    end
end
