local _, EUI = ...

-- Target bar: HP bar with heal prediction, raid marker and name coloured by reaction, HP% and
-- your threat, a class icon or portrait with the level badge, your combo points, debuff/buff
-- rows with dispel and stealable borders, the unit's cast bar, and a mini bar for its target.
-- Non-attackable NPCs out of combat get a separator line instead of the HP bar.
-- The drawing is not secure, so it may show/hide in combat. Secure buttons on the anchor take
-- clicks on both bars: left-click targets, right-click opens the unit menu, hover shows the tooltip.
-- Each bar is an instance for one unit ('target' or 'focus'; the unit's target gets the mini
-- bar). Demo bars have no unit and only show SetPreview data.

EUI.TargetBar = {}
local TargetBar = EUI.TargetBar
local TargetBarClass = {}
TargetBarClass.__index = TargetBarClass

-- Live bars by unit.
local bars = {}

local Style = EUI.Style
local UnitVisual = EUI.UnitVisual
local UnitInfo = EUI.UnitInfo
local CLASS_ICONS = 'Interface\\TargetingFrame\\UI-Classes-Circles'
local NPC_GRADIENT = '#808080FF'

local function createIcon(self, parent, spec, fonts, frameLevel)
    local iconSpec = spec.icon
    local frame
    frame, self.iconGradient, self.portrait = UnitVisual.JobFrame(parent, iconSpec.pos, iconSpec.size, iconSpec.inset, iconSpec)
    frame:SetFrameLevel(frameLevel)
    self.levelBadge = EUI.LevelBadge.Create(frame, frame, spec.levelBadge, fonts)
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
    EUI.Indicators.SetLeaderArt(self.leader)
    self.leader:Hide()
    if spec.comboPoints then
        self.combo = EUI.ComboPoints.Create(markers, spec.comboPoints)
    end
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
    EUI.AttachUnitTooltip(button, function() return unit end)
    if RegisterUnitWatch then
        RegisterUnitWatch(button)
    end
end

