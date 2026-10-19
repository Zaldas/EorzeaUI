local _, EUI = ...

-- Raid pets: one SecureGroupPetHeader showing every raidpetN in raid order, in columns, as
-- Blizzard's raid frames list pets after the groups. Its own block and mover. Each row is a
-- secure button: portrait, name, HP with incoming heals, and power. The header assigns units and
-- lays out the rows in combat too, as pets are summoned and dismissed.

EUI.RaidPets = {}
local RaidPets = EUI.RaidPets

local Style = EUI.Style
local UnitVisual = EUI.UnitVisual

local VISIBILITY = '[group:raid] show; hide'

local rows = {}
local rowsByUnit = {}

local PetCell = {}
PetCell.__index = PetCell

local function buildArt(self, host)
    local style, spec, fonts = RaidPets.style, RaidPets.spec, RaidPets.fonts
    -- Art lives on a child frame so a secure host keeps all mouse input.
    local art = CreateFrame('Frame', nil, host)
    art:SetAllPoints(host)
    art:EnableMouse(false)
    self.art = art
    self.hover = Style.Image(art, 'BACKGROUND', spec.hover, 1)
    self.hover:Hide()

    self.hp = EUI.Bar.Create(art, style.hp.bar, style.hp.pos, { prediction = style.indicators.healPrediction })
    self.hpText = Style.Text(self.hp.overlay, style.hp.txtValue, fonts)
    self.hpCurve = EUI.Curves.Step(style.hp.thresholds, style.hp.textColor)
    self.power = EUI.Bar.Create(art, style.power.bar, style.power.pos)

    local top = CreateFrame('Frame', nil, art)
    top:SetAllPoints(art)
    top:SetFrameLevel(self.power.overlay:GetFrameLevel() + 1)
    self.name = Style.Text(top, style.txtName, fonts)
    self.name:SetWidth(style.txtName.width)
    self.name:SetWordWrap(false)

    local portrait = spec.portrait
    local iconFrame
    iconFrame, self.gradient, self.portrait = UnitVisual.JobFrame(art, portrait.pos, portrait.size, portrait.inset, style.classIcon)
    iconFrame:SetFrameLevel(self.power.overlay:GetFrameLevel() + 1)

    local pointer = CreateFrame('Frame', nil, art)
    pointer:SetAllPoints(art)
    pointer:SetFrameLevel(iconFrame:GetFrameLevel() + 1)
    self.cursor = Style.Image(pointer, 'OVERLAY', spec.cursor)
    self.cursor:Hide()
end

local function classHex(classToken)
    local color = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    if not color then
        return '#808080FF'
    end
    return string.format('#%02X%02X%02XFF', color.r * 255, color.g * 255, color.b * 255)
end

local function tintPower(self, powerType)
    local spec = RaidPets.style.power
    UnitVisual.TintBar(self.power, powerType, spec.colors and spec.colors[powerType] or spec.bar.fill.color)
end

-- raidpetN belongs to raidN.
function PetCell:Owner()
    return self.unit and (self.unit:gsub('pet', ''))
end

function PetCell:SetUnit(unit)
    if unit == self.unit then
        return
    end
    local previous = self.unit
    self.unit = unit
    if previous and rowsByUnit[previous] == self then
        rowsByUnit[previous] = nil
    end
    if unit then
        EUI.LogOnce('raid:pet', 'raid: pet row showing %s', unit)
        rowsByUnit[unit] = self
        self:Refresh()
    end
end

function PetCell:Refresh()
    if not self.unit or not UnitExists(self.unit) then
        return
    end
    self:UpdateName()
    self:UpdatePortrait()
    self:UpdateHealth(false)
    self:UpdatePower(false)
    self:UpdateRange()
    self:UpdateCursor()
end

-- The job frame's gradient takes the owner's class colour, as on the party pet rows.
function PetCell:UpdateName()
    pcall(self.name.SetText, self.name, EUI.UnitDisplayName(self.unit))
    local owner = self:Owner()
    self.gradient:SetVertexColor(Style.Color(classHex(EUI.SafeValue(function() return select(2, UnitClass(owner)) end))))
end

function PetCell:UpdatePortrait()
    EUI.Read('SetPortraitTexture', SetPortraitTexture, self.portrait, self.unit)
    UnitVisual.CropCircle(self.portrait)
end

function PetCell:UpdateHealth(smooth)
    local unit = self.unit
    local maxHealth = UnitHealthMax(unit)
    self.hp:SetRange(maxHealth)
    local health = UnitHealth(unit)
    self.hp:SetValue(health, smooth)
    UnitVisual.SetHealthText(self.hpText, unit, health, self.hpCurve, RaidPets.style.indicators.stateColor)
    self.hp:ShowIncomingHeals(unit, maxHealth)
end

function PetCell:UpdateHealPrediction()
    self.hp:ShowIncomingHeals(self.unit, UnitHealthMax(self.unit))
end

