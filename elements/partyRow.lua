local _, EUI = ...

-- Visuals for one secure party button or raid cell. Its list owns the button's unit attribute
-- and visibility; this only draws on it and follows unit changes. The form bar, level badge,
-- power value, cast bar, auras and pet sub-row are optional: a style without the spec builds
-- none.

EUI.PartyRow = {}
local Row = {}
Row.__index = Row

local Style = EUI.Style
local UnitVisual = EUI.UnitVisual
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

    self.hp = EUI.Bar.Create(art, style.hp.bar, style.hp.pos, { prediction = style.indicators.healPrediction })
    self.hpText = Style.Text(self.hp.overlay, style.hp.txtValue, fonts)
    self.hpCurve = EUI.Curves.Step(style.hp.thresholds, style.hp.textColor)
    self.missingCurve = EUI.Curves.HideAtFull(style.hp.thresholds, style.hp.textColor)
    self.lowHealthCurve = EUI.Curves.Step({ style.lowHealth }, '#FFFFFFFF')

    self.power = EUI.Bar.Create(art, style.power.bar, style.power.pos, { cost = style.power.cost })
    if style.power.txtValue then
        self.powerText = Style.Text(self.power.overlay, style.power.txtValue, fonts)
    end
    if style.formBar then
        self.formBar = EUI.Bar.Create(art, style.formBar.bar, style.formBar.pos, { cost = style.power.cost })
        self.formText = Style.Text(self.formBar.overlay, style.formBar.txtValue, fonts)
        self.formBar.frame:Hide()
    end

    if style.cast then
        self.cast = EUI.CastBar.Create(art, nil, style.cast, fonts, style.cast.pos)
        -- The cast bar takes the name row. Alpha, not Hide, so marker and flag updates mid-cast stick.
        self.cast.onVisibility = function(casting)
            local alpha = casting and 0 or 1
            self.name:SetAlpha(alpha)
            self.indicators.raidMarker:SetAlpha(alpha)
            self.indicators.flag:SetAlpha(alpha)
        end
    end

    local iconSpec = style.classIcon
    local iconFrame
    iconFrame, self.classGradient, self.classIcon = UnitVisual.JobFrame(art, iconSpec.pos, iconSpec.size, iconSpec.size / 8, iconSpec)
    iconFrame:SetFrameLevel(self.power.overlay:GetFrameLevel() + 1)
    self.classIcon:SetTexture(CLASS_ICONS)

    -- Row-relative text and markers, drawn above both bars.
    local top = CreateFrame('Frame', nil, art)
    top:SetAllPoints(art)
    top:SetFrameLevel(self.power.overlay:GetFrameLevel() + 1)

    -- Cut off with an ellipsis before the aura icons.
    self.name = Style.Text(top, style.txtName, fonts)
    self.name:SetWidth(style.txtName.width)
    self.name:SetWordWrap(false)

    if style.levelBadge then
        self.levelBadge = EUI.LevelBadge.Create(iconFrame, iconFrame, style.levelBadge, fonts)
        self.levelBadge.frame:SetFrameLevel(iconFrame:GetFrameLevel() + 2)
    end

    local markers = CreateFrame('Frame', nil, art)
    markers:SetAllPoints(art)
    markers:SetFrameLevel(iconFrame:GetFrameLevel() + 3)
    self.indicators = EUI.Indicators.Create(markers, top, style)
    self.threat = Style.Image(markers, 'OVERLAY', style.threat)
    self.threat:Hide()

    -- cursor.onTop: a pointer drawn over the indicators rather than a highlight behind the row.
    if style.cursor.onTop then
        local pointer = CreateFrame('Frame', nil, art)
        pointer:SetAllPoints(art)
        pointer:SetFrameLevel(markers:GetFrameLevel() + 1)
        self.cursor = Style.Image(pointer, 'OVERLAY', style.cursor)
        self.cursor:Hide()
    end
end

-- name may be secret.
local function setName(self, name)
    pcall(self.name.SetText, self.name, name)
end

