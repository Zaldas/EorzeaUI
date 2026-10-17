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
    if not style.cursor.onTop then
        self.cursor = Style.Image(art, 'BACKGROUND', style.cursor, 2)
        self.cursor:Hide()
    end

    self.hp = AV.Bar.Create(art, style.hp.bar, style.hp.pos, { prediction = style.indicators.healPrediction })
    self.hpText = Style.Text(self.hp.overlay, style.hp.txtValue, fonts)
    self.hpCurve = AV.Curves.Step(style.hp.thresholds, style.hp.textColor)
    self.lowHealthCurve = AV.Curves.Step({ style.lowHealth }, '#FFFFFFFF')

    self.power = AV.Bar.Create(art, style.power.bar, style.power.pos)
    self.powerText = Style.Text(self.power.overlay, style.power.txtValue, fonts)

    if style.cast then
        self.cast = AV.CastBar.Create(art, nil, style.cast, fonts, style.cast.pos)
        -- The cast bar takes the name row. Alpha, not Hide, so marker updates mid-cast stick.
        self.cast.onVisibility = function(casting)
            local alpha = casting and 0 or 1
            self.name:SetAlpha(alpha)
            self.indicators.raidMarker:SetAlpha(alpha)
        end
    end

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


    -- Row-relative text and markers, drawn above both bars.
    local top = CreateFrame('Frame', nil, art)
    top:SetAllPoints(art)
    top:SetFrameLevel(self.power.overlay:GetFrameLevel() + 1)

    self.threat = Style.Image(top, 'OVERLAY', style.threat)
    self.threat:Hide()
    self.combo = AV.ComboPoints.Create(top, style.comboPoints)

    -- Cut off with an ellipsis before the aura icons.
    self.name = Style.Text(top, style.txtName, fonts)
    self.name:SetWidth(style.txtName.width)
    self.name:SetWordWrap(false)

    self.levelBadge = AV.LevelBadge.Create(iconFrame, iconFrame, style.levelBadge, fonts)
    self.levelBadge.frame:SetFrameLevel(iconFrame:GetFrameLevel() + 2)

    local markers = CreateFrame('Frame', nil, art)
    markers:SetAllPoints(art)
    markers:SetFrameLevel(iconFrame:GetFrameLevel() + 3)
    self.indicators = AV.Indicators.Create(markers, top, style)

    -- cursor.onTop: a pointer drawn over the indicators rather than a highlight behind the row.
    if style.cursor.onTop then
        local pointer = CreateFrame('Frame', nil, art)
        pointer:SetAllPoints(art)
        pointer:SetFrameLevel(markers:GetFrameLevel() + 1)
        self.cursor = Style.Image(pointer, 'OVERLAY', style.cursor)
        self.cursor:Hide()
    end
    self.tagFormat = '|cff' .. style.indicators.tagColor:sub(2, 7) .. '[%s]|r %s'
end

-- name may be secret: SetFormattedText accepts it, concatenation would not.
local function setName(self, name)
    if self.flagTag then
        pcall(self.name.SetFormattedText, self.name, self.tagFormat, self.flagTag, name)
    else
        pcall(self.name.SetText, self.name, name)
    end
end

-- Blizzard's GetThreatStatusColor values for statuses 1-3, used when that function is absent.
local THREAT_COLORS = { { 1, 1, 0.47 }, { 1, 0.6, 0 }, { 1, 0, 0 } }

-- status: UnitThreatSituation result. 1 high threat, 2 tanking but not highest, 3 securely tanking.
local function setThreat(self, status)
    if type(status) ~= 'number' or status < 1 then
        self.threat:Hide()
        return
    end
    status = math.min(status, 3)
    local r, g, b
    if GetThreatStatusColor then
        local ok, red, green, blue = pcall(GetThreatStatusColor, status)
        if ok then
            r, g, b = red, green, blue
        end
    end
    if not r then
        r, g, b = unpack(THREAT_COLORS[status])
    end
    self.threat:SetVertexColor(r, g, b, 1)
    self.threat:Show()
end

