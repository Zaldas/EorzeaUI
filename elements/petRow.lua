local _, EUI = ...

-- Visuals for a party row's pet sub-row: portrait with threat, HP with incoming heals, power and
-- an aura row. The player's own pet adds hunter happiness, a cast bar on the name line and a
-- pulse while it attacks. The party list builds the
-- secure button that carries the pet unit; this only draws on it and follows unit changes.

EUI.PetRow = {}
local Pet = {}
Pet.__index = Pet

local Style = EUI.Style
local UnitVisual = EUI.UnitVisual

local ICON_INSET = 0.08

-- C_PetInfo.GetPetHappiness: 1 unhappy, 2 content, 3 happy. The fallback sheet is the pre-atlas art.
local HAPPINESS_SHEET = 'Interface\\PetPaperDollFrame\\UI-PetHappiness'
local HAPPINESS = {
    { atlas = 'UI-PetMad', coords = { 0.375, 0.5625, 0, 0.359375 } },
    { atlas = 'UI-PetNeutral', coords = { 0.1875, 0.375, 0, 0.359375 } },
    { atlas = 'UI-PetHappiness', coords = { 0, 0.1875, 0, 0.359375 } },
}

local function buildArt(self, host, spec, fonts)
    -- Art lives on a child frame so a secure host keeps all mouse input.
    local art = CreateFrame('Frame', nil, host)
    art:SetPoint('TOPLEFT', host, 'TOPLEFT', 0, spec.shiftUp)
    art:SetPoint('BOTTOMRIGHT', host, 'BOTTOMRIGHT', 0, spec.shiftUp)
    art:EnableMouse(false)
    self.art = art

    self.hover = Style.Image(art, 'BACKGROUND', spec.hover, 1)
    self.hover:Hide()

    self.hp = EUI.Bar.Create(art, spec.hp.bar, spec.hp.pos, { prediction = self.partyStyle.indicators.healPrediction })
    self.hpText = Style.Text(self.hp.overlay, spec.hp.txtValue, fonts)
    self.hpCurve = EUI.Curves.Step(spec.hp.thresholds, spec.hp.textColor)

    self.power = EUI.Bar.Create(art, spec.power.bar, spec.power.pos)
    self.powerText = Style.Text(self.power.overlay, spec.power.txtValue, fonts)

    -- Name line, above both bars; the cast bar takes it while the pet casts.
    local top = CreateFrame('Frame', nil, art)
    top:SetAllPoints(art)
    top:SetFrameLevel(self.power.overlay:GetFrameLevel() + 1)
    self.name = Style.Text(top, spec.txtName, fonts)
    self.name:SetWidth(spec.txtName.width)
    self.name:SetWordWrap(false)
    self.cast = EUI.CastBar.Create(top, nil, spec.cast, fonts, spec.cast.pos)
    -- Alpha, not Hide, so name updates mid-cast stick.
    self.cast.onVisibility = function(casting)
        self.name:SetAlpha(casting and 0 or 1)
    end

    local portraitSpec = spec.portrait
    local iconFrame
    iconFrame, self.gradient, self.portrait = UnitVisual.JobFrame(art, portraitSpec.pos, portraitSpec.size,
        portraitSpec.inset, self.partyStyle.classIcon)
    iconFrame:SetFrameLevel(self.power.overlay:GetFrameLevel() + 1)

    -- Over the picture, under the frame art.
    local attack = spec.attack
    self.attackGlow = Style.Image(iconFrame, 'ARTWORK', {
        path = attack.path, color = attack.color, size = { portraitSpec.size, portraitSpec.size },
    }, 1)
    self.attackGlow:SetBlendMode('ADD')
    local pulse = self.attackGlow:CreateAnimationGroup()
    pulse:SetLooping('BOUNCE')
    local fade = pulse:CreateAnimation('Alpha')
    fade:SetFromAlpha(attack.from)
    fade:SetToAlpha(attack.to)
    fade:SetDuration(attack.period)
    self.attackPulse = pulse
    self.attackGlow:Hide()

    -- The target pointer, drawn over the portrait as on the member rows.
    local pointer = CreateFrame('Frame', nil, art)
    pointer:SetAllPoints(art)
    pointer:SetFrameLevel(iconFrame:GetFrameLevel() + 1)
    self.cursor = Style.Image(pointer, 'OVERLAY', spec.cursor)
    self.cursor:Hide()
    self.threat = Style.Image(pointer, 'OVERLAY', spec.threat)
    self.threat:Hide()

    self.happiness = art:CreateTexture(nil, 'OVERLAY')
    self.happiness:SetSize(spec.happiness.size[1], spec.happiness.size[2])
    Style.Place(self.happiness, art, spec.happiness.pos)
    self.happiness:Hide()

    self.auraLayer = CreateFrame('Frame', nil, art)
    self.auraLayer:SetAllPoints(art)