-- status: UnitThreatSituation result. 1 high threat, 2 tanking but not highest, 3 securely tanking.
local function setThreat(self, status)
    if type(status) ~= 'number' or status < 1 or self.style.threat.hidden then
        self.threat:Hide()
        return
    end
    local r, g, b = EUI.Indicators.ThreatColor(status)
    self.threat:SetVertexColor(r, g, b, 1)
    self.threat:Show()
end

-- value: a number (possibly secret), or nil to clear.
local function setPowerText(self, value)
    if self.powerText then
        EUI.SetNumberText(self.powerText, value)
    end
end

-- Stands in for a power type while the member is offline.
local OFFLINE = 'offline'

-- Recolours a power bar when its power type changes (druid forms, unit swaps, going offline).
local function tintPower(self, bar, powerType)
    local spec = self.style.power
    local color
    if powerType == OFFLINE then
        color = self.style.hp.offlineColor
    else
        color = spec.colors and spec.colors[powerType] or spec.bar.fill.color
    end
    UnitVisual.TintBar(bar, powerType, color)
end

-- The HP bar's fill and line art: offline members get style.hp.offlineColor, as on Blizzard's
-- frames; else the class colour while style.hp.classColor (settings) and the class is known; else
-- the palette's.
local function applyHealthColor(self)
    local hp = self.style.hp
    local fill, frame = hp.bar.fill.color, hp.bar.bg.color
    if self.offline then
        fill, frame = hp.offlineColor, hp.offlineColor
    elseif hp.classColor and self.classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[self.classToken] then
        fill = classColorHex(self.classToken)
        frame = fill
    end
    if fill == self.healthFill and frame == self.healthFrame then
        return
    end
    self.healthFill, self.healthFrame = fill, frame
    self.hp:SetFillColor(fill)
    self.hp:SetFrameColor(frame)
end

-- state: 'dead' | 'ghost' | 'offline' | nil. Returns true when a label replaced the HP value.
-- maxHealth fills the bar while offline; it may be secret.
local function applyState(self, state, maxHealth)
    -- The health curve recolours the text afterwards; without one it keeps this colour.
    if self.state and not state then
        self.hpText:SetTextColor(Style.Color(self.style.hp.textColor))
    end
    self.state = state
    self.offline = state == 'offline'
    applyHealthColor(self)
    self.classIcon:SetDesaturated(state ~= nil)
    if state then
        self.classIcon:SetVertexColor(1, 1, 1, 1)
    end
    if not state then
        return false
    end
    self.hp:SetValue(state == 'offline' and maxHealth or 0)
    self.hp:SetIncoming(0)
    self.hpText:SetText(EUI.UnitInfo.STATE_LABELS[state])
    self.hpText:SetTextColor(Style.Color(self.style.indicators.stateColor))
    return true
end

-- hooks = { unitChanged(row, previous, unit), readyCheckPhase() }: the party list's callbacks.
function EUI.PartyRow.Attach(button, style, fonts, hooks)
    local self = setmetatable({ button = button, style = style, hooks = hooks }, Row)
    buildArt(self, button, style, fonts)
    local art = self.art

    -- AuraContainers are created at login (out of combat) with the button's initial unit.
    local initialUnit = button:GetAttribute('unit') or 'player'
    if style.auras then
        self.auras = EUI.AuraRow.Create(art, initialUnit, style.auras.order, style.auras, fonts)
    end

    UnitVisual.AttachButton(self, button)

    self:SetUnit(button:GetAttribute('unit'))
    return self
end

-- A non-secure row showing fixed sample data; PartyList.StackDemoRows places it.
function EUI.PartyRow.CreateDemo(parent, style, fonts)
    local self = setmetatable({ style = style }, Row)
    local host = CreateFrame('Frame', nil, parent)
    host:SetSize(style.width, style.rowHeight)
    self.host = host
    buildArt(self, host, style, fonts)
    if style.auras then
        self.auras = EUI.StaticIcons.Create(self.art, style.auras, fonts)
    end
    if style.pet then
        self.pet = EUI.PetRow.CreateDemo(host, self, style, fonts)
    end
    return self
end

local function setClassIcon(self, classToken)
    local coords = classToken and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classToken]
    if coords then
        UnitVisual.CropCircle(self.classIcon, unpack(coords))
        self.classIcon:Show()
    else
        self.classIcon:Hide()
    end
    self.classGradient:SetVertexColor(Style.Color(classColorHex(classToken)))
    self.classToken = classToken
    applyHealthColor(self)