-- Hunter pets run on focus, warlock pets on mana.
function PetCell:UpdatePower(smooth)
    local unit = self.unit
    tintPower(self, EUI.Read('UnitPowerType', UnitPowerType, unit))
    self.power:SetRange(UnitPowerMax(unit))
    self.power:SetValue(UnitPower(unit), smooth)
end

-- Raid pets have no happiness or cast bar here; the shared pet routes call these.
function PetCell:UpdateHappiness()
end

-- Your own pet counts as near, as your own row does.
function PetCell:UpdateRange()
    if EUI.SafeValue(UnitIsUnit, self.unit, 'pet') then
        self.art:SetAlpha(1)
    else
        UnitVisual.ShowRange(self.art, self.unit, RaidPets.style.range.farAlpha)
    end
end

function PetCell:UpdateCursor()
    self.cursor:SetShown(UnitVisual.IsTarget(self.unit))
end

-- pet = { name, icon, ownerClass, hp, hpMax, power, powerMax, powerType, targeted, far }
function PetCell:ShowDemo(pet)
    self.host:SetShown(pet ~= nil)
    if not pet then
        return
    end
    self.name:SetText(pet.name)
    self.gradient:SetVertexColor(Style.Color(classHex(pet.ownerClass)))
    self.portrait:SetTexture(pet.icon)
    self.portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    self.hp:SetRange(pet.hpMax)
    self.hp:SetValue(pet.hp)
    self.hpText:SetText(UnitVisual.FormatNumber(pet.hp))
    self.hpText:SetTextColor(Style.Color(UnitVisual.ThresholdColor(RaidPets.style.hp, pet.hp / pet.hpMax)))
    tintPower(self, pet.powerType)
    self.power:SetRange(pet.powerMax)
    self.power:SetValue(pet.power)
    self.cursor:SetShown(pet.targeted == true)
    self.art:SetAlpha(pet.far and RaidPets.style.range.farAlpha or 1)
end

-- Columns step as the group columns do; each has its own background, the label sits on the first.
local function columnX(column)
    return (column - 1) * EUI.RaidList.ColumnStep(RaidPets.style)
end

local function createColumns(parent)
    local style, spec = RaidPets.style, RaidPets.spec
    local columns = {}
    for column = 1, math.ceil(spec.max / spec.perColumn) do
        local slot = CreateFrame('Frame', nil, parent)
        slot:SetSize(style.width, spec.rowHeight)
        slot:SetPoint('TOPLEFT', parent, 'TOPLEFT', columnX(column), 0)
        -- Only the first column carries the label, centred over it; the header's right line
        -- reaches the last column in use (sizeColumns).
        if column == 1 then
            local header
            columns[column], header = EUI.RaidList.CreateChrome(slot, spec.label, style.background, style.groupNumber, RaidPets.fonts)
            header.label:ClearAllPoints()
            header.label:SetPoint('CENTER', header, 'LEFT', style.groupNumber.width / 2, 0)
            columns.header = header
        else
            columns[column] = EUI.PartyList.CreateBackground(slot, style.background)
        end
    end
    return columns
end

local function sizeColumns(columns, count)
    local spec = RaidPets.spec
    for column, bg in ipairs(columns) do
        local inColumn = math.max(0, math.min(spec.perColumn, count - (column - 1) * spec.perColumn))
        EUI.RaidList.SizeChrome(bg, inColumn, RaidPets.style, spec.rowHeight)
    end
    local used = math.max(1, math.ceil(count / spec.perColumn))
    columns.header:SetWidth(columnX(used) + RaidPets.style.groupNumber.width)
end

local function updateBackground()
    local count = 0
    for _, row in ipairs(rows) do
        if row.button:IsShown() then
            count = count + 1
        end
    end
    sizeColumns(RaidPets.columns, count)
end

