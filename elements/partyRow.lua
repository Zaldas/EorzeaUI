local _, EUI = ...

-- Visuals for one secure party button. The party list owns the button's unit attribute and
-- the unit watch its visibility; this only draws on it and follows unit changes.

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
    self.lowHealthCurve = EUI.Curves.Step({ style.lowHealth }, '#FFFFFFFF')

    self.power = EUI.Bar.Create(art, style.power.bar, style.power.pos, { cost = style.power.cost })
    self.powerText = Style.Text(self.power.overlay, style.power.txtValue, fonts)
    self.formBar = EUI.Bar.Create(art, style.formBar.bar, style.formBar.pos, { cost = style.power.cost })
    self.formText = Style.Text(self.formBar.overlay, style.formBar.txtValue, fonts)
    self.formBar.frame:Hide()

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
    self.iconFrame = iconFrame

    -- Row-relative text and markers, drawn above both bars.
    local top = CreateFrame('Frame', nil, art)
    top:SetAllPoints(art)
    top:SetFrameLevel(self.power.overlay:GetFrameLevel() + 1)

    self.threat = Style.Image(top, 'OVERLAY', style.threat)
    self.threat:Hide()

    -- Cut off with an ellipsis before the aura icons.
    self.name = Style.Text(top, style.txtName, fonts)
    self.name:SetWidth(style.txtName.width)
    self.name:SetWordWrap(false)

    self.levelBadge = EUI.LevelBadge.Create(iconFrame, iconFrame, style.levelBadge, fonts)
    self.levelBadge.frame:SetFrameLevel(iconFrame:GetFrameLevel() + 2)

    local markers = CreateFrame('Frame', nil, art)
    markers:SetAllPoints(art)
    markers:SetFrameLevel(iconFrame:GetFrameLevel() + 3)
    self.indicators = EUI.Indicators.Create(markers, top, style)

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
    if type(status) ~= 'number' or status < 1 then
        self.threat:Hide()
        return
    end
    local r, g, b = EUI.Indicators.ThreatColor(status)
    self.threat:SetVertexColor(r, g, b, 1)
    self.threat:Show()
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

local STATE_LABELS = {
    dead = DEAD and DEAD:upper() or 'DEAD',
    ghost = GHOST and GHOST:upper() or 'GHOST',
    offline = PLAYER_OFFLINE and PLAYER_OFFLINE:upper() or 'OFFLINE',
}

-- Offline members get a full HP bar in style.hp.offlineColor, as on Blizzard's frames.
local function greyHealth(self, offline)
    if offline == self.greyed then
        return
    end
    self.greyed = offline
    local bar = self.style.hp.bar
    self.hp:SetFillColor(offline and self.style.hp.offlineColor or bar.fill.color)
    self.hp:SetFrameColor(offline and self.style.hp.offlineColor or bar.bg.color)
end

-- state: 'dead' | 'ghost' | 'offline' | nil. Returns true when a label replaced the HP value.
-- maxHealth fills the bar while offline; it may be secret.
local function applyState(self, state, maxHealth)
    -- The health curve recolours the text afterwards; without one it keeps this colour.
    if self.state and not state then
        self.hpText:SetTextColor(Style.Color(self.style.hp.textColor))
    end
    self.state = state
    greyHealth(self, state == 'offline')
    self.classIcon:SetDesaturated(state ~= nil)
    if state then
        self.classIcon:SetVertexColor(1, 1, 1, 1)
    end
    if not state then
        return false
    end
    self.hp:SetValue(state == 'offline' and maxHealth or 0)
    self.hp:SetIncoming(0)
    self.hpText:SetText(STATE_LABELS[state])
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
    self.buffs = EUI.AuraRow.Create(art, initialUnit, 'HELPFUL', style.buffs, fonts)
    self.debuffs = EUI.AuraRow.Create(art, initialUnit, 'HARMFUL', style.debuffs, fonts)

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
    self.buffs = EUI.StaticIcons.Create(self.art, style.buffs, fonts)
    self.debuffs = EUI.StaticIcons.Create(self.art, style.debuffs, fonts)
    self.pet = EUI.PetRow.CreateDemo(host, self, style, fonts)
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
end

-- The height a demo row needs to show member: the base row plus its form and pet sub-rows.
function Row:DemoHeight(member)
    local style = self.style
    return style.rowHeight + (member.form and style.formRowHeight or 0) + (member.pet and style.pet.rowHeight or 0)
end

