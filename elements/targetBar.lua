local _, AV = ...

-- Target bar: HP bar with heal prediction, raid marker and name coloured by unit kind and claim,
-- HP% and your threat, a class icon or portrait with the level badge, debuff/buff rows with
-- dispel and stealable borders, the unit's cast bar, and a mini bar for the unit's target.
-- Non-attackable NPCs out of combat get a separator line instead of the HP bar.
-- The drawing is not secure, so it may show/hide in combat. Secure buttons on the anchor take
-- clicks on both bars: left-click targets, right-click opens the unit menu, hover shows the tooltip.
-- Each bar is an instance for one unit ('target' or 'focus'; the unit's target gets the mini
-- bar). Demo bars have no unit and only show SetPreview data.

AV.TargetBar = {}
local TargetBar = AV.TargetBar
local Bar = {}
Bar.__index = Bar

-- Live bars by unit.
local bars = {}

local Style = AV.Style
local CLASS_ICONS = 'Interface\\TargetingFrame\\UI-Classes-Circles'
-- Class icons and portraits are drawn as circles; cropping to the inscribed square fills the
-- job frame.
local CIRCLE_INSET = 0.146
local NPC_GRADIENT = '#808080FF'

local function createSeparator(parent, spec)
    local frame = CreateFrame('Frame', nil, parent)
    frame:SetSize(spec.width, spec.height)
    Style.Place(frame, parent, spec.pos)
    local half = spec.width / 2
    local left = frame:CreateTexture(nil, 'ARTWORK')
    left:SetColorTexture(1, 1, 1, 1)
    left:SetSize(half, spec.height)
    left:SetPoint('TOPLEFT', frame, 'TOPLEFT', 0, 0)
    local right = frame:CreateTexture(nil, 'ARTWORK')
    right:SetColorTexture(1, 1, 1, 1)
    right:SetSize(half, spec.height)
    right:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', 0, 0)
    frame.left, frame.right = left, right
    frame:Hide()
    return frame
end

-- SetGradient sets vertex colours, so the colour goes into the gradient itself.
local function colorSeparator(separator, hex, spec)
    local r, g, b = Style.Color(hex)
    local alpha = spec.alpha
    local edge, centre = CreateColor(r, g, b, 0), CreateColor(r, g, b, alpha)
    local ok = pcall(separator.left.SetGradient, separator.left, 'HORIZONTAL', CreateColor(r, g, b, spec.leftAlpha), centre)
        and pcall(separator.right.SetGradient, separator.right, 'HORIZONTAL', centre, edge)
    if not ok then
        separator.left:SetVertexColor(r, g, b, alpha)
        separator.right:SetVertexColor(r, g, b, alpha)
    end
end

local function createIcon(self, parent, spec, fonts, frameLevel)
    local iconSpec = spec.icon
    local size = iconSpec.size
    local frame = CreateFrame('Frame', nil, parent)
    frame:SetSize(size, size)
    Style.Place(frame, parent, iconSpec.pos)
    frame:SetFrameLevel(frameLevel)
    local full = { 0, 0 }
    Style.Image(frame, 'BACKGROUND', { path = iconSpec.bg, pos = full, size = { size, size } })
    self.iconGradient = Style.Image(frame, 'BORDER', { path = iconSpec.gradient, pos = full, size = { size, size } })
    local portrait = frame:CreateTexture(nil, 'ARTWORK')
    portrait:SetPoint('TOPLEFT', iconSpec.inset, -iconSpec.inset)
    portrait:SetPoint('BOTTOMRIGHT', -iconSpec.inset, iconSpec.inset)
    self.portrait = portrait
    Style.Image(frame, 'OVERLAY', { path = iconSpec.frame, pos = full, size = { size, size } })
    self.levelBadge = AV.LevelBadge.Create(frame, frame, spec.levelBadge, fonts)
    self.levelBadge.frame:SetFrameLevel(frameLevel + 2)
    self.icon = frame

    local markers = CreateFrame('Frame', nil, parent)
    markers:SetAllPoints(parent)
    markers:SetFrameLevel(frameLevel + 3)
    self.pvp = markers:CreateTexture(nil, 'OVERLAY')
    self.pvp:SetSize(spec.pvp.size[1], spec.pvp.size[2])
    Style.Place(self.pvp, markers, spec.pvp.pos)
    self.pvp:Hide()
    self.tier = markers:CreateTexture(nil, 'OVERLAY')
    self.tier:SetSize(spec.tier.size, spec.tier.size)
    Style.Place(self.tier, markers, spec.tier.pos)
    self.tier:Hide()
    self.threat = Style.Image(markers, 'OVERLAY', spec.threat)
    self.threat:Hide()
    self.leader = markers:CreateTexture(nil, 'OVERLAY')
    self.leader:SetSize(spec.leader.size[1], spec.leader.size[2])
    Style.Place(self.leader, markers, spec.leader.pos)
    AV.Indicators.SetLeaderArt(self.leader)
    self.leader:Hide()