-- Builds a bar on anchor, sized spec.width x spec.height by the caller. unit (e.g. 'target')
-- makes it live: aura containers and secure click areas for unit and its target, and events for
-- unit reach it through TargetBar.ForUnit. Live bars are built out of combat. Without a unit the
-- bar is a demo that shows SetPreview data only, from plain frames.
function TargetBar.New(anchor, spec, fonts, unit)
    local self = setmetatable({ anchor = anchor, spec = spec, fonts = fonts, unit = unit }, TargetBarClass)
    self.totUnit = unit and unit .. 'target'

    local content = CreateFrame('Frame', nil, anchor)
    content:SetAllPoints(anchor)
    self.content = content
    -- Created before the bar, at the content's level, so it draws behind the bar art.
    if spec.nameBg then
        self.nameBg = Style.Fade(content, spec.nameBg)
        self.nameBg:SetFrameLevel(content:GetFrameLevel())
        self.nameBg:Show()
    end

    self.bar = EUI.Bar.Create(content, spec.bar, { 0, 0 }, { prediction = spec.healPrediction })
    -- Text sits on its own layer above the bar, which hides for NPCs. The bar sits at the
    -- content's origin, so both share coordinates.
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
    self.hpp = Style.Text(top, spec.txtHpp, fonts)
    self.threatText = Style.Text(top, spec.txtThreat, fonts)
    -- A child frame draws over its parent's regions; one level below keeps the name over the line.
    self.separator = Style.Fade(top, spec.separator)
    self.separator:SetFrameLevel(top:GetFrameLevel() - 1)
    createIcon(self, content, spec, fonts, top:GetFrameLevel() + 1)
    self.lowHealthCurve = EUI.Curves.Step({ spec.lowHealth }, '#FFFFFFFF')

    if unit then
        self.auras = EUI.AuraRow.Create(content, unit, { 'HARMFUL', 'HELPFUL' }, spec.auras, fonts)
    end

    self.cast = EUI.CastBar.Create(content, unit, spec.cast, fonts, spec.cast.pos)
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
    self.totBar = EUI.Bar.Create(tot, spec.tot.bar, { 0, 0 })
    self.totName = Style.Text(self.totBar.overlay, spec.tot.txtName, fonts)
    self.totMarker = self.totBar.overlay:CreateTexture(nil, 'OVERLAY')
    self.totMarker:SetSize(spec.tot.raidMarker.size[1], spec.tot.raidMarker.size[2])
    Style.Place(self.totMarker, self.totBar.overlay, spec.tot.raidMarker.pos)
    self.totMarker:Hide()

    if unit then
        createClickArea(self, unit, spec.click, { 0, 0 })
        createClickArea(self, self.totUnit, spec.tot.click, spec.tot.pos)
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
    TargetBar.target = createLive('EorzeaUITargetAnchor', style.target, fonts, 'target')
    TargetBar.focus = createLive('EorzeaUIFocusAnchor', style.focus, fonts, 'focus')
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
-- while they show. textSpec.right truncates the text at that x. Returns the shift.
local function setMarkedName(text, textSpec, marker, markerSpec, index, flag, flagSpec, flagKind)
    EUI.Indicators.SetRaidMarkerIcon(marker, index)
    if flag then
        EUI.Indicators.SetFlagIcon(flag, flagKind)
    end
    local shift = UnitVisual.NameLineShift(marker:GetParent(), marker, markerSpec, flag, flagSpec)
    text:ClearAllPoints()
    text:SetPoint('TOPLEFT', marker:GetParent(), 'TOPLEFT', textSpec.pos[1] + shift, -textSpec.pos[2])
    if textSpec.right then
        text:SetWidth(textSpec.right - textSpec.pos[1] - shift)
        text:SetWordWrap(false)
    end
    return shift
end

-- The fade peaks where the name starts and falls to 0 at spec.nameBg.pad past its end, over at
-- least spec.nameBg.fadeMin.
local function fitNameBg(self)
    local fade = self.nameBg
    if not fade then
        return
    end
    local textSpec, bgSpec = self.spec.txtName, self.spec.nameBg
    local left = textSpec.pos[1] + (self.nameShift or 0)
    local limit = textSpec.right - left
    local width = self.name:GetStringWidth()
    if type(width) ~= 'number' or not EUI.CanAccess(width) or width > limit then
        width = limit
    end
    local total = left + width + bgSpec.pad - bgSpec.pos[1]
    local peak = math.max(1, math.min(left - bgSpec.pos[1], total - bgSpec.fadeMin))
    Style.SetFadeWidth(fade, total, peak)
end

function TargetBarClass:UpdateRaidMarker()
    if not isLive(self) then
        return
    end
    local spec = self.spec
    self.nameShift = setMarkedName(self.name, spec.txtName, self.marker, spec.raidMarker,
        EUI.Indicators.ReadRaidMarker(self.unit), self.flag, spec.flag, self.flagKind)
    fitNameBg(self)
end

-- AFK/DND flag; players only.
function TargetBarClass:UpdateFlags()
    if not isLive(self) then
        return
    end
    local unit = self.unit
    local kind
    if EUI.Read('UnitIsPlayer', UnitIsPlayer, unit) then
        if EUI.Read('UnitIsAFK', UnitIsAFK, unit) then
            kind = 'AFK'
        elseif EUI.Read('UnitIsDND', UnitIsDND, unit) then
            kind = 'DND'
        end
    end
    self.flagKind = kind
    self:UpdateRaidMarker()
end

local function nameHex(spec, key)
    return spec.nameColor or spec.reactionColors[key]
