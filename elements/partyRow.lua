local _, AV = ...

-- Visuals for one secure party button. The SecureGroupHeader owns the button's unit attribute
-- and visibility; this only draws on it and follows unit changes.

AV.PartyRow = {}
local Row = {}
Row.__index = Row

local Style = AV.Style
local CLASS_ICONS = 'Interface\\TargetingFrame\\UI-Classes-Circles'

local function classColorHex(classToken)
    local color = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    if not color then
        return '#808080FF'
    end
    return string.format('#%02X%02X%02XFF', color.r * 255, color.g * 255, color.b * 255)
end

local function buildArt(self, host, style, fonts)
    -- Art lives on a child frame so a secure host keeps all mouse input.
    local art = CreateFrame('Frame', nil, host)
    art:SetAllPoints(host)
    art:EnableMouse(false)
    self.art = art

    self.hover = Style.Image(art, 'BACKGROUND', style.hover, 1)
    self.hover:Hide()
    self.cursor = Style.Image(art, 'BACKGROUND', style.cursor, 2)
    self.cursor:Hide()

    self.hp = AV.Bar.Create(art, style.hp.bar, style.hp.pos)
    self.hpText = Style.Text(self.hp.overlay, style.hp.txtValue, fonts)
    self.hpCurve = AV.Curves.Step(style.hp.thresholds, style.hp.textColor)

    self.power = AV.Bar.Create(art, style.power.bar, style.power.pos)
    self.powerText = Style.Text(self.power.overlay, style.power.txtValue, fonts)

    local iconSpec = style.classIcon
    local iconFrame = CreateFrame('Frame', nil, art)
    iconFrame:SetSize(iconSpec.size, iconSpec.size)
    Style.Place(iconFrame, art, iconSpec.pos)
    iconFrame:SetFrameLevel(self.power.overlay:GetFrameLevel() + 1)
    local full = { pos = { 0, 0 }, size = { iconSpec.size, iconSpec.size } }
    Style.Image(iconFrame, 'BACKGROUND', { path = iconSpec.bg, pos = full.pos, size = full.size })
    self.classGradient = Style.Image(iconFrame, 'BORDER', { path = iconSpec.gradient, pos = full.pos, size = full.size })
    self.classIcon = iconFrame:CreateTexture(nil, 'ARTWORK')
    self.classIcon:SetTexture(CLASS_ICONS)
    self.classIcon:SetPoint('TOPLEFT', 5, -5)
    self.classIcon:SetPoint('BOTTOMRIGHT', -5, 5)
    Style.Image(iconFrame, 'OVERLAY', { path = iconSpec.frame, pos = full.pos, size = full.size })
    self.iconFrame = iconFrame

    self.leader = Style.Image(iconFrame, 'OVERLAY', {
        path = style.leader.path, size = style.leader.size, color = style.leader.color,
        pos = { style.leader.pos[1] - iconSpec.pos[1], style.leader.pos[2] - iconSpec.pos[2] },
    }, 1)
    self.leader:Hide()

    -- Row-relative text and markers, drawn above both bars.
    local top = CreateFrame('Frame', nil, art)
    top:SetAllPoints(art)
    top:SetFrameLevel(self.power.overlay:GetFrameLevel() + 1)

    self.rangeNear = Style.Image(top, 'OVERLAY', style.range.near)
    self.rangeFar = Style.Image(top, 'OVERLAY', style.range.far)
    self.rangeFar:Hide()

    -- Cut off with an ellipsis before the aura icons.
    self.name = Style.Text(top, style.txtName, fonts)
    self.name:SetWidth(style.txtName.width)
    self.name:SetWordWrap(false)

    self.levelBadge = AV.LevelBadge.Create(iconFrame, iconFrame, style.levelBadge, fonts)
    self.levelBadge.frame:SetFrameLevel(iconFrame:GetFrameLevel() + 2)
end

function AV.PartyRow.Attach(button, style, fonts)
    local self = setmetatable({ button = button, style = style }, Row)
    buildArt(self, button, style, fonts)
    local art = self.art

    -- AuraContainers are created at login (out of combat) with the button's initial unit.
    local initialUnit = button:GetAttribute('unit') or 'player'
    self.buffs = AV.AuraRow.Create(art, initialUnit, 'HELPFUL', style.buffs, fonts)
    self.debuffs = AV.AuraRow.Create(art, initialUnit, 'HARMFUL', style.debuffs, fonts)

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
    button:HookScript('OnShow', function()
        self:Refresh()
    end)

    self:SetUnit(button:GetAttribute('unit'))
    return self
end

-- A non-secure row showing fixed sample data. index is the 1-based row position.
function AV.PartyRow.CreateDemo(parent, style, fonts, index)
    local self = setmetatable({ style = style }, Row)
    local host = CreateFrame('Frame', nil, parent)
    host:SetSize(style.width, style.rowHeight)
    host:SetPoint('TOPLEFT', parent, 'TOPLEFT', 0, -(index - 1) * style.rowHeight)
    self.host = host
    buildArt(self, host, style, fonts)
    self.buffs = AV.StaticIcons.Create(self.art, style.buffs, fonts)
    self.debuffs = AV.StaticIcons.Create(self.art, style.debuffs, fonts)
    return self