end

-- Secure unit buttons on the anchor, never on content: content shows and hides in combat, which
-- a frame with protected children cannot. The unit watch shows each one while its unit exists.
local function createClickArea(self, unit, rect, origin)
    local anchor = self.anchor
    local button = CreateFrame('Button', nil, anchor, 'SecureUnitButtonTemplate')
    button:SetSize(rect.size[1], rect.size[2])
    Style.Place(button, anchor, { origin[1] + rect.pos[1], origin[2] + rect.pos[2] })
    button:RegisterForClicks('AnyUp')
    button:SetAttribute('unit', unit)
    button:SetAttribute('type1', 'target')
    button:SetAttribute('type2', 'togglemenu')
    button:HookScript('OnEnter', function()
        if UnitExists(unit) then
            GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
            GameTooltip:SetUnit(unit)
            GameTooltip:Show()
        end
    end)
    button:HookScript('OnLeave', function()
        GameTooltip:Hide()
    end)
    if RegisterUnitWatch then
        RegisterUnitWatch(button)
    end
    return button
end

-- Builds a bar on anchor, sized spec.width x spec.height by the caller. unit (e.g. 'target')
-- makes it live: aura containers and secure click areas for unit and its target, and events for
-- unit reach it through TargetBar.ForUnit. Live bars are built out of combat. Without a unit the
-- bar is a demo that shows SetPreview data only, from plain frames.
function TargetBar.New(anchor, spec, fonts, unit)
    local self = setmetatable({ anchor = anchor, spec = spec, fonts = fonts, unit = unit }, Bar)
    self.totUnit = unit and unit .. 'target'

    local content = CreateFrame('Frame', nil, anchor)
    content:SetAllPoints(anchor)
    self.content = content

    self.bar = AV.Bar.Create(content, spec.bar, { 0, 0 }, { prediction = spec.healPrediction })
    -- Text lives above the bar rather than on it, so the bar can hide for NPCs. The bar sits
    -- at the content's origin, so both share coordinates.
    local top = CreateFrame('Frame', nil, content)
    top:SetAllPoints(content)
    top:SetFrameLevel(self.bar.overlay:GetFrameLevel() + 1)
    self.name = Style.Text(top, spec.txtName, fonts)
    self.marker = top:CreateTexture(nil, 'OVERLAY')
    self.marker:SetSize(spec.raidMarker.size[1], spec.raidMarker.size[2])
    Style.Place(self.marker, top, spec.raidMarker.pos)
    self.marker:Hide()
    self.flag = top:CreateTexture(nil, 'OVERLAY')
    self.flag:SetSize(spec.flag.size[1], spec.flag.size[2])
    self.flag:Hide()
    self.hpp =Style.Text(top, spec.txtHpp, fonts)
    self.threatText = Style.Text(top, spec.txtThreat, fonts)
    self.separator = createSeparator(top, spec.separator)
    createIcon(self, content, spec, fonts, top:GetFrameLevel() + 1)
    self.lowHealthCurve = AV.Curves.Step({ spec.lowHealth }, '#FFFFFFFF')

    if unit then
        self.auras = AV.AuraRow.Create(content, unit, { 'HARMFUL', 'HELPFUL' }, spec.auras, fonts)
    end

    self.cast = AV.CastBar.Create(content, unit, spec.cast, fonts, spec.cast.pos)
    if spec.cast.hidesName then
        -- Alpha, not Hide, so marker and flag updates mid-cast stick.
        self.cast.onVisibility = function(casting)
            local alpha = casting and 0 or 1
            self.name:SetAlpha(alpha)
            self.marker:SetAlpha(alpha)
            self.flag:SetAlpha(alpha)
        end
    end

    if spec.header then
        Style.Header(content, spec.header, fonts)
    end

    self.attention = Style.Image(content, 'ARTWORK', spec.attention)
    local tot = CreateFrame('Frame', nil, content)
    tot:SetSize(spec.tot.bar.width, spec.tot.bar.height)
    Style.Place(tot, content, spec.tot.pos)
    self.tot = tot
    self.totBar = AV.Bar.Create(tot, spec.tot.bar, { 0, 0 })
    self.totName = Style.Text(self.totBar.overlay, spec.tot.txtName, fonts)
    self.totMarker = self.totBar.overlay:CreateTexture(nil, 'OVERLAY')
    self.totMarker:SetSize(spec.tot.raidMarker.size[1], spec.tot.raidMarker.size[2])
    Style.Place(self.totMarker, self.totBar.overlay, spec.tot.raidMarker.pos)
    self.totMarker:Hide()

    if unit then
        self.clickUnit = createClickArea(self, unit, spec.click, { 0, 0 })
        self.clickTot = createClickArea(self, self.totUnit, spec.tot.click, spec.tot.pos)
        bars[unit] = self
        self:Refresh()
    else
        self.tot:Hide()
        self.attention:Hide()
    end
    return self