end

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
    local spec = self.spec
    local reaction = spec.reactionColors[key]
    self.name:SetTextColor(Style.Color(nameHex(spec, key)))
    Style.ColorFade(self.separator, reaction, spec.separator)
    if self.nameBg then
        Style.ColorFade(self.nameBg, spec.nameBg.color or reaction, spec.nameBg)
    end
end

-- kind: 'FFA' | 'Alliance' | 'Horde' | nil
local function setPvP(self, kind)
    if kind == self.pvpKind then
        return
    end
    self.pvpKind = kind
    if kind then
        EUI.Indicators.SetPvPIcon(self.pvp, kind)
    end
    self.pvp:SetShown(kind ~= nil)
end

local function setLevel(self, level, r, g, b)
    self.levelBadge:Set(level)
    self.levelBadge:SetColor(r, g, b)
end

-- The class icon when classToken has one; otherwise drawPortrait(texture) fills the frame.
local function setIcon(self, classToken, drawPortrait)
    local portrait = self.portrait
    local coords = classToken and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classToken]
    local color = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    if coords then
        portrait:SetTexture(CLASS_ICONS)
        UnitVisual.CropCircle(portrait, unpack(coords))
    else
        drawPortrait(portrait)
        UnitVisual.CropCircle(portrait)
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
function TargetBarClass:UpdateIcon()
    if not isLive(self) then
        return
    end
    local unit = self.unit
    local classToken = EUI.Read('UnitIsPlayer', UnitIsPlayer, unit) == true
        and EUI.Read('UnitClass', function() return select(2, UnitClass(unit)) end)
    setIcon(self, classToken, function(texture)
        EUI.Read('SetPortraitTexture', SetPortraitTexture, texture, unit)
    end)
end

-- Returns a plain number, or nil when the value is missing or secret.
local function plainNumber(value)
    if type(value) == 'number' and EUI.CanAccess(value) then
        return value
    end
    return nil
end

-- Your threat on the unit, as Blizzard's target frame shows it: the diamond while you have
-- aggro or are about to, the percent whenever you have any threat. The main ticker calls this.
function TargetBarClass:UpdateThreat()
    if self.preview or not self.unit then
        return
    end
    local unit = self.unit
    local status, display, detailed
    if UnitExists(unit) and not EUI.Read('UnitIsDeadOrGhost', UnitIsDeadOrGhost, unit) then
        status = plainNumber(EUI.Read('UnitThreatSituation', UnitThreatSituation, 'player', unit))
        local ok, isTanking, detailedStatus, _, rawPercent = pcall(UnitDetailedThreatSituation, 'player', unit)
        if not ok then
            EUI.LogOnce('threat:detailed', 'UnitDetailedThreatSituation failed: %s', tostring(isTanking))
        else
            detailed = plainNumber(detailedStatus)
            display = plainNumber(rawPercent)
            if EUI.CanAccess(isTanking) and isTanking == true then
                display = plainNumber(EUI.Read('UnitThreatPercentageOfLead', UnitThreatPercentageOfLead, 'player', unit))
            end
        end
    end
    if status and status > 0 then
        self.threat:SetVertexColor(EUI.Indicators.ThreatColor(status))
        self.threat:Show()
    else
        self.threat:Hide()
    end
    if display and display > 0 then
        self.threatText:SetFormattedText('%.0f%%', display)
        if detailed and detailed > 0 then
            self.threatText:SetTextColor(EUI.Indicators.ThreatColor(detailed))
        else
            self.threatText:SetTextColor(Style.Color(self.spec.txtThreat.color))
        end
        self.threatText:Show()
    else
        self.threatText:Hide()
    end
end

local ENERGY = 3

-- Rogues, and druids while on energy (cat form).
local function usesComboPoints()
    local class = EUI.SafeValue(function() return select(2, UnitClass('player')) end)
    if class == 'DRUID' then
        return EUI.Read('UnitPowerType', UnitPowerType, 'player') == ENERGY
    end
    return class == 'ROGUE'
end