local function attachRow(button)
    local spec = RaidPets.spec
    button:SetSize(RaidPets.style.width, spec.rowHeight)
    button:RegisterForClicks('AnyUp')
    ClickCastFrames = ClickCastFrames or {}
    ClickCastFrames[button] = true
    local self = setmetatable({ button = button }, PetCell)
    buildArt(self, button)
    UnitVisual.AttachButton(self, button)
    button:HookScript('OnShow', updateBackground)
    button:HookScript('OnHide', updateBackground)
    self:SetUnit(button:GetAttribute('unit'))
    rows[#rows + 1] = self
end

-- Edit Mode handle (EditMode.Register's box): the left edge moves in from the cursor's overhang
-- to the portrait.
function RaidPets.EditBox()
    local spec = RaidPets.spec
    return { left = -(-spec.cursor.pos[1] + spec.portrait.pos[1]) }
end

function RaidPets.Create(style, fonts)
    RaidPets.style = style.raid
    RaidPets.spec = style.raid.pets
    RaidPets.fonts = fonts
    local raidStyle, spec = RaidPets.style, RaidPets.spec
    local columnCount = math.ceil(spec.max / spec.perColumn)

    local anchor = CreateFrame('Frame', 'EorzeaUIRaidPetsAnchor', UIParent)
    local labelTop = -raidStyle.groupNumber.pos[2]
    anchor:SetSize(-spec.cursor.pos[1] + columnX(columnCount) + raidStyle.background.pos[1] + raidStyle.background.width,
        labelTop + spec.perColumn * (spec.rowHeight + raidStyle.rowSpacing) + raidStyle.background.bottom.height)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    RaidPets.anchor = anchor

    -- Plain parent of the header, so the demo can hide it out of combat.
    local live = CreateFrame('Frame', nil, anchor)
    live:SetAllPoints(anchor)
    live:SetFrameLevel(anchor:GetFrameLevel() + 2)
    RaidPets.live = live

    local header = CreateFrame('Frame', 'EorzeaUIRaidPets', live, 'SecureGroupPetHeaderTemplate')
    -- Hidden while configured, so each attribute does not relayout the header.
    header:Hide()
    header:SetPoint('TOPLEFT', anchor, 'TOPLEFT', -spec.cursor.pos[1], -labelTop)
    header:SetAttribute('template', 'EorzeaUIRaidPetButtonTemplate')
    header:SetAttribute('templateType', 'Button')
    header:SetAttribute('showRaid', true)
    header:SetAttribute('sortMethod', 'INDEX')
    header:SetAttribute('point', 'TOP')
    header:SetAttribute('yOffset', -raidStyle.rowSpacing)
    header:SetAttribute('unitsPerColumn', spec.perColumn)
    header:SetAttribute('maxColumns', columnCount)
    header:SetAttribute('columnAnchorPoint', 'LEFT')
    header:SetAttribute('columnSpacing', EUI.RaidList.ColumnStep(raidStyle) - raidStyle.width)
    RaidPets.header = header
    RaidPets.columns = createColumns(header)

    -- A negative startingIndex makes the header build every button now, out of combat.
    header:Show()
    header:SetAttribute('startingIndex', 1 - spec.max)
    header:SetAttribute('startingIndex', 1)
    for i = 1, spec.max do
        local button = header[i]
        if not button then
            EUI.LogOnce('raid:petButton', 'raid pet header built %d of %d buttons', i - 1, spec.max)
            break
        end
        attachRow(button)
    end
    RaidPets.header = header
    if RegisterStateDriver then
        RegisterStateDriver(header, 'visibility', VISIBILITY)
    end
    updateBackground()
    EUI.Log('raid: built %d pet rows', #rows)
end

-- Hides the block whatever the group (the raid manager's Hide). Out of combat only.
function RaidPets.SetHidden(hidden)
    if RegisterStateDriver and RaidPets.header then
        RegisterStateDriver(RaidPets.header, 'visibility', hidden and 'hide' or VISIBILITY)
    end
end

-- The row showing unit (raidpetN), if shown.
function RaidPets.ForUnit(unit)
    local row = rowsByUnit[unit]
    if row and row.button:IsVisible() then
        return row
    end
    return nil
end

function RaidPets.ForEachVisible(fn)
    for _, row in ipairs(rows) do
        if row.button:IsVisible() and row.unit then
            fn(row)
        end
    end
end

-- A pet swap keeps the owner's raidpetN token.
function RaidPets.RefreshAll()
    RaidPets.ForEachVisible(function(row)
        row:Refresh()
    end)
    updateBackground()
end

-- pets: a list of PetCell ShowDemo tables, or nil to restore the live rows. Out of combat only.
function RaidPets.SetDemo(pets)
    local spec = RaidPets.spec
    if not RaidPets.demoFrame then
        local frame = CreateFrame('Frame', nil, RaidPets.anchor)
        frame:SetAllPoints(RaidPets.anchor)
        frame:SetFrameLevel(RaidPets.live:GetFrameLevel() + 5)
        RaidPets.demoFrame = frame
        local origin = CreateFrame('Frame', nil, frame)
        origin:SetSize(RaidPets.style.width, spec.rowHeight)
        origin:SetPoint('TOPLEFT', RaidPets.anchor, 'TOPLEFT', -spec.cursor.pos[1], RaidPets.style.groupNumber.pos[2])
        RaidPets.demoColumns = createColumns(origin)
        RaidPets.demoRows = {}
        for i = 1, spec.max do
            local column = math.floor((i - 1) / spec.perColumn) + 1
            local index = (i - 1) % spec.perColumn
            local host = CreateFrame('Frame', nil, origin)
            host:SetSize(RaidPets.style.width, spec.rowHeight)
            host:SetPoint('TOPLEFT', origin, 'TOPLEFT', columnX(column), -index * (spec.rowHeight + RaidPets.style.rowSpacing))
            local row = setmetatable({ host = host }, PetCell)
            buildArt(row, host)
            RaidPets.demoRows[i] = row
        end
    end
    if pets then
        for i, row in ipairs(RaidPets.demoRows) do
            row:ShowDemo(pets[i])
        end
        sizeColumns(RaidPets.demoColumns, math.min(#pets, spec.max))
    end
    RaidPets.demoFrame:SetShown(pets ~= nil)
    RaidPets.live:SetShown(pets == nil)
end