-- Recolours the power bar when the power type changes (druid forms, unit swaps).
local function tintPower(self, powerType)
    if powerType == self.powerType then
        return
    end
    self.powerType = powerType
    local spec = self.style.power
    local color = spec.colors and spec.colors[powerType] or spec.bar.fill.color
    self.power:SetFrameColor(color)
    self.power:SetFillColor(color)
end

local STATE_LABELS = { dead = 'DEAD', ghost = 'GHOST', offline = 'OFFLINE' }

-- state: 'dead' | 'ghost' | 'offline' | nil. Returns true when a label replaced the HP value.
local function applyState(self, state)
    self.state = state
    self.classIcon:SetDesaturated(state ~= nil)
    if state then
        self.classIcon:SetVertexColor(1, 1, 1, 1)
    end
    if not state then
        return false
    end
    self.hp:SetValue(0)
    self.hp:SetIncoming(0)
    self.hpText:SetText(STATE_LABELS[state])
    self.hpText:SetTextColor(Style.Color(self.style.indicators.stateColor))
    return true
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
    host:SetPoint('TOPLEFT', parent, 'TOPLEFT', 0, -(index - 1) * (style.rowHeight + style.rowSpacing))
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

-- member = { name, class, level, hp, hpMax, incoming, power, powerMax, leader, targeted, far,
--            state, resting, status, raidMarker, tag, role, pvp, cast, threat, powerType,
--            combo, assistant, masterLooter, buffs, debuffs }
function Row:ShowDemo(member)
    self.host:SetShown(member ~= nil)
    if not member then
        return
    end
    setClassIcon(self, member.class)
    self.flagTag = member.tag
    setName(self, member.name)
    self.levelBadge:Set(member.level)

    self.hp:SetRange(member.hpMax)
    if not applyState(self, member.state) then
        self.hp:SetValue(member.hp)
        self.hp:SetIncoming(member.incoming or 0, member.hpMax)
        self.hpText:SetText(BreakUpLargeNumbers and BreakUpLargeNumbers(member.hp) or tostring(member.hp))
        self.hpText:SetTextColor(Style.Color(thresholdColor(self.style, member.hp / member.hpMax)))
        local low = member.hp / member.hpMax < self.style.lowHealth.below
        self.classIcon:SetVertexColor(Style.Color(low and self.style.lowHealth.color or '#FFFFFFFF'))
    end

    local indicators = self.indicators
    indicators:SetPlayerState(member.resting and 'rest' or nil)
    indicators:SetStatus(member.status)
    indicators:SetRaidMarker(member.raidMarker)
    indicators:SetRole(member.role)
    indicators:SetPvP(member.pvp)
    if self.cast then
        self.cast:SetPreview(member.cast, 0.4)
    end
    indicators:LayoutNameLine(self.name)

    tintPower(self, member.powerType)
    self.power:SetRange(member.powerMax)
    self.power:SetValue(member.power)
    self.combo:SetShown(member.combo ~= nil)
    self.combo:SetCount(member.combo)
    self.powerText:SetText(BreakUpLargeNumbers and BreakUpLargeNumbers(member.power) or tostring(member.power))

    indicators:SetLeader(member.leader == true)
    indicators:SetAssistant(member.assistant == true)
    indicators:SetMasterLooter(member.masterLooter == true)
    self.cursor:SetShown(member.targeted == true)
    setThreat(self, member.threat)
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
    self.readyStatus = nil
    AV.PartyList.OnRowUnitChanged(self, previous, unit)
    if unit then
        self.buffs:SetUnit(unit)
        if self.cast then
            self.cast:SetUnit(unit)
        end
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
    self:UpdateCast()
    self:UpdateThreat()
    self:UpdateCombo()
    self:UpdateFlags()
    self:UpdateRole()
    self:UpdatePvP()
    self:UpdateRaidMarker()
    self:UpdatePlayerState()
    self:UpdateReadyCheck(AV.PartyList.ReadyCheckPhase())
    self.buffs:Refresh()
    self.debuffs:Refresh()
end

function Row:IsPlayer()
    local guid = self.unit and AV.SafeValue(UnitGUID, self.unit)
    return guid ~= nil and guid == AV.SafeValue(UnitGUID, 'player')