end

-- The live target and focus bars, each on its own movable anchor.
local function createLive(anchorName, spec, fonts, unit)
    local anchor = CreateFrame('Frame', anchorName, UIParent)
    anchor:SetSize(spec.width, spec.height)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    return TargetBar.New(anchor, spec, fonts, unit)
end

function TargetBar.Create(style, fonts)
    TargetBar.target = createLive('AzerothVistaTargetAnchor', style.target, fonts, 'target')
    TargetBar.focus = createLive('AzerothVistaFocusAnchor', style.focus, fonts, 'focus')
end

-- A demo bar in parent, on its own anchor sized to spec. Show data with bar:SetPreview.
function TargetBar.CreateDemo(parent, spec, fonts)
    local anchor = CreateFrame('Frame', nil, parent)
    anchor:SetSize(spec.width, spec.height)
    return TargetBar.New(anchor, spec, fonts)
end

-- The live bar showing unit, or nil.
function TargetBar.ForUnit(unit)
    return bars[unit]
end

function TargetBar.ForEach(fn)
    for _, bar in pairs(bars) do
        fn(bar)
    end
end

-- True while the bar follows its live unit and the unit exists.
local function isLive(self)
    return not self.preview and self.unit ~= nil and UnitExists(self.unit)
end

-- Shows raid marker index, then the optional AFK/DND flag, before text, shifting the text right
-- while they show.
local function setMarkedName(text, textSpec, marker, markerSpec, index, flag, flagSpec, flagKind)
    local shift = AV.Indicators.SetRaidMarkerIcon(marker, index) and (markerSpec.size[1] + 3) or 0
    if flag and AV.Indicators.SetFlagIcon(flag, flagKind) then
        Style.Place(flag, marker:GetParent(), { flagSpec.pos[1] + shift, flagSpec.pos[2] })
        shift = shift + flagSpec.size[1] + 3
    end
    text:ClearAllPoints()
    text:SetPoint('TOPLEFT', marker:GetParent(), 'TOPLEFT', textSpec.pos[1] + shift, -textSpec.pos[2])