end

-- The class sheet draws each icon as a ringed circle; cropping to the circle's inscribed
-- square (inset 14.6% per side) drops the ring so the art fills the square job frame.
local CIRCLE_INSET = 0.146

local function setClassIcon(self, classToken)
    local coords = classToken and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classToken]
    if coords then
        local left, right, top, bottom = unpack(coords)
        local dx, dy = (right - left) * CIRCLE_INSET, (bottom - top) * CIRCLE_INSET
        self.classIcon:SetTexCoord(left + dx, right - dx, top + dy, bottom - dy)
        self.classIcon:Show()
    else
        self.classIcon:Hide()
    end
    self.classGradient:SetVertexColor(Style.Color(classColorHex(classToken)))
end


local function thresholdColor(style, fraction)
    for _, step in ipairs(style.hp.thresholds) do
        if fraction < step.below then
            return step.color
        end
    end
    return style.hp.textColor
end

-- member = { name, class, level, hp, hpMax, power, powerMax, leader, targeted, far, buffs, debuffs }
function Row:ShowDemo(member)
    self.host:SetShown(member ~= nil)
    if not member then
        return
    end
    setClassIcon(self, member.class)
    self.name:SetText(member.name)
    self.levelBadge:Set(member.level)

    self.hp:SetRange(member.hpMax)
    self.hp:SetValue(member.hp)
    self.hpText:SetText(BreakUpLargeNumbers and BreakUpLargeNumbers(member.hp) or tostring(member.hp))
    self.hpText:SetTextColor(Style.Color(thresholdColor(self.style, member.hp / member.hpMax)))

    self.power:SetRange(member.powerMax)
    self.power:SetValue(member.power)
    self.powerText:SetText(BreakUpLargeNumbers and BreakUpLargeNumbers(member.power) or tostring(member.power))

    self.leader:SetShown(member.leader == true)
    self.cursor:SetShown(member.targeted == true)
    self.rangeNear:SetShown(not member.far)
    self.rangeFar:SetShown(member.far == true)
    self.art:SetAlpha(member.far and self.style.range.farAlpha or 1)

    self.buffs:Set(member.buffs)
    self.debuffs:Set(member.debuffs)
end

function Row:SetUnit(unit)
    if unit == self.unit then
        return
    end
    local previous = self.unit
    self.unit = unit
    AV.PartyList.OnRowUnitChanged(self, previous, unit)
    if unit then
        self.buffs:SetUnit(unit)
        self.debuffs:SetUnit(unit)
        self:Refresh()
    end
end

function Row:Refresh()
    if not self.unit or not UnitExists(self.unit) then
        return
    end
    self:UpdateName()
    self:UpdateHealth(false)
    self:UpdatePower(false)
    self:UpdateLeader()
    self:UpdateRange()
    self:UpdateCursor()
    self.buffs:Refresh()
    self.debuffs:Refresh()
end

function Row:UpdateName()
    local unit = self.unit
    setClassIcon(self, AV.SafeValue(function() return select(2, UnitClass(unit)) end))
    pcall(self.name.SetText, self.name, AV.UnitDisplayName(unit))
    self.levelBadge:Set(AV.SafeValue(UnitLevel, unit))
end

function Row:UpdateHealth(smooth)
    local unit = self.unit
    self.hp:SetRange(UnitHealthMax(unit))
    local health = UnitHealth(unit)
    self.hp:SetValue(health, smooth)
    AV.SetNumberText(self.hpText, health)
    AV.Curves.ApplyHealthColor(self.hpText, unit, self.hpCurve)
end

function Row:UpdatePower(smooth)
    local unit = self.unit
    self.power:SetRange(UnitPowerMax(unit))
    local power = UnitPower(unit)
    self.power:SetValue(power, smooth)
    AV.SetNumberText(self.powerText, power)
end

function Row:UpdateLeader()
    self.leader:SetShown(AV.SafeBool(UnitIsGroupLeader, self.unit))
end

function Row:UpdateRange()
    local unit = self.unit
    local near = true
    if unit and AV.SafeValue(UnitGUID, unit) ~= AV.SafeValue(UnitGUID, 'player') then
        local inRange = AV.SafeValue(CheckInteractDistance, unit, 4)
        near = inRange ~= false
    end
    self.rangeNear:SetShown(near)
    self.rangeFar:SetShown(not near)
    self.art:SetAlpha(near and 1 or self.style.range.farAlpha)
end

-- GUIDs stay readable in combat, unlike UnitIsUnit against compound tokens.
function Row:UpdateCursor()
    local guid = self.unit and AV.SafeValue(UnitGUID, self.unit)
    local targetGuid = AV.SafeValue(UnitGUID, 'target')
    self.cursor:SetShown(guid ~= nil and guid == targetGuid)
end