-- member = { name, class, level, hp, hpMax, incoming, power, powerMax, leader, targeted, far,
--            state, resting, combat, status, raidMarker, tag, role, pvp, cast, threat, powerType,
--            form = { powerType, power, powerMax }, assistant, masterLooter, absorb,
--            buffs, debuffs, pet (see PetRow ShowDemo) }
function Row:ShowDemo(member)
    self.host:SetShown(member ~= nil)
    if not member then
        return
    end
    setClassIcon(self, member.class)
    setName(self, member.name)
    self.levelBadge:Set(member.level)

    self.hp:SetRange(member.hpMax)
    if not applyState(self, member.state, member.hpMax) then
        self.hp:SetValue(member.hp)
        self.hp:SetIncoming(member.incoming or 0, member.hpMax, member.absorb or 0)
        self.hpText:SetText(UnitVisual.FormatNumber(member.hp))
        self.hpText:SetTextColor(Style.Color(UnitVisual.ThresholdColor(self.style.hp, member.hp / member.hpMax)))
        local low = member.hp / member.hpMax < self.style.lowHealth.below
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
    local form = member.form
    self.formBar.frame:SetShown(form ~= nil)
    if form then
        tintPower(self, self.formBar, form.powerType)
        self.formBar:SetRange(form.powerMax)
        self.formBar:SetValue(form.power)
        self.formText:SetText(UnitVisual.FormatNumber(form.power))
    end
    if offline then
        self.powerText:SetText('')
    else
        self.powerText:SetText(UnitVisual.FormatNumber(member.power))
    end

    indicators:SetLeader(member.leader == true)
    indicators:SetAssistant(member.assistant == true)
    indicators:SetMasterLooter(member.masterLooter == true)
    self.cursor:SetShown(member.targeted == true)
    setThreat(self, member.threat)
    self.art:SetAlpha(member.far and self.style.range.farAlpha or 1)

    self.buffs:Set(member.buffs)
    self.debuffs:Set(member.debuffs)

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
    self.buffs:Refresh()
    self.debuffs:Refresh()
end

-- Row 1 is bound to 'player' in party and raid.
function Row:IsPlayer()
    return self.unit == 'player'
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
    self.levelBadge:Set(EUI.SafeValue(UnitLevel, unit))
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
    EUI.SetNumberText(self.hpText, health)
    EUI.Curves.ApplyHealthColor(self.hpText, unit, self.hpCurve)
    EUI.Curves.ApplyHealthTint(self.classIcon, unit, self.lowHealthCurve)
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

-- As Blizzard's group frames: no threat colours while solo.
function Row:UpdateThreat()
    if not IsInGroup() then
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

function Row:UpdateRole()
    self.indicators:SetRole(EUI.Read('UnitGroupRolesAssigned', UnitGroupRolesAssigned, self.unit))
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
    if phase == 'active' then
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

-- One centre icon, by priority: ready check, summon, resurrect, phased.
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
    if not kind and EUI.Read('UnitIsConnected', UnitIsConnected, unit)
        and EUI.Read('UnitPhaseReason', UnitPhaseReason, unit) ~= nil then
        kind = 'phased'
    end
    self.indicators:SetStatus(kind)
end

local MANA = 0

-- A druid's own power bar always shows mana; the form bar carries rage or energy.
function Row:UpdatePower(smooth)
    local unit = self.unit
    if self:IsPlayer() and EUI.Druid.IsDruid() then
        tintPower(self, self.power, MANA)
        self.power:SetRange(UnitPowerMax(unit, MANA))
        local mana = UnitPower(unit, MANA)
        self.power:SetValue(mana, smooth)
        EUI.SetNumberText(self.powerText, mana)
        self:UpdateFormBar(smooth)
        return
    end
    self.formBar.frame:Hide()
    -- Offline: a full bar in the offline grey, as the HP bar.
    if self.state == 'offline' then
        tintPower(self, self.power, OFFLINE)
        self.power:SetRange(1)
        self.power:SetValue(1)
        self.powerText:SetText('')
        return
    end
    tintPower(self, self.power, EUI.Read('UnitPowerType', UnitPowerType, unit))
    self.power:SetRange(UnitPowerMax(unit))
    local power = UnitPower(unit)
    self.power:SetValue(power, smooth)
    EUI.SetNumberText(self.powerText, power)
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
    self.indicators:SetLeader(EUI.SafeBool(UnitIsGroupLeader, self.unit))
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
            EUI.LogOnce('range:error', 'UnitInRange failed: %s', tostring(inRange))
        elseif EUI.CanAccess(inRange) then
            if EUI.CanAccess(checked) and checked then
                showNear(self, inRange == true)
                return
            end
        elseif EUI.CanAccess(checked) and not checked then
            -- Unchecked: the secret result says nothing; fall through to CheckInteractDistance.
        elseif self.art.SetAlphaFromBoolean and showNearSecret(self, inRange) then
            EUI.LogOnce('range:secret', 'range: UnitInRange is secret; dimming via SetAlphaFromBoolean')
            return
        else
            EUI.LogOnce('range:fallback', 'range: UnitInRange is secret and SetAlphaFromBoolean failed; using CheckInteractDistance')
        end
    end
    showNear(self, EUI.SafeValue(CheckInteractDistance, unit, 4) ~= false)
end

-- GUIDs are readable in combat unless unit identity is restricted, unlike UnitIsUnit against
-- compound tokens.
function Row:UpdateCursor()
    local guid = self.unit and EUI.SafeValue(UnitGUID, self.unit)
    local targetGuid = EUI.SafeValue(UnitGUID, 'target')
    self.cursor:SetShown(guid ~= nil and guid == targetGuid)
end