end

function Bar:UpdateRaidMarker()
    if not isLive(self) then
        return
    end
    local spec = self.spec
    setMarkedName(self.name, spec.txtName, self.marker, spec.raidMarker, AV.Indicators.ReadRaidMarker(self.unit),
        self.flag, spec.flag, self.flagKind)
end

-- AFK/DND flag; players only.
function Bar:UpdateFlags()
    if not isLive(self) then
        return
    end
    local unit = self.unit
    local kind
    if AV.Read('UnitIsPlayer', UnitIsPlayer, unit) then
        if AV.Read('UnitIsAFK', UnitIsAFK, unit) then
            kind = 'AFK'
        elseif AV.Read('UnitIsDND', UnitIsDND, unit) then
            kind = 'DND'
        end
    end
    self.flagKind = kind
    self:UpdateRaidMarker()
end

local function inGroup(unit)
    return AV.Read('UnitInParty', UnitInParty, unit) == true or AV.Read('UnitInRaid', UnitInRaid, unit) ~= nil
end

-- Returns the spec.nameColors key for unit.
local function nameColorKey(unit)
    local canAttack = AV.Read('UnitCanAttack', UnitCanAttack, 'player', unit) == true
    if AV.Read('UnitIsPlayer', UnitIsPlayer, unit) then
        if AV.Read('UnitIsUnit', UnitIsUnit, unit, 'player') or inGroup(unit) then
            return 'party'
        end
        return canAttack and 'hostilePlayer' or 'player'
    end
    if AV.Read('UnitPlayerControlled', UnitPlayerControlled, unit) then
        if canAttack then
            return 'hostilePlayer'
        end
        return AV.Read('UnitIsUnit', UnitIsUnit, unit, 'pet') and 'party' or 'player'
    end
    if not canAttack then
        return 'npc'
    end
    if AV.Read('UnitIsTapDenied', UnitIsTapDenied, unit) then
        return 'otherClaim'
    end
    if AV.Read('UnitAffectingCombat', UnitAffectingCombat, unit) then
        return 'claimed'
    end
    return 'unclaimed'
end

-- nameColorKey results for units you can attack; only these get a difficulty-coloured level.
local ATTACKABLE = { unclaimed = true, claimed = true, otherClaim = true, hostilePlayer = true }

local function setNpcMode(self, npc)
    if self.npcMode == npc then
        return
    end
    self.npcMode = npc
    self.bar.frame:SetShown(not npc)
    self.hpp:SetShown(not npc)
    self.separator:SetShown(npc)
end

local function applyNameColor(self, key)
    local hex = self.spec.nameColors[key]
    self.name:SetTextColor(Style.Color(hex))
    colorSeparator(self.separator, hex, self.spec.separator)
end

-- kind: 'FFA' | 'Alliance' | 'Horde' | nil
local function setPvP(self, kind)
    if kind == self.pvpKind then
        return
    end
    self.pvpKind = kind
    if kind then
        AV.Indicators.SetPvPIcon(self.pvp, kind)
    end
    self.pvp:SetShown(kind ~= nil)
end

local function readPvP(unit)
    if AV.Read('UnitIsPVPFreeForAll', UnitIsPVPFreeForAll, unit) then
        return 'FFA'
    elseif AV.Read('UnitIsPVP', UnitIsPVP, unit) then
        return AV.Read('UnitFactionGroup', UnitFactionGroup, unit)
    end
    return nil
end

-- r, g, b for a level, or nil. unit (optional) uses the client's content difficulty.
local function difficultyColor(unit, level)
    if level <= 0 then
        local skull = QuestDifficultyColors and QuestDifficultyColors.impossible
        if skull then
            return skull.r, skull.g, skull.b
        end
        return 1, 0.1, 0.1
    end
    local color
    if unit and C_PlayerInfo and C_PlayerInfo.GetContentDifficultyCreatureForPlayer and GetDifficultyColor then
        local difficulty = AV.Read('GetContentDifficultyCreatureForPlayer', C_PlayerInfo.GetContentDifficultyCreatureForPlayer, unit)
        color = difficulty and AV.Read('GetDifficultyColor', GetDifficultyColor, difficulty)
    end
    if not color and GetCreatureDifficultyColor then
        color = AV.Read('GetCreatureDifficultyColor', GetCreatureDifficultyColor, level)
    end
    if color then
        return color.r, color.g, color.b
    end
    return nil
