local _, AV = ...

-- Visuals for a party row's pet sub-row: portrait, HP and power. The player's own pet adds
-- hunter happiness, a cast bar over the power bar and an aura row. The party list builds the
-- secure button that carries the pet unit; this only draws on it and follows unit changes.

AV.PetRow = {}
local Pet = {}
Pet.__index = Pet

local Style = AV.Style

-- Portraits are drawn as circles; cropping to the inscribed square fills the job frame.
local CIRCLE_INSET = 0.146
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

    self.hp = AV.Bar.Create(art, spec.hp.bar, spec.hp.pos)
    self.hpText = Style.Text(self.hp.overlay, spec.hp.txtValue, fonts)
    self.hpCurve = AV.Curves.Step(spec.hp.thresholds, spec.hp.textColor)

    self.power = AV.Bar.Create(art, spec.power.bar, spec.power.pos)
    self.powerText = Style.Text(self.power.overlay, spec.power.txtValue, fonts)

    -- Name line, above both bars; the cast bar takes it while the pet casts.
    local top = CreateFrame('Frame', nil, art)
    top:SetAllPoints(art)
    top:SetFrameLevel(self.power.overlay:GetFrameLevel() + 1)
    self.name = Style.Text(top, spec.txtName, fonts)
    self.name:SetWidth(spec.txtName.width)
    self.name:SetWordWrap(false)
    self.cast = AV.CastBar.Create(top, nil, spec.cast, fonts, spec.cast.pos)
    -- Alpha, not Hide, so name updates mid-cast stick.
    self.cast.onVisibility = function(casting)
        self.name:SetAlpha(casting and 0 or 1)
    end

    local portraitSpec = spec.portrait
    local size = portraitSpec.size
    local iconFrame = CreateFrame('Frame', nil, art)
    iconFrame:SetSize(size, size)
    Style.Place(iconFrame, art, portraitSpec.pos)
    iconFrame:SetFrameLevel(self.power.overlay:GetFrameLevel() + 1)
    local iconSpec = self.partyStyle.classIcon
    local full = { pos = { 0, 0 }, size = { size, size } }
    Style.Image(iconFrame, 'BACKGROUND', { path = iconSpec.bg, pos = full.pos, size = full.size })
    self.gradient = Style.Image(iconFrame, 'BORDER', { path = iconSpec.gradient, pos = full.pos, size = full.size })
    self.portrait = iconFrame:CreateTexture(nil, 'ARTWORK')
    self.portrait:SetPoint('TOPLEFT', portraitSpec.inset, -portraitSpec.inset)
    self.portrait:SetPoint('BOTTOMRIGHT', -portraitSpec.inset, portraitSpec.inset)
    Style.Image(iconFrame, 'OVERLAY', { path = iconSpec.frame, pos = full.pos, size = full.size })

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
function AV.PetRow.Attach(button, owner, partyStyle, fonts)
    local spec = partyStyle.pet
    local self = setmetatable({ button = button, owner = owner, spec = spec, partyStyle = partyStyle }, Pet)
    buildArt(self, button, spec, fonts)

    -- Created at login (out of combat) with the button's initial unit.
    self.auras = AV.AuraRow.Create(self.auraLayer, button:GetAttribute('unit') or 'pet', { 'HARMFUL', 'HELPFUL' }, spec.auras, fonts)

    button:HookScript('OnEnter', function()
        self.hover:Show()
        if self.unit and UnitExists(self.unit) then
            GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
            GameTooltip:SetUnit(self.unit)
            GameTooltip:Show()
        end
    end)
    button:HookScript('OnLeave', function()
        self.hover:Hide()
        GameTooltip:Hide()
    end)
    button:HookScript('OnAttributeChanged', function(_, name, value)
        if name == 'unit' then
            self:SetUnit(value)
        end
    end)
    -- The secure show/hide handlers have resized the owner's row by the time these run.
    button:HookScript('OnShow', function()
        self:Refresh()
        AV.PartyList.UpdateBackground()
    end)
    button:HookScript('OnHide', function()
        AV.PartyList.UpdateBackground()
    end)

    self:SetUnit(button:GetAttribute('unit'))
    return self