end

-- The height a demo row needs to show member: the base row plus its form and pet sub-rows.
function Row:DemoHeight(member)
    local style = self.style
    return style.rowHeight + (member.form and style.formRowHeight or 0) + (member.pet and style.pet.rowHeight or 0)
end

-- member = { name, class, level, hp, hpMax, incoming, power, powerMax, leader, guide, targeted, far,
--            state, resting, combat, status, raidMarker, tag, role, pvp, cast, threat, powerType,
--            form = { powerType, power, powerMax }, assistant, masterLooter, absorb,
--            buffs, debuffs (shown in the live order), or auras (one prepared list), pet (see PetRow
--            ShowDemo) }
function Row:ShowDemo(member)
    self.host:SetShown(member ~= nil)
    if not member then
        return
    end
    setClassIcon(self, member.class)
    setName(self, member.name)
    if self.levelBadge then
        self.levelBadge:Set(member.level)
    end

    self.hp:SetRange(member.hpMax)
    if not applyState(self, member.state, member.hpMax) then
        self.hp:SetValue(member.hp)
        self.hp:SetIncoming(member.incoming or 0, member.hpMax, member.absorb or 0)
        local mode = self.style.hp.textMode
        if mode == 'missing' then
            local missing = member.hpMax - member.hp
            self.hpText:SetText(missing > 0 and '-' .. UnitVisual.FormatNumber(missing) or '')
        elseif mode == 'percent' then
            self.hpText:SetText(string.format('%.0f%%', member.hp / member.hpMax * 100))
        elseif mode == 'none' then
            self.hpText:SetText('')
        else
            self.hpText:SetText(UnitVisual.FormatNumber(member.hp))
        end
        self.hpText:SetTextColor(Style.Color(UnitVisual.ThresholdColor(self.style.hp, member.hp / member.hpMax)))
        local low = not self.style.lowHealth.hidden and member.hp / member.hpMax < self.style.lowHealth.below
        self.classIcon:SetVertexColor(Style.Color(low and self.style.lowHealth.color or '#FFFFFFFF'))
    end

    local indicators = self.indicators
    local playerState
    if member.combat then
        playerState = 'combat'
    elseif member.resting then
        playerState = 'rest'
    end
    indicators:SetPlayerState(playerState)
    indicators:SetStatus(member.status)
    indicators:SetRaidMarker(member.raidMarker)
    indicators:SetFlag(member.tag)
    indicators:SetRole(member.role)
    indicators:SetPvP(member.pvp)
    if self.cast then
        self.cast:SetPreview(member.cast, 0.4)
    end
    indicators:LayoutNameLine(self.name)

    local offline = member.state == 'offline'
    tintPower(self, self.power, offline and OFFLINE or member.powerType)
    self.power:SetRange(member.powerMax)
    self.power:SetValue(offline and member.powerMax or member.power)
    local show = self.style.power.show
    self.power.frame:SetShown(show ~= 'none' and (show ~= 'healers' or member.role == 'HEALER'))
    local form = self.formBar and member.form
    if self.formBar then
        self.formBar.frame:SetShown(form ~= nil)
    end
    if form then
        tintPower(self, self.formBar, form.powerType)
        self.formBar:SetRange(form.powerMax)
        self.formBar:SetValue(form.power)
        self.formText:SetText(UnitVisual.FormatNumber(form.power))
    end
    if self.powerText then
        self.powerText:SetText(offline and '' or UnitVisual.FormatNumber(member.power))
    end

    indicators:SetLeader(member.leader == true, member.guide == true)
    indicators:SetAssistant(member.assistant == true)
    indicators:SetMasterLooter(member.masterLooter == true)
    self.cursor:SetShown(member.targeted == true)
    setThreat(self, member.threat)
    self.art:SetAlpha(member.far and self.style.range.farAlpha or 1)

    if self.auras then
        self.auras:Set(member.auras or EUI.StaticIcons.Grouped(member.debuffs, member.buffs))
    end

    if not self.pet then
        return
    end
    -- The pet sub-row follows the form sub-row when both show.
    local petY = self.style.rowHeight + (form and self.style.formRowHeight or 0)
    self.pet.host:ClearAllPoints()
    self.pet.host:SetPoint('TOPLEFT', self.host, 'TOPLEFT', 0, -petY)
    self.pet:ShowDemo(member.pet)