end

local function setLevel(self, level, r, g, b)
    self.levelBadge:Set(level)
    self.levelBadge:SetColor(r, g, b)
end

local function cropCircle(texture, left, right, top, bottom)
    local dx, dy = (right - left) * CIRCLE_INSET, (bottom - top) * CIRCLE_INSET
    texture:SetTexCoord(left + dx, right - dx, top + dy, bottom - dy)
end

-- The class icon when classToken has one; otherwise drawPortrait(texture) fills the frame.
local function setIcon(self, classToken, drawPortrait)
    local portrait = self.portrait
    local coords = classToken and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classToken]
    local color = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    if coords then
        portrait:SetTexture(CLASS_ICONS)
        cropCircle(portrait, unpack(coords))
    else
        drawPortrait(portrait)
        cropCircle(portrait, 0, 1, 0, 1)
    end
    if color then
        self.iconGradient:SetVertexColor(color.r, color.g, color.b, 1)
    else
        self.iconGradient:SetVertexColor(Style.Color(NPC_GRADIENT))
    end
end

local function setTier(self, classification)
    local path = classification and self.spec.tier.paths[classification]
    if path then
        self.tier:SetTexture(Style.AssetPath(path))
    end
    self.tier:SetShown(path ~= nil)
end

-- Class icon for players, the engine-rendered portrait for everything else.
function Bar:UpdateIcon()
    if not isLive(self) then
        return
    end
    local unit = self.unit
    local classToken = AV.Read('UnitIsPlayer', UnitIsPlayer, unit) == true
        and AV.Read('UnitClass', function() return select(2, UnitClass(unit)) end)
    setIcon(self, classToken, function(texture)
        AV.Read('SetPortraitTexture', SetPortraitTexture, texture, unit)
    end)
end

-- Returns a plain number, or nil when the value is missing or secret.
local function plainNumber(value)
    if type(value) == 'number' and AV.CanAccess(value) then
        return value
    end
    return nil
end

-- Your threat on the unit, as Blizzard's target frame shows it: the diamond while you have
-- aggro or are about to, the percent whenever you have any threat. The main ticker calls this.
function Bar:UpdateThreat()
    if self.preview or not self.unit then
        return
    end
    local unit = self.unit
    local status, display, detailed
    if UnitExists(unit) and not AV.Read('UnitIsDeadOrGhost', UnitIsDeadOrGhost, unit) then
        status = plainNumber(AV.Read('UnitThreatSituation', UnitThreatSituation, 'player', unit))
        local ok, isTanking, detailedStatus, _, rawPercent = pcall(UnitDetailedThreatSituation, 'player', unit)
        if ok then
            detailed = plainNumber(detailedStatus)
            display = plainNumber(rawPercent)
            if isTanking == true then
                display = plainNumber(AV.Read('UnitThreatPercentageOfLead', UnitThreatPercentageOfLead, 'player', unit))
            end
        end
    end
    if status and status > 0 then
        self.threat:SetVertexColor(AV.Indicators.ThreatColor(status))
        self.threat:Show()
    else
        self.threat:Hide()
    end
    if display and display > 0 then
        self.threatText:SetFormattedText('%.0f%%', display)
        if detailed and detailed > 0 then
            self.threatText:SetTextColor(AV.Indicators.ThreatColor(detailed))
        else
            self.threatText:SetTextColor(Style.Color(self.spec.txtThreat.color))
        end
        self.threatText:Show()
    else
        self.threatText:Hide()
    end
end

