local _, EUI = ...

-- Visuals for a party row's pet sub-row: portrait, HP and power. The player's own pet adds
-- hunter happiness, a cast bar over the power bar and an aura row. The party list builds the
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

    self.hp = EUI.Bar.Create(art, spec.hp.bar, spec.hp.pos)
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

    self.happiness = art:CreateTexture(nil, 'OVERLAY')
    self.happiness:SetSize(spec.happiness.size[1], spec.happiness.size[2])
    Style.Place(self.happiness, art, spec.happiness.pos)
    self.happiness:Hide()

    -- Own pet only; the AuraContainer keeps its unit, the layer decides whether it shows.
    self.auraLayer = CreateFrame('Frame', nil, art)
    self.auraLayer:SetAllPoints(art)
    self.auraLayer:Hide()
end

-- button: the secure pet button. owner: the party row it belongs to.
function EUI.PetRow.Attach(button, owner, partyStyle, fonts)
    local spec = partyStyle.pet
    local self = setmetatable({ button = button, owner = owner, spec = spec, partyStyle = partyStyle }, Pet)
    buildArt(self, button, spec, fonts)

    -- Created at login (out of combat) with the button's initial unit.
    self.auras = EUI.AuraRow.Create(self.auraLayer, button:GetAttribute('unit') or 'pet', { 'HARMFUL', 'HELPFUL' }, spec.auras, fonts)

    UnitVisual.AttachButton(self, button)
    -- The secure show/hide handlers have resized the owner's row by the time these run.
    button:HookScript('OnShow', function()
        EUI.PartyList.UpdateBackground()
    end)
    button:HookScript('OnHide', function()
        EUI.PartyList.UpdateBackground()
    end)

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
    local auraSpec = spec.auras
    self.auras = EUI.StaticIcons.Create(self.auraLayer, {
        pos = auraSpec.pos, size = auraSpec.size, spacing = auraSpec.spacing, max = auraSpec.max * 2,
        border = auraSpec.border,
    }, fonts)
    return self
end

-- The job frame's gradient takes the owner's class colour.
local function matchOwnerGradient(self)
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

-- pet = { name, icon, hp, hpMax, power, powerMax, powerType, happiness, cast, auras }
function Pet:ShowDemo(pet)
    self.host:SetShown(pet ~= nil)
    if not pet then
        return
    end
    matchOwnerGradient(self)
    self.name:SetText(pet.name)
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
end

function Pet:SetUnit(unit)
    if unit == self.unit then
        return
    end
    local previous = self.unit
    self.unit = unit
    self.isOwn = unit == 'pet'
    EUI.PartyList.OnPetUnitChanged(self, previous, unit)
    self.cast:SetUnit(self.isOwn and unit or nil)
    self.auraLayer:SetShown(self.isOwn)
    if unit then
        self.auras:SetUnit(unit)
    end
    self:Refresh()
end

function Pet:Refresh()
    if not self.unit or not UnitExists(self.unit) then
        return
    end
    matchOwnerGradient(self)
    self:UpdateName()
    self:UpdatePortrait()
    self:UpdateHealth(false)
    self:UpdatePower(false)
    self:UpdateHappiness()
    self:UpdateCast()
    self.auras:Refresh()
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
    self.hp:SetRange(UnitHealthMax(unit))
    local health = UnitHealth(unit)
    self.hp:SetValue(health, smooth)
    EUI.SetNumberText(self.hpText, health)
    EUI.Curves.ApplyHealthColor(self.hpText, unit, self.hpCurve)
end

-- Hunter pets run on focus, warlock pets on mana.
function Pet:UpdatePower(smooth)
    local unit = self.unit
    tintPower(self, EUI.Read('UnitPowerType', UnitPowerType, unit))
    self.power:SetRange(UnitPowerMax(unit))
    local power = UnitPower(unit)
    self.power:SetValue(power, smooth)
    EUI.SetNumberText(self.powerText, power)
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