end

-- A non-secure sub-row showing fixed sample data, placed by its demo owner row.
function AV.PetRow.CreateDemo(parent, owner, partyStyle, fonts)
    local spec = partyStyle.pet
    local self = setmetatable({ owner = owner, spec = spec, partyStyle = partyStyle }, Pet)
    local host = CreateFrame('Frame', nil, parent)
    host:SetSize(partyStyle.width, spec.rowHeight)
    self.host = host
    buildArt(self, host, spec, fonts)
    local auraSpec = spec.auras
    self.auras = AV.StaticIcons.Create(self.auraLayer, {
        pos = auraSpec.pos, size = auraSpec.size, spacing = auraSpec.spacing, max = auraSpec.max * 2,
    }, fonts)
    return self
end

-- The job frame's gradient takes the owner's class colour.
local function matchOwnerGradient(self)
    self.gradient:SetVertexColor(self.owner.classGradient:GetVertexColor())
end

local function tintPower(self, powerType)
    if powerType == self.powerType then
        return
    end
    self.powerType = powerType
    local colors = self.partyStyle.power.colors
    local color = colors and colors[powerType] or self.spec.power.bar.fill.color
    self.power:SetFrameColor(color)
    self.power:SetFillColor(color)
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
    self.hpText:SetText(BreakUpLargeNumbers and BreakUpLargeNumbers(pet.hp) or tostring(pet.hp))
    local color = self.spec.hp.textColor
    for _, step in ipairs(self.spec.hp.thresholds) do
        if pet.hp / pet.hpMax < step.below then
            color = step.color
            break
        end
    end
    self.hpText:SetTextColor(Style.Color(color))

    tintPower(self, pet.powerType)
    self.power:SetRange(pet.powerMax)
    self.power:SetValue(pet.power)
    self.powerText:SetText(BreakUpLargeNumbers and BreakUpLargeNumbers(pet.power) or tostring(pet.power))

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
    AV.PartyList.OnPetUnitChanged(self, previous, unit)
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
    pcall(self.name.SetText, self.name, AV.UnitDisplayName(self.unit))
end

function Pet:UpdatePortrait()
    AV.Read('SetPortraitTexture', SetPortraitTexture, self.portrait, self.unit)
    self.portrait:SetTexCoord(CIRCLE_INSET, 1 - CIRCLE_INSET, CIRCLE_INSET, 1 - CIRCLE_INSET)
end

function Pet:UpdateHealth(smooth)
    local unit = self.unit
    self.hp:SetRange(UnitHealthMax(unit))
    local health = UnitHealth(unit)
    self.hp:SetValue(health, smooth)
    AV.SetNumberText(self.hpText, health)
    AV.Curves.ApplyHealthColor(self.hpText, unit, self.hpCurve)
end

-- Hunter pets run on focus, warlock pets on mana.
function Pet:UpdatePower(smooth)
    local unit = self.unit
    tintPower(self, AV.Read('UnitPowerType', UnitPowerType, unit))
    self.power:SetRange(UnitPowerMax(unit))
    local power = UnitPower(unit)
    self.power:SetValue(power, smooth)
    AV.SetNumberText(self.powerText, power)
end

local function hasHunterPet()
    return select(2, HasPetUI())
end

-- Own hunter pet only, as Blizzard's PetHappinessIndicator.
function Pet:UpdateHappiness()
    local happiness
    if self.isOwn and AV.Read('HasPetUI', HasPetUI and hasHunterPet) then
        happiness = AV.Read('GetPetHappiness', C_PetInfo and C_PetInfo.GetPetHappiness or GetPetHappiness)
    end
    setHappiness(self, happiness)
end

function Pet:UpdateCast()
    self.cast:Update()
end