end

function Row:SetUnit(unit)
    if unit == self.unit then
        return
    end
    local previous = self.unit
    self.unit = unit
    self.readyStatus = nil
    self.hooks.unitChanged(self, previous, unit)
    if unit then
        if self.auras then
            self.auras:SetUnit(unit)
        end
        if self.cast then
            self.cast:SetUnit(unit)
        end
        self:Refresh()
    end
end

function Row:Refresh()
    if not self.unit or not UnitExists(self.unit) then
        return
    end
    self:UpdateSelf()
    self:UpdateName()
    self:UpdateHealth(false)
    self:UpdatePower(false)
    self:UpdateLeader()
    self:UpdateGroupRoles()
    self:UpdateRange()
    self:UpdateCursor()
    self:UpdateCast()
    self:UpdateThreat()
    self:UpdateFlags()
    self:UpdateRole()
    self:UpdatePvP()
    self:UpdateRaidMarker()
    self:UpdatePlayerState()
    self:UpdateReadyCheck(self.hooks.readyCheckPhase())
    if self.auras then
        self.auras:Refresh()
    end
end

-- The party list's first row, bound to 'player'.
function Row:IsPlayer()
    return self.unit == 'player'
end

-- isSelf: the unit is you by any token (the raidN cell for you). Rechecked on refresh, as a
-- roster change can put someone else behind the same token.
function Row:UpdateSelf()
    local guid = EUI.SafeValue(UnitGUID, self.unit)
    self.isSelf = guid ~= nil and guid == EUI.SafeValue(UnitGUID, 'player')
end

local function readState(unit)
    if EUI.Read('UnitIsConnected', UnitIsConnected, unit) == false then
        return 'offline'
    end
    if EUI.Read('UnitIsGhost', UnitIsGhost, unit) then
        return 'ghost'
    end
    if EUI.Read('UnitIsDead', UnitIsDead, unit) then
        return 'dead'
    end
    return nil
end

function Row:UpdateName()
    local unit = self.unit
    setClassIcon(self, EUI.SafeValue(function() return select(2, UnitClass(unit)) end))
    setName(self, EUI.UnitDisplayName(unit))
    if self.levelBadge then
        self.levelBadge:Set(EUI.SafeValue(UnitEffectiveLevel or UnitLevel, unit))
    end
    if self.pet then
        self.pet:UpdateGradient()
    end
end

function Row:UpdateHealth(smooth)
    local unit = self.unit
    local maxHealth = UnitHealthMax(unit)
    self.hp:SetRange(maxHealth)
    if applyState(self, readState(unit), maxHealth) then
        return
    end
    local health = UnitHealth(unit)
    self.hp:SetValue(health, smooth)
    -- textMode (settings): 'current' (default), 'missing' (blank at full), 'percent' or 'none'.
    local mode = self.style.hp.textMode
    if mode == 'missing' and UnitHealthMissing then
        EUI.SetNumberText(self.hpText, UnitHealthMissing(unit), '-')
        EUI.Curves.ApplyHealthColor(self.hpText, unit, self.missingCurve)
    elseif mode == 'percent' then
        EUI.Curves.SetHealthPercentText(self.hpText, unit)
        EUI.Curves.ApplyHealthColor(self.hpText, unit, self.hpCurve)
    elseif mode == 'none' then
        self.hpText:SetText('')
    else
        EUI.SetNumberText(self.hpText, health)
        EUI.Curves.ApplyHealthColor(self.hpText, unit, self.hpCurve)
    end
    if self.style.lowHealth.hidden then
        self.classIcon:SetVertexColor(1, 1, 1, 1)
    else
        EUI.Curves.ApplyHealthTint(self.classIcon, unit, self.lowHealthCurve)
    end
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
    self:UpdatePower(false)
    self:UpdateRange()
end