-- Name colour, NPC mode, PvP badge and leader crown; claim and combat state change without a dedicated
-- event, so the main ticker calls this too.
function Bar:UpdateIdentity()
    if not isLive(self) then
        return
    end
    local unit = self.unit
    local key = nameColorKey(unit)
    if key ~= self.colorKey then
        self.colorKey = key
        applyNameColor(self, key)
    end
    -- An NPC in combat (escorts, guards) shows its HP.
    setNpcMode(self, key == 'npc' and not AV.Read('UnitAffectingCombat', UnitAffectingCombat, unit))
    setPvP(self, readPvP(unit))
    -- UnitLeadsAnyGroup also covers players outside your group.
    local leads
    if UnitLeadsAnyGroup then
        leads = AV.Read('UnitLeadsAnyGroup', UnitLeadsAnyGroup, unit)
    else
        leads = AV.Read('UnitIsGroupLeader', UnitIsGroupLeader, unit)
    end
    self.leader:SetShown(leads == true)
end

function Bar:Refresh()
    if self.preview or not self.unit then
        return
    end
    local unit = self.unit
    if not UnitExists(unit) then
        self.content:Hide()
        return
    end
    self.content:Show()

    pcall(self.name.SetText, self.name, AV.UnitDisplayName(unit))
    self.colorKey = nil
    self:UpdateIdentity()
    self:UpdateIcon()
    self:UpdateFlags()
    setTier(self, AV.Read('UnitClassification', UnitClassification, unit))
    local level = AV.SafeValue(UnitLevel, unit)
    if level and AV.Read('UnitCanAttack', UnitCanAttack, 'player', unit) then
        setLevel(self, level, difficultyColor(unit, level))
    else
        setLevel(self, level)
    end
    self:UpdateHealth(false)
    self:UpdateThreat()
    self.auras:Refresh()
    self.cast:EndFailure()
    self.cast:Update()
    self:UpdateTargetOfTarget()
end

function Bar:UpdateHealth(smooth)
    if not isLive(self) then
        return
    end
    local unit = self.unit
    local maxHealth = UnitHealthMax(unit)
    self.bar:SetRange(maxHealth)
    self.bar:SetValue(UnitHealth(unit), smooth)
    self.bar:ShowIncomingHeals(unit, maxHealth)
    AV.Curves.SetHealthPercentText(self.hpp, unit)
    local dead = AV.Read('UnitIsDeadOrGhost', UnitIsDeadOrGhost, unit) == true
    self.portrait:SetDesaturated(dead)
    if dead then
        self.portrait:SetVertexColor(1, 1, 1, 1)
    else
        AV.Curves.ApplyHealthTint(self.portrait, unit, self.lowHealthCurve)
    end
end

function Bar:UpdateHealPrediction()
    if not isLive(self) then
        return
    end
    self.bar:ShowIncomingHeals(self.unit, UnitHealthMax(self.unit))
end

-- The unit's target fires no UNIT_HEALTH events; the main ticker calls this.
function Bar:UpdateTargetOfTarget()
    if self.preview or not self.unit then
        return
    end
    local totUnit = self.totUnit
    local exists = UnitExists(self.unit) and UnitExists(totUnit)
    self.tot:SetShown(exists)
    self.attention:SetShown(exists)
    if not exists then
        return
    end
    self.totBar:SetRange(UnitHealthMax(totUnit))
    self.totBar:SetValue(UnitHealth(totUnit), true)
    pcall(self.totName.SetText, self.totName, AV.UnitDisplayName(totUnit))
    self.totName:SetTextColor(Style.Color(self.spec.nameColors[nameColorKey(totUnit)]))
    setMarkedName(self.totName, self.spec.tot.txtName, self.totMarker, self.spec.tot.raidMarker,
        AV.Indicators.ReadRaidMarker(totUnit))
end

local function setLiveAurasShown(self, shown)
    if self.auras and self.auras.container then
        self.auras.container:SetShown(shown)
    end
end