-- Your combo points on the unit. They are stored on the unit: GetComboPoints reads them
-- there, while UnitPower is the raw count wherever the points are.
function TargetBarClass:UpdateCombo()
    if not self.combo or not isLive(self) then
        return
    end
    local shown = usesComboPoints()
    self.combo:SetShown(shown)
    if not shown then
        return
    end
    local ok, count = pcall(GetComboPoints, 'player', self.unit)
    if not ok then
        EUI.LogOnce('combo:error', 'combo points: %s', tostring(count))
        count = 0
    elseif not EUI.CanAccess(count) then
        EUI.LogOnce('combo:secret', 'combo points are secret; drawn through StatusBar ranges')
    end
    self.combo:SetCount(count)
end

-- Name colour, NPC mode, PvP badge and leader crown; tapping and combat state change without a
-- dedicated event, so the main ticker calls this too.
function TargetBarClass:UpdateIdentity()
    if not isLive(self) then
        return
    end
    local unit = self.unit
    local key, npc = UnitInfo.ReactionKey(unit)
    if key ~= self.colorKey then
        self.colorKey = key
        applyNameColor(self, key)
    end
    -- An NPC in combat (escorts, guards) shows its HP.
    setNpcMode(self, npc and not EUI.Read('UnitAffectingCombat', UnitAffectingCombat, unit))
    setPvP(self, UnitInfo.PvPKind(unit))
    -- UnitLeadsAnyGroup also covers players outside your group.
    local leads
    if UnitLeadsAnyGroup then
        leads = EUI.Read('UnitLeadsAnyGroup', UnitLeadsAnyGroup, unit)
    else
        leads = EUI.Read('UnitIsGroupLeader', UnitIsGroupLeader, unit)
    end
    self.leader:SetShown(leads == true)
end

function TargetBarClass:UpdateName()
    if not isLive(self) then
        return
    end
    pcall(self.name.SetText, self.name, EUI.UnitDisplayName(self.unit))
    fitNameBg(self)
end

function TargetBarClass:UpdateTier()
    if not isLive(self) then
        return
    end
    setTier(self, EUI.Read('UnitClassification', UnitClassification, self.unit))
end

-- Difficulty-coloured for units you can attack, so it also changes with faction and PvP state.
function TargetBarClass:UpdateLevel()
    if not isLive(self) then
        return
    end
    local unit = self.unit
    local level = EUI.SafeValue(UnitLevel, unit)
    if level and EUI.Read('UnitCanAttack', UnitCanAttack, 'player', unit) then
        setLevel(self, level, UnitInfo.DifficultyColor(unit, level))
    else
        setLevel(self, level)
    end
end

function TargetBarClass:Refresh()
    if self.preview or not self.unit then
        return
    end
    local unit = self.unit
    if not UnitExists(unit) then
        self.content:Hide()
        return
    end
    self.content:Show()

    self:UpdateName()
    self.colorKey = nil
    self:UpdateIdentity()
    self:UpdateIcon()
    self:UpdateFlags()
    self:UpdateTier()
    self:UpdateLevel()
    self:UpdateHealth(false)
    self:UpdateThreat()
    self:UpdateCombo()
    self.auras:Refresh()
    self.cast:EndFailure()
    self.cast:Update()
    self:UpdateTargetOfTarget()
end

function TargetBarClass:UpdateHealth(smooth)
    if not isLive(self) then
        return
    end
    local unit = self.unit
    local maxHealth = UnitHealthMax(unit)
    self.bar:SetRange(maxHealth)
    self.bar:SetValue(UnitHealth(unit), smooth)
    self.bar:ShowIncomingHeals(unit, maxHealth)
    EUI.Curves.SetHealthPercentText(self.hpp, unit)
    local dead = EUI.Read('UnitIsDeadOrGhost', UnitIsDeadOrGhost, unit) == true
    self.portrait:SetDesaturated(dead)
    if dead then
        self.portrait:SetVertexColor(1, 1, 1, 1)
    else
        EUI.Curves.ApplyHealthTint(self.portrait, unit, self.lowHealthCurve)
    end