-- As Blizzard's group frames: no threat colours on members while solo. Your own row shows it, as
-- the player frame does.
function Row:UpdateThreat()
    if not IsInGroup() and not self:IsPlayer() then
        setThreat(self, nil)
        return
    end
    setThreat(self, EUI.Read('UnitThreatSituation', UnitThreatSituation, self.unit))
end

function Row:UpdateCast()
    if self.cast then
        self.cast:Update()
    end
end

function Row:UpdateFlags()
    local unit = self.unit
    local tag
    if EUI.Read('UnitIsAFK', UnitIsAFK, unit) then
        tag = 'AFK'
    elseif EUI.Read('UnitIsDND', UnitIsDND, unit) then
        tag = 'DND'
    end
    self.indicators:SetFlag(tag)
    self.indicators:LayoutNameLine(self.name)
end

-- The raid role (main tank or assist) wins over the assigned role, as on Blizzard's frames.
function Row:UpdateRole()
    local unit = self.unit
    local raidIndex = EUI.Read('UnitInRaid', UnitInRaid, unit)
    local role = raidIndex and EUI.Read('GetRaidRosterInfo', function()
        return select(10, GetRaidRosterInfo(raidIndex))
    end)
    if role == 'MAINTANK' or role == 'MAINASSIST' then
        EUI.LogOnce('raid:role:' .. role, 'raid: %s icon on %s', role, tostring(unit))
    else
        role = EUI.Read('UnitGroupRolesAssigned', UnitGroupRolesAssigned, unit)
    end
    self.indicators:SetRole(role)
    if self.style.power.show == 'healers' then
        self:UpdatePower(false)
    end
end

function Row:UpdatePvP()
    self.indicators:SetPvP(EUI.UnitInfo.PvPKind(self.unit))
end

function Row:UpdateRaidMarker()
    self.indicators:SetRaidMarker(EUI.Indicators.ReadRaidMarker(self.unit))
    self.indicators:LayoutNameLine(self.name)
end

-- Rest and combat show on the player's own row only.
function Row:UpdatePlayerState()
    local state
    if self:IsPlayer() then
        if EUI.inCombat then
            state = 'combat'
        elseif EUI.Read('IsResting', IsResting) then
            state = 'rest'
        end
    end
    self.indicators:SetPlayerState(state)
end

-- phase: 'active' while a check runs, 'finished' while results linger, nil otherwise.
-- Members still waiting when the check ends count as not ready. A result stays with the member
-- who gave it, not the token, which renumbers when someone leaves.
function Row:UpdateReadyCheck(phase)
    local guid = EUI.SafeValue(UnitGUID, self.unit)
    -- Offline members get no icon, as on Blizzard's party frames.
    if phase == 'active' and EUI.Read('UnitIsConnected', UnitIsConnected, self.unit) == false then
        self.readyStatus = nil
    elseif phase == 'active' then
        self.readyStatus = EUI.Read('GetReadyCheckStatus', GetReadyCheckStatus, self.unit)
        self.readyGuid = guid
    elseif phase == 'finished' then
        if guid ~= self.readyGuid then
            self.readyStatus = nil
        elseif self.readyStatus == 'waiting' then
            self.readyStatus = 'notready'
        end
    else
        self.readyStatus = nil
    end
    self:UpdateStatusIcon()
end

-- Enum.SummonStatus: 1 pending, 2 accepted, 3 declined.
local SUMMON_ICONS = { 'summonPending', 'summonAccepted', 'summonDeclined' }

-- A connected unit with a phase reason. With style.range.phaseDistance (raid cells), only within
-- that many yards, as Blizzard's raid frames: an unchecked distance counts as too far.
local function isPhased(self, unit)
    if EUI.Read('UnitIsConnected', UnitIsConnected, unit) ~= true
        or EUI.Read('UnitPhaseReason', UnitPhaseReason, unit) == nil then
        return false
    end
    local limit = self.style.range.phaseDistance
    if not limit then
        return true
    end
    local ok, distance, checked = pcall(UnitDistanceSquared, unit)
    return ok and checked == true and EUI.CanAccess(distance) and distance < limit * limit
end