-- Demo debuffs then buffs, each capped at its group's max as the live row is and tagged with its
-- group's filter for the dispel edge.
local function demoAuras(spec, debuffs, buffs)
    local out = {}
    for _, group in ipairs({ { 'HARMFUL', debuffs }, { 'HELPFUL', buffs } }) do
        local max = AV.AuraRow.GroupSpec(spec, group[1]).max
        for i, entry in ipairs(group[2] or {}) do
            if i > max then
                break
            end
            out[#out + 1] = { entry[1], entry[2], dispel = entry.dispel, stealable = entry.stealable, group = group[1] }
        end
    end
    return out
end

-- Demo and Edit Mode: fixed sample data in place of the unit, or nil to restore live updates.
-- data = { name, level, classification, colorKey, npc, pvp, leader, raidMarker, tag, threat,
--          threatPercent, class | portrait | portraitUnit, hpPercent, dead, incoming, debuffs,
--          buffs, castName, castProgress, castNotInterruptible, totName, totColorKey, totPercent }
-- npc: the separator line replaces the HP bar. class: a class token's icon; portrait: a texture
-- path; portraitUnit: that unit's portrait. threat and totName are optional; nil hides them.
function Bar:SetPreview(data)
    self.preview = data ~= nil
    if not data then
        if self.demoAuras then
            self.demoAuras:Set(nil)
        end
        setLiveAurasShown(self, true)
        self.cast:SetPreview(nil)
        self:Refresh()
        return
    end
    local spec = self.spec
    if not self.demoAuras then
        self.demoAuras = AV.StaticIcons.Create(self.content, spec.auras, self.fonts)
    end
    setLiveAurasShown(self, false)
    self.content:Show()
    self.name:SetText(data.name)
    setMarkedName(self.name, spec.txtName, self.marker, spec.raidMarker, data.raidMarker, self.flag, spec.flag, data.tag)
    applyNameColor(self, data.colorKey)
    self.colorKey = nil
    setNpcMode(self, data.npc == true)
    setPvP(self, data.pvp)
    self.leader:SetShown(data.leader == true)
    setTier(self, data.classification)
    self.hpp:SetText(string.format('%d%%', data.hpPercent))
    self.threat:SetShown(data.threat ~= nil)
    self.threatText:SetShown(data.threat ~= nil)
    if data.threat then
        self.threat:SetVertexColor(AV.Indicators.ThreatColor(data.threat))
        self.threatText:SetFormattedText('%.0f%%', data.threatPercent)
        self.threatText:SetTextColor(AV.Indicators.ThreatColor(data.threat))
    end
    setIcon(self, data.class, function(texture)
        if data.portrait then
            texture:SetTexture(data.portrait)
        else
            AV.Read('SetPortraitTexture', SetPortraitTexture, texture, data.portraitUnit)
        end
    end)
    self.portrait:SetDesaturated(data.dead == true)
    local low = not data.dead and data.hpPercent < spec.lowHealth.below * 100
    self.portrait:SetVertexColor(Style.Color(low and spec.lowHealth.color or '#FFFFFFFF'))
    if ATTACKABLE[data.colorKey] then
        setLevel(self, data.level, difficultyColor(nil, data.level))
    else
        setLevel(self, data.level)
    end
    self.bar:SetRange(100)
    self.bar:SetValue(data.hpPercent)
    self.bar:SetIncoming(data.incoming or 0, 100)
    self.demoAuras:Set(demoAuras(spec.auras, data.debuffs, data.buffs))
    local hasTot = data.totName ~= nil
    self.tot:SetShown(hasTot)
    self.attention:SetShown(hasTot)
    if hasTot then
        self.totBar:SetRange(100)
        self.totBar:SetValue(data.totPercent)
        self.totName:SetText(data.totName)
        setMarkedName(self.totName, spec.tot.txtName, self.totMarker, spec.tot.raidMarker, nil)
        self.totName:SetTextColor(Style.Color(spec.nameColors[data.totColorKey]))
    end
    self.cast:SetPreview(data.castName, data.castProgress, data.castNotInterruptible)
end