end

-- button: the secure pet button. owner: the party row it belongs to. hooks = { unitChanged(pet,
-- previous, unit), heightChanged() }: the party list's callbacks.
function EUI.PetRow.Attach(button, owner, partyStyle, fonts, hooks)
    local spec = partyStyle.pet
    local self = setmetatable({ button = button, owner = owner, spec = spec, partyStyle = partyStyle, hooks = hooks }, Pet)
    buildArt(self, button, spec, fonts)

    -- Created at login (out of combat) with the button's initial unit.
    self.auras = EUI.AuraRow.Create(self.auraLayer, button:GetAttribute('unit') or 'pet', spec.auras.order, spec.auras, fonts)

    UnitVisual.AttachButton(self, button)
    -- The secure show/hide handlers have resized the owner's row by the time these run.
    button:HookScript('OnShow', hooks.heightChanged)
    button:HookScript('OnHide', hooks.heightChanged)

    self:SetUnit(button:GetAttribute('unit'))
    return self
end

-- A non-secure sub-row showing fixed sample data, placed by its demo owner row.
function EUI.PetRow.CreateDemo(parent, owner, partyStyle, fonts)
    local spec = partyStyle.pet
    local self = setmetatable({ owner = owner, spec = spec, partyStyle = partyStyle }, Pet)
    local host = CreateFrame('Frame', nil, parent)
    host:SetSize(partyStyle.width, spec.rowHeight)
    self.host = host
    buildArt(self, host, spec, fonts)
    self.auras = EUI.StaticIcons.Create(self.auraLayer, spec.auras, fonts)
    return self
end

-- The job frame's gradient takes the owner's class colour.
function Pet:UpdateGradient()
    self.gradient:SetVertexColor(self.owner.classGradient:GetVertexColor())
end

local function tintPower(self, powerType)
    local colors = self.partyStyle.power.colors
    UnitVisual.TintBar(self.power, powerType, colors and colors[powerType] or self.spec.power.bar.fill.color)
end

local function setHappiness(self, happiness)
    local entry = happiness and HAPPINESS[happiness]
    self.happiness:SetShown(entry ~= nil)
    if entry then
        Style.SetAtlas(self.happiness, entry.atlas, { path = HAPPINESS_SHEET, coords = entry.coords })
    end
end

-- status: UnitThreatSituation's 1-3 tint the diamond with Blizzard's threat colours; else hidden,
-- as while spec.threat.hidden (settings).
local function setThreat(self, status)
    if type(status) ~= 'number' or status < 1 or self.spec.threat.hidden then
        self.threat:Hide()
        return
    end
    self.threat:SetVertexColor(EUI.Indicators.ThreatColor(status))
    self.threat:Show()
end

-- pet = { name, icon, hp, hpMax, power, powerMax, powerType, happiness, cast, auras, targeted, far,
--         threat, attacking }
function Pet:ShowDemo(pet)
    self.host:SetShown(pet ~= nil)
    if not pet then
        return
    end
    self:UpdateGradient()
    self.name:SetText(pet.name)
    self.cursor:SetShown(pet.targeted == true)
    self.art:SetAlpha(pet.far and self.partyStyle.range.farAlpha or 1)
    self.portrait:SetTexture(pet.icon)
    self.portrait:SetTexCoord(ICON_INSET, 1 - ICON_INSET, ICON_INSET, 1 - ICON_INSET)

    self.hp:SetRange(pet.hpMax)
    self.hp:SetValue(pet.hp)
    self.hpText:SetText(UnitVisual.FormatNumber(pet.hp))
    self.hpText:SetTextColor(Style.Color(UnitVisual.ThresholdColor(self.spec.hp, pet.hp / pet.hpMax)))

    tintPower(self, pet.powerType)
    self.power:SetRange(pet.powerMax)
    self.power:SetValue(pet.power)
    self.powerText:SetText(UnitVisual.FormatNumber(pet.power))

    self.cast:SetPreview(pet.cast, 0.55)
    setHappiness(self, pet.happiness)
    self.auraLayer:SetShown(pet.auras ~= nil)
    self.auras:Set(pet.auras)
    setThreat(self, pet.threat)
    self:SetAttacking(pet.attacking == true)