local SUMMON_TOOLTIPS = {
    summonPending = INCOMING_SUMMON_TOOLTIP_SUMMON_PENDING,
    summonAccepted = INCOMING_SUMMON_TOOLTIP_SUMMON_ACCEPTED,
    summonDeclined = INCOMING_SUMMON_TOOLTIP_SUMMON_DECLINED,
}

-- Blizzard's centre icon tooltips: summons, in another group, and the phase reason. The reason
-- is secret for units whose identity is restricted; that phased icon gets none.
local function statusTooltip(kind, unit)
    if kind == 'otherGroup' then
        return PARTY_IN_PUBLIC_GROUP_MESSAGE
    elseif kind ~= 'phased' then
        return SUMMON_TOOLTIPS[kind]
    end
    local reason = EUI.Read('UnitPhaseReason', UnitPhaseReason, unit)
    if reason == nil or not EUI.CanAccess(reason) or not (PartyUtil and PartyUtil.GetPhasedReasonString) then
        return nil
    end
    local ok, text = pcall(PartyUtil.GetPhasedReasonString, reason, unit)
    return ok and text or nil
end

-- One centre icon, by priority: ready check, summon, resurrect, phased, in another group.
function Row:UpdateStatusIcon()
    local unit = self.unit
    local kind = self.readyStatus
    local summon = C_IncomingSummon
    if not kind and summon and EUI.Read('HasIncomingSummon', summon.HasIncomingSummon, unit) then
        kind = SUMMON_ICONS[EUI.Read('IncomingSummonStatus', summon.IncomingSummonStatus, unit)]
    end
    if not kind and EUI.Read('UnitHasIncomingResurrection', UnitHasIncomingResurrection, unit) then
        kind = 'resurrect'
    end
    if not kind and isPhased(self, unit) then
        kind = 'phased'
    end
    if not kind and EUI.Read('UnitInOtherParty', UnitInOtherParty, unit) then
        kind = 'otherGroup'
        EUI.LogOnce('status:otherGroup', 'in-another-group icon on %s', tostring(unit))
    end
    self.indicators:SetStatus(kind, kind and statusTooltip(kind, unit))
end

local MANA = 0

-- power.show (settings): 'none' hides the bar; 'healers' shows it on healers only.
local function powerShown(self)
    local show = self.style.power.show
    if show == 'none' then
        return false
    end
    if show == 'healers' then
        return EUI.Read('UnitGroupRolesAssigned', UnitGroupRolesAssigned, self.unit) == 'HEALER'
    end
    return true
end

-- A druid's own power bar always shows mana; the form bar carries rage or energy.
function Row:UpdatePower(smooth)
    local unit = self.unit
    local shown = powerShown(self)
    self.power.frame:SetShown(shown)
    if not shown then
        if self.formBar then
            self.formBar.frame:Hide()
        end
        return
    end
    if self:IsPlayer() and EUI.Druid.IsDruid() then
        tintPower(self, self.power, MANA)
        self.power:SetRange(UnitPowerMax(unit, MANA))
        local mana = UnitPower(unit, MANA)
        self.power:SetValue(mana, smooth)
        setPowerText(self, mana)
        self:UpdateFormBar(smooth)
        return
    end
    if self.formBar then
        self.formBar.frame:Hide()
    end
    -- Offline: a full bar in the offline grey, as the HP bar.
    if self.state == 'offline' then
        tintPower(self, self.power, OFFLINE)
        self.power:SetRange(1)
        self.power:SetValue(1)
        setPowerText(self, nil)
        return
    end
    tintPower(self, self.power, EUI.Read('UnitPowerType', UnitPowerType, unit))
    self.power:SetRange(UnitPowerMax(unit))
    local power = UnitPower(unit)
    self.power:SetValue(power, smooth)
    setPowerText(self, power)
end

function Row:UpdateFormBar(smooth)
    local shown = self:IsPlayer() and EUI.Druid.IsShifted()
    self.formBar.frame:SetShown(shown)
    if not shown then
        return
    end
    tintPower(self, self.formBar, EUI.Read('UnitPowerType', UnitPowerType, 'player'))
    self.formBar:SetRange(UnitPowerMax('player'))
    local power = UnitPower('player')
    self.formBar:SetValue(power, smooth)
    EUI.SetNumberText(self.formText, power)
end