end

local function readState(unit)
    if AV.Read('UnitIsConnected', UnitIsConnected, unit) == false then
        return 'offline'
    end
    if AV.Read('UnitIsGhost', UnitIsGhost, unit) then
        return 'ghost'
    end
    if AV.Read('UnitIsDead', UnitIsDead, unit) then
        return 'dead'
    end
    return nil
end

function Row:UpdateName()
    local unit = self.unit
    setClassIcon(self, AV.SafeValue(function() return select(2, UnitClass(unit)) end))
    setName(self, AV.UnitDisplayName(unit))
    self.levelBadge:Set(AV.SafeValue(UnitLevel, unit))
end

function Row:UpdateHealth(smooth)
    local unit = self.unit
    local maxHealth = UnitHealthMax(unit)
    self.hp:SetRange(maxHealth)
    if applyState(self, readState(unit)) then
        return
    end
    local health = UnitHealth(unit)
    self.hp:SetValue(health, smooth)
    AV.SetNumberText(self.hpText, health)
    AV.Curves.ApplyHealthColor(self.hpText, unit, self.hpCurve)
    AV.Curves.ApplyHealthTint(self.classIcon, unit, self.lowHealthCurve)
    self.hp:ShowIncomingHeals(unit, maxHealth)
end

function Row:UpdateHealPrediction()
    if not self.state then
        self.hp:ShowIncomingHeals(self.unit, UnitHealthMax(self.unit))
    end
end

-- Death and connection changes: the HP slot and the offline dimming.
function Row:UpdateState()
    self:UpdateHealth(false)
    self:UpdateRange()
end

function Row:UpdateThreat()
    setThreat(self, AV.Read('UnitThreatSituation', UnitThreatSituation, self.unit))
end

function Row:UpdateCast()
    if self.cast then
        self.cast:Update()
    end
end

function Row:UpdateFlags()
    local unit = self.unit
    local tag
    if AV.Read('UnitIsAFK', UnitIsAFK, unit) then
        tag = 'AFK'
    elseif AV.Read('UnitIsDND', UnitIsDND, unit) then
        tag = 'DND'
    end
    self.flagTag = tag
    setName(self, AV.UnitDisplayName(unit))
end

function Row:UpdateRole()
    self.indicators:SetRole(AV.Read('UnitGroupRolesAssigned', UnitGroupRolesAssigned, self.unit))
end

function Row:UpdatePvP()
    local unit = self.unit
    local kind
    if AV.Read('UnitIsPVPFreeForAll', UnitIsPVPFreeForAll, unit) then
        kind = 'FFA'
    elseif AV.Read('UnitIsPVP', UnitIsPVP, unit) then
        kind = AV.Read('UnitFactionGroup', UnitFactionGroup, unit)
    end
    self.indicators:SetPvP(kind)
end

function Row:UpdateRaidMarker()
    self.indicators:SetRaidMarker(AV.Read('GetRaidTargetIndex', GetRaidTargetIndex, self.unit))
    self.indicators:LayoutNameLine(self.name)
end

-- Rest and combat show on the player's own row only.
function Row:UpdatePlayerState()
    local state
    if self:IsPlayer() then
        if AV.inCombat then
            state = 'combat'
        elseif AV.Read('IsResting', IsResting) then
            state = 'rest'
        end
    end
    self.indicators:SetPlayerState(state)
end

-- phase: 'active' while a check runs, 'finished' while results linger, nil otherwise.
-- Members still waiting when the check ends count as not ready.
function Row:UpdateReadyCheck(phase)
    if phase == 'active' then
        self.readyStatus = AV.Read('GetReadyCheckStatus', GetReadyCheckStatus, self.unit)
    elseif phase == 'finished' then
        if self.readyStatus == 'waiting' then
            self.readyStatus = 'notready'
        end
    else
        self.readyStatus = nil
    end
    self:UpdateStatusIcon()
end

-- Enum.SummonStatus: 1 pending, 2 accepted, 3 declined.
local SUMMON_ICONS = { 'summonPending', 'summonAccepted', 'summonDeclined' }