end

function Pet:SetUnit(unit)
    if unit == self.unit then
        return
    end
    local previous = self.unit
    self.unit = unit
    self.isOwn = unit == 'pet'
    self.hooks.unitChanged(self, previous, unit)
    self.cast:SetUnit(self.isOwn and unit or nil)
    if not self.isOwn then
        self:SetAttacking(false)
    end
    if unit then
        self.auras:SetUnit(unit)
    end
    self:Refresh()
end

function Pet:Refresh()
    if not self.unit or not UnitExists(self.unit) then
        return
    end
    self:UpdateGradient()
    self:UpdateName()
    self:UpdatePortrait()
    self:UpdateHealth(false)
    self:UpdatePower(false)
    self:UpdateThreat()
    self:UpdateHappiness()
    self:UpdateCast()
    self:UpdateRange()
    self:UpdateCursor()
    self.auras:Refresh()
end

-- Your own pet counts as near, as your own row does; a pet fades with an owner who is phased or
-- in another group.
function Pet:UpdateRange()
    local range = self.partyStyle.range
    if not self.unit or self.isOwn then
        self.art:SetAlpha(1)
    elseif self.owner.notPresent then
        self.art:SetAlpha(range.notPresentAlpha)
    else
        UnitVisual.ShowRange(self.art, self.unit, range.farAlpha)
    end
end

function Pet:UpdateCursor()
    self.cursor:SetShown(UnitVisual.IsTarget(self.unit))
end

-- The name may be secret: SetText accepts it.
function Pet:UpdateName()
    pcall(self.name.SetText, self.name, EUI.UnitDisplayName(self.unit))
end

function Pet:UpdatePortrait()
    EUI.Read('SetPortraitTexture', SetPortraitTexture, self.portrait, self.unit)
    UnitVisual.CropCircle(self.portrait)
end

function Pet:UpdateHealth(smooth)
    local unit = self.unit
    local maxHealth = UnitHealthMax(unit)
    self.hp:SetRange(maxHealth)
    local health = UnitHealth(unit)
    self.hp:SetValue(health, smooth)
    UnitVisual.SetHealthText(self.hpText, unit, health, self.hpCurve, self.partyStyle.indicators.stateColor)
    self.hp:ShowIncomingHeals(unit, maxHealth)
end

function Pet:UpdateHealPrediction()
    self.hp:ShowIncomingHeals(self.unit, UnitHealthMax(self.unit))
end

-- As the member rows: no threat colours on others' pets while solo.
function Pet:UpdateThreat()
    if not self.unit or (not IsInGroup() and not self.isOwn) then
        setThreat(self, nil)
        return
    end
    setThreat(self, EUI.Read('UnitThreatSituation', UnitThreatSituation, self.unit))
end

-- Own pet: PET_ATTACK_START / PET_ATTACK_STOP.
function Pet:SetAttacking(attacking)
    self.attackGlow:SetShown(attacking)
    if attacking then
        self.attackPulse:Play()
    else
        self.attackPulse:Stop()
    end
end

-- Hunter pets run on focus, warlock pets on mana.
-- A pet without power (max 0) shows no number, as Blizzard's pet frame. A secret max can't be
-- compared, so the number stays.
function Pet:UpdatePower(smooth)
    local unit = self.unit
    tintPower(self, EUI.Read('UnitPowerType', UnitPowerType, unit))
    local maxPower = UnitPowerMax(unit)
    self.power:SetRange(maxPower)
    local power = UnitPower(unit)
    self.power:SetValue(power, smooth)
    local powerless = type(maxPower) == 'number' and EUI.CanAccess(maxPower) and maxPower == 0
    self.powerText:SetShown(not powerless)
    if not powerless then
        EUI.SetNumberText(self.powerText, power)
    end
end

local function hasHunterPet()
    return select(2, HasPetUI())
end

-- Own hunter pet only, as Blizzard's PetHappinessIndicator.
function Pet:UpdateHappiness()
    local happiness
    if self.isOwn and EUI.Read('HasPetUI', HasPetUI and hasHunterPet) then
        happiness = EUI.Read('GetPetHappiness', C_PetInfo and C_PetInfo.GetPetHappiness or GetPetHappiness)
    end
    setHappiness(self, happiness)
end

function Pet:UpdateCast()
    self.cast:Update()
end