-- Loot-method APIs: C_PartyInfo.GetLootMethod (Enum.LootMethod) or the older GetLootMethod
-- ('master'). Both return the master looter's party index (0 = player) and raid index.
local function masterLooterGuid()
    local getter = (C_PartyInfo and C_PartyInfo.GetLootMethod) or GetLootMethod
    if not getter then
        return nil
    end
    local ok, method, partyIndex, raidIndex = pcall(getter)
    if not ok then
        EUI.LogOnce('lootMethod:error', 'loot method: %s', tostring(method))
        return nil
    end
    local masterEnum = Enum and Enum.LootMethod and Enum.LootMethod.Masterlooter
    if method ~= 'master' and (masterEnum == nil or method ~= masterEnum) then
        return nil
    end
    local unit
    if raidIndex then
        unit = 'raid' .. raidIndex
    elseif partyIndex == 0 then
        unit = 'player'
    elseif partyIndex then
        unit = 'party' .. partyIndex
    end
    return unit and EUI.SafeValue(UnitGUID, unit)
end

function Row:UpdateGroupRoles()
    local unit = self.unit
    self.indicators:SetAssistant(EUI.Read('UnitIsGroupAssistant', UnitIsGroupAssistant, unit) == true)
    local looter = masterLooterGuid()
    self.indicators:SetMasterLooter(looter ~= nil and looter == EUI.SafeValue(UnitGUID, unit))
end

-- The cost of spellID in the player's current power type, or nil.
local function spellCost(spellID)
    if not (C_Spell and C_Spell.GetSpellPowerCost) or not EUI.CanAccess(spellID) then
        EUI.LogOnce('cost:unavailable', 'cost preview: spell ID secret or GetSpellPowerCost missing')
        return nil
    end
    local powerType = EUI.Read('UnitPowerType', UnitPowerType, 'player')
    local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellID)
    if not ok or type(costs) ~= 'table' then
        return nil
    end
    for _, info in ipairs(costs) do
        local kind, cost = info.type, info.cost
        if EUI.CanAccess(kind) and EUI.CanAccess(cost) and kind == powerType and cost and cost > 0 then
            return cost
        end
    end
    return nil
end

-- Player row only: shade the power the cast in progress will spend, fade it once it lands.
function Row:UpdateCostPreview(event, spellID)
    if not self:IsPlayer() then
        return
    end
    local bar = EUI.Druid.IsShifted() and self.formBar or self.power
    if event == 'UNIT_SPELLCAST_START' then
        bar:SetCost(spellCost(spellID), UnitPowerMax('player'))
    elseif event == 'UNIT_SPELLCAST_SUCCEEDED' then
        bar:CommitCost()
    elseif event == 'UNIT_SPELLCAST_STOP' or event == 'UNIT_SPELLCAST_FAILED' or event == 'UNIT_SPELLCAST_INTERRUPTED' then
        bar:SetCost(nil)
    end
end

function Row:UpdateLeader()
    self.indicators:SetLeader(EUI.SafeBool(UnitIsGroupLeader, self.unit), EUI.Indicators.IsGuideGroup())
end

-- Phased or in another group (a cross-faction or public group), as Blizzard's
-- UpdateNotPresentIcon checks.
local function notPresent(unit, phased)
    return phased or EUI.Read('UnitInOtherParty', UnitInOtherParty, unit) == true
end

function Row:UpdateRange()
    local unit = self.unit
    local range = self.style.range
    self.notPresent = false
    -- The phased icon follows the distance limit, which changes without an event.
    local phased = unit ~= nil and isPhased(self, unit)
    if phased ~= self.phased then
        self.phased = phased
        self:UpdateStatusIcon()
    end
    if self.state == 'offline' then
        self.art:SetAlpha(range.farAlpha)
    elseif not unit or self:IsPlayer() or self.isSelf then
        self.art:SetAlpha(1)
    elseif notPresent(unit, phased) then
        self.notPresent = true
        self.art:SetAlpha(range.notPresentAlpha)
    else
        UnitVisual.ShowRange(self.art, unit, range.farAlpha)
    end
end

function Row:UpdateCursor()
    self.cursor:SetShown(UnitVisual.IsTarget(self.unit))
end