end

function TargetBarClass:UpdateHealPrediction()
    if not isLive(self) then
        return
    end
    self.bar:ShowIncomingHeals(self.unit, UnitHealthMax(self.unit))
end

-- The unit's target fires no UNIT_HEALTH events; the main ticker calls this.
function TargetBarClass:UpdateTargetOfTarget()
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
    -- Eases only while the same unit stays the target's target.
    local guid = EUI.SafeValue(UnitGUID, totUnit)
    self.totBar:SetRange(UnitHealthMax(totUnit))
    self.totBar:SetValue(UnitHealth(totUnit), guid ~= nil and guid == self.totGuid)
    self.totGuid = guid
    pcall(self.totName.SetText, self.totName, EUI.UnitDisplayName(totUnit))
    self.totName:SetTextColor(Style.Color(nameHex(self.spec, (UnitInfo.ReactionKey(totUnit)))))
    setMarkedName(self.totName, self.spec.tot.txtName, self.totMarker, self.spec.tot.raidMarker,
        EUI.Indicators.ReadRaidMarker(totUnit))
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
        local max = EUI.AuraRow.GroupSpec(spec, group[1]).max
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
--          buffs, castName, castProgress, castNotInterruptible, castChannel, totName, totColorKey, totPercent,
--          combo }
-- npc: the separator line replaces the HP bar. class: a class token's icon; portrait: a texture
-- path; portraitUnit: that unit's portrait. threat, totName and combo are optional; nil hides them.
function TargetBarClass:SetPreview(data)
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
        self.demoAuras = EUI.StaticIcons.Create(self.content, spec.auras, self.fonts)
    end
    setLiveAurasShown(self, false)
    self.content:Show()
    self.name:SetText(data.name)
    self.nameShift = setMarkedName(self.name, spec.txtName, self.marker, spec.raidMarker, data.raidMarker,
        self.flag, spec.flag, data.tag)
    fitNameBg(self)
    applyNameColor(self, data.colorKey)
    self.colorKey = nil
    setNpcMode(self, data.npc == true)
    setPvP(self, data.pvp)
    self.leader:SetShown(data.leader == true)
    setTier(self, data.classification)
    if self.combo then
        self.combo:SetShown(data.combo ~= nil)
        self.combo:SetCount(data.combo)
    end
    self.hpp:SetText(string.format('%d%%', data.hpPercent))
    self.threat:SetShown(data.threat ~= nil)
    self.threatText:SetShown(data.threat ~= nil and data.threatPercent ~= nil)
    if data.threat then
        self.threat:SetVertexColor(EUI.Indicators.ThreatColor(data.threat))
        if data.threatPercent then
            self.threatText:SetFormattedText('%.0f%%', data.threatPercent)
            self.threatText:SetTextColor(EUI.Indicators.ThreatColor(data.threat))
        end
    end
    setIcon(self, data.class, function(texture)
        if data.portrait then
            texture:SetTexture(data.portrait)
        else
            EUI.Read('SetPortraitTexture', SetPortraitTexture, texture, data.portraitUnit)
        end
    end)
    self.portrait:SetDesaturated(data.dead == true)
    local low = not data.dead and data.hpPercent < spec.lowHealth.below * 100
    self.portrait:SetVertexColor(Style.Color(low and spec.lowHealth.color or '#FFFFFFFF'))
    if UnitInfo.ATTACKABLE[data.colorKey] then
        setLevel(self, data.level, UnitInfo.DifficultyColor(nil, data.level))
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
        self.totName:SetTextColor(Style.Color(nameHex(spec, data.totColorKey)))
    end
    self.cast:SetPreview(data.castName or false, data.castProgress, data.castNotInterruptible, data.castChannel)
end