-- One centre icon, by priority: ready check, summon, resurrect, phased.
function Row:UpdateStatusIcon()
    local unit = self.unit
    local kind = self.readyStatus
    local summon = C_IncomingSummon
    if not kind and summon and AV.Read('HasIncomingSummon', summon.HasIncomingSummon, unit) then
        kind = SUMMON_ICONS[AV.Read('IncomingSummonStatus', summon.IncomingSummonStatus, unit)]
    end
    if not kind and AV.Read('UnitHasIncomingResurrection', UnitHasIncomingResurrection, unit) then
        kind = 'resurrect'
    end
    if not kind and AV.Read('UnitPhaseReason', UnitPhaseReason, unit) ~= nil then
        kind = 'phased'
    end
    self.indicators:SetStatus(kind)
end

function Row:UpdatePower(smooth)
    local unit = self.unit
    tintPower(self, AV.Read('UnitPowerType', UnitPowerType, unit))
    self.power:SetRange(UnitPowerMax(unit))
    local power = UnitPower(unit)
    self.power:SetValue(power, smooth)
    AV.SetNumberText(self.powerText, power)
end

local COMBO_POINTS = Enum and Enum.PowerType and Enum.PowerType.ComboPoints or 4
local ENERGY = 3

-- Rogues, and druids while on energy (cat form), with a target.
local function usesComboPoints()
    local class = AV.SafeValue(function() return select(2, UnitClass('player')) end)
    if class == 'DRUID' then
        return AV.Read('UnitPowerType', UnitPowerType, 'player') == ENERGY
    end
    return class == 'ROGUE'
end

function Row:UpdateCombo()
    local shown = self:IsPlayer() and usesComboPoints() and UnitExists('target')
    self.combo:SetShown(shown)
    if not shown then
        return
    end
    local ok, count = pcall(UnitPower, 'player', COMBO_POINTS)
    if not ok then
        AV.LogOnce('combo:error', 'combo points: %s', tostring(count))
        count = 0
    elseif not AV.CanAccess(count) then
        AV.LogOnce('combo:secret', 'combo points are secret; drawn through StatusBar ranges')
    end
    self.combo:SetCount(count)
end

function Row:UpdateLeader()
    self.indicators:SetLeader(AV.SafeBool(UnitIsGroupLeader, self.unit))
end

local function showNear(self, near)
    self.art:SetAlpha(near and 1 or self.style.range.farAlpha)
end

-- inRange is a secret boolean, so the engine picks between the alphas.
local function showNearSecret(self, inRange)
    return pcall(self.art.SetAlphaFromBoolean, self.art, inRange, 1, self.style.range.farAlpha)
end

-- UnitInRange is the 40-yard group check; CheckInteractDistance(unit, 4) (28 yards) is the fallback.
function Row:UpdateRange()
    local unit = self.unit
    if self.state == 'offline' then
        showNear(self, false)
        return
    end
    if not unit or self:IsPlayer() then
        showNear(self, true)
        return
    end
    if UnitInRange then
        local ok, inRange, checked = pcall(UnitInRange, unit)
        if not ok then
            AV.LogOnce('range:error', 'UnitInRange failed: %s', tostring(inRange))
        elseif AV.CanAccess(inRange) then
            if AV.CanAccess(checked) and checked then
                showNear(self, inRange == true)
                return
            end
        elseif self.art.SetAlphaFromBoolean and showNearSecret(self, inRange) then
            AV.LogOnce('range:secret', 'range: UnitInRange is secret; dimming via SetAlphaFromBoolean')
            return
        else
            AV.LogOnce('range:fallback', 'range: UnitInRange is secret and SetAlphaFromBoolean failed; using CheckInteractDistance')
        end
    end
    showNear(self, AV.SafeValue(CheckInteractDistance, unit, 4) ~= false)
end

-- GUIDs stay readable in combat, unlike UnitIsUnit against compound tokens.
function Row:UpdateCursor()
    local guid = self.unit and AV.SafeValue(UnitGUID, self.unit)
    local targetGuid = AV.SafeValue(UnitGUID, 'target')
    self.cursor:SetShown(guid ~= nil and guid == targetGuid)
end
