local _, AV = ...

-- Target bar: HP bar, name coloured by unit kind and claim, HP%, a class icon or portrait with
-- the level badge, debuff/buff rows, target cast bar, and a target-of-target mini bar.
-- Non-attackable NPCs get a separator line instead of the HP bar.
-- Not secure: it only displays, so it may show/hide in combat.

AV.TargetBar = {}
local TargetBar = AV.TargetBar

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

local function createIcon(parent, spec, fonts, frameLevel)
    local iconSpec = spec.icon
    local size = iconSpec.size
    local frame = CreateFrame('Frame', nil, parent)
    frame:SetSize(size, size)
    Style.Place(frame, parent, iconSpec.pos)
    frame:SetFrameLevel(frameLevel)
    local full = { 0, 0 }
    Style.Image(frame, 'BACKGROUND', { path = iconSpec.bg, pos = full, size = { size, size } })
    TargetBar.iconGradient = Style.Image(frame, 'BORDER', { path = iconSpec.gradient, pos = full, size = { size, size } })
    local portrait = frame:CreateTexture(nil, 'ARTWORK')
    portrait:SetPoint('TOPLEFT', iconSpec.inset, -iconSpec.inset)
    portrait:SetPoint('BOTTOMRIGHT', -iconSpec.inset, iconSpec.inset)
    TargetBar.portrait = portrait
    TargetBar.iconFrameArt = Style.Image(frame, 'OVERLAY', { path = iconSpec.frame, pos = full, size = { size, size } })
    TargetBar.levelBadge = AV.LevelBadge.Create(frame, frame, spec.levelBadge, fonts)
    TargetBar.levelBadge.frame:SetFrameLevel(frameLevel + 2)
    TargetBar.icon = frame
end

function TargetBar.Create(style, fonts)
    local spec = style.target

    local anchor = CreateFrame('Frame', 'AzerothVistaTargetAnchor', UIParent)
    anchor:SetSize(spec.width, spec.height)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    TargetBar.anchor = anchor

    local content = CreateFrame('Frame', nil, anchor)
    content:SetAllPoints(anchor)
    TargetBar.content = content
    TargetBar.spec = spec
    TargetBar.fonts = fonts

    TargetBar.bar = AV.Bar.Create(content, spec.bar, { 0, 0 })
    -- Text lives above the bar rather than on it, so the bar can hide for NPCs. The bar sits
    -- at the content's origin, so both share coordinates.
    local top = CreateFrame('Frame', nil, content)
    top:SetAllPoints(content)
    top:SetFrameLevel(TargetBar.bar.overlay:GetFrameLevel() + 1)
    TargetBar.name = Style.Text(top, spec.txtName, fonts)
    TargetBar.hpp = Style.Text(top, spec.txtHpp, fonts)
    TargetBar.separator = createSeparator(top, spec.separator)
    createIcon(content, spec, fonts, top:GetFrameLevel() + 1)
    TargetBar.lowHealthCurve = AV.Curves.Step({ spec.lowHealth }, '#FFFFFFFF')

    TargetBar.debuffs = AV.AuraRow.Create(content, 'target', 'HARMFUL', spec.debuffs, fonts)
    TargetBar.buffs = AV.AuraRow.Create(content, 'target', 'HELPFUL', spec.buffs, fonts)

    TargetBar.cast = AV.CastBar.Create(content, 'target', spec.cast, fonts, spec.cast.pos)

    TargetBar.attention = Style.Image(content, 'ARTWORK', spec.attention)
    local tot = CreateFrame('Frame', nil, content)
    tot:SetSize(spec.tot.bar.width, spec.tot.bar.height)
    Style.Place(tot, content, spec.tot.pos)
    TargetBar.tot = tot
    TargetBar.totBar = AV.Bar.Create(tot, spec.tot.bar, { 0, 0 })
    TargetBar.totName = Style.Text(TargetBar.totBar.overlay, spec.tot.txtName, fonts)

    TargetBar.Refresh()
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

local function setNpcMode(npc)
    if TargetBar.npcMode == npc then
        return
    end
    TargetBar.npcMode = npc
    TargetBar.bar.frame:SetShown(not npc)
    TargetBar.hpp:SetShown(not npc)
    TargetBar.separator:SetShown(npc)
end

local function applyNameColor(key)
    local hex = TargetBar.spec.nameColors[key]
    TargetBar.name:SetTextColor(Style.Color(hex))
    colorSeparator(TargetBar.separator, hex, TargetBar.spec.separator)
    setNpcMode(key == 'npc')
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

local function setLevel(level, r, g, b)
    TargetBar.levelBadge:Set(level)
    TargetBar.levelBadge:SetColor(r, g, b)
end

local function setClassification(classification)
    TargetBar.iconFrameArt:SetVertexColor(Style.Color(TargetBar.spec.icon.classification[classification] or '#FFFFFFFF'))
end

local function cropCircle(texture, left, right, top, bottom)
    local dx, dy = (right - left) * CIRCLE_INSET, (bottom - top) * CIRCLE_INSET
    texture:SetTexCoord(left + dx, right - dx, top + dy, bottom - dy)
end

-- Class icon for players, the engine-rendered portrait for everything else.
local function setIcon(unit, isPlayer)
    local portrait = TargetBar.portrait
    local classToken = isPlayer and AV.Read('UnitClass', function() return select(2, UnitClass(unit)) end)
    local coords = classToken and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classToken]
    local color = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    if coords then
        portrait:SetTexture(CLASS_ICONS)
        cropCircle(portrait, unpack(coords))
    else
        AV.Read('SetPortraitTexture', SetPortraitTexture, portrait, unit)
        cropCircle(portrait, 0, 1, 0, 1)
    end
    if color then
        TargetBar.iconGradient:SetVertexColor(color.r, color.g, color.b, 1)
    else
        TargetBar.iconGradient:SetVertexColor(Style.Color(NPC_GRADIENT))
    end
end

function TargetBar.UpdateIcon()
    if TargetBar.preview or not UnitExists('target') then
        return
    end
    setIcon('target', AV.Read('UnitIsPlayer', UnitIsPlayer, 'target') == true)
end

-- Name colour and NPC mode; claim and combat state change without a dedicated event, so the
-- main ticker calls this too.
function TargetBar.UpdateIdentity()
    if TargetBar.preview or not UnitExists('target') then
        return
    end
    local key = nameColorKey('target')
    if key ~= TargetBar.colorKey then
        TargetBar.colorKey = key
        applyNameColor(key)
    end
end

function TargetBar.Refresh()
    if TargetBar.preview then
        return
    end
    if not UnitExists('target') then
        TargetBar.content:Hide()
        return
    end
    TargetBar.content:Show()

    pcall(TargetBar.name.SetText, TargetBar.name, AV.UnitDisplayName('target'))
    TargetBar.colorKey = nil
    TargetBar.UpdateIdentity()
    TargetBar.UpdateIcon()
    setClassification(AV.Read('UnitClassification', UnitClassification, 'target'))
    local level = AV.SafeValue(UnitLevel, 'target')
    if level and AV.Read('UnitCanAttack', UnitCanAttack, 'player', 'target') then
        setLevel(level, difficultyColor('target', level))
    else
        setLevel(level)
    end
    TargetBar.UpdateHealth(false)
    TargetBar.debuffs:Refresh()
    TargetBar.buffs:Refresh()
    TargetBar.cast:Update()
    TargetBar.UpdateTargetOfTarget()
end

function TargetBar.UpdateHealth(smooth)
    if TargetBar.preview or not UnitExists('target') then
        return
    end
    TargetBar.bar:SetRange(UnitHealthMax('target'))
    TargetBar.bar:SetValue(UnitHealth('target'), smooth)
    AV.Curves.SetHealthPercentText(TargetBar.hpp, 'target')
    local dead = AV.Read('UnitIsDeadOrGhost', UnitIsDeadOrGhost, 'target') == true
    TargetBar.portrait:SetDesaturated(dead)
    if dead then
        TargetBar.portrait:SetVertexColor(1, 1, 1, 1)
    else
        AV.Curves.ApplyHealthTint(TargetBar.portrait, 'target', TargetBar.lowHealthCurve)
    end
end

-- targettarget fires no UNIT_HEALTH events; the main ticker calls this.
function TargetBar.UpdateTargetOfTarget()
    if TargetBar.preview then
        return
    end
    local exists = UnitExists('target') and UnitExists('targettarget')
    TargetBar.tot:SetShown(exists)
    TargetBar.attention:SetShown(exists)
    if not exists then
        return
    end
    TargetBar.totBar:SetRange(UnitHealthMax('targettarget'))
    TargetBar.totBar:SetValue(UnitHealth('targettarget'), true)
    pcall(TargetBar.totName.SetText, TargetBar.totName, AV.UnitDisplayName('targettarget'))
    TargetBar.totName:SetTextColor(Style.Color(TargetBar.spec.nameColors[nameColorKey('targettarget')]))
end

-- Edit Mode preview: show every part with placeholder values.
local function setLiveAurasShown(shown)
    for _, row in ipairs({ TargetBar.debuffs, TargetBar.buffs }) do
        if row.container then
            row.container:SetShown(shown)
        end
    end
end

-- data = { name, level, classification, colorKey, portraitUnit, hpPercent, debuffs, buffs,
-- castName, castProgress, totName, totColorKey, totPercent }, or nil to restore live updates.
function TargetBar.SetPreview(data)
    TargetBar.preview = data ~= nil
    if not data then
        if TargetBar.demoDebuffs then
            TargetBar.demoDebuffs:Set(nil)
            TargetBar.demoBuffs:Set(nil)
        end
        setLiveAurasShown(true)
        TargetBar.cast:SetPreview(nil)
        TargetBar.Refresh()
        return
    end
    if not TargetBar.demoDebuffs then
        TargetBar.demoDebuffs = AV.StaticIcons.Create(TargetBar.content, TargetBar.spec.debuffs, TargetBar.fonts)
        TargetBar.demoBuffs = AV.StaticIcons.Create(TargetBar.content, TargetBar.spec.buffs, TargetBar.fonts)
    end
    setLiveAurasShown(false)
    TargetBar.content:Show()
    TargetBar.name:SetText(data.name)
    applyNameColor(data.colorKey)
    TargetBar.colorKey = nil
    TargetBar.hpp:SetText(string.format('%d%%', data.hpPercent))
    setIcon(data.portraitUnit, false)
    TargetBar.portrait:SetDesaturated(false)
    TargetBar.portrait:SetVertexColor(1, 1, 1, 1)
    setClassification(data.classification)
    setLevel(data.level, difficultyColor(nil, data.level))
    TargetBar.bar:SetRange(100)
    TargetBar.bar:SetValue(data.hpPercent)
    TargetBar.demoDebuffs:Set(data.debuffs)
    TargetBar.demoBuffs:Set(data.buffs)
    TargetBar.tot:Show()
    TargetBar.attention:Show()
    TargetBar.totBar:SetRange(100)
    TargetBar.totBar:SetValue(data.totPercent)
    TargetBar.totName:SetText(data.totName)
    TargetBar.totName:SetTextColor(Style.Color(TargetBar.spec.nameColors[data.totColorKey]))
    TargetBar.cast:SetPreview(data.castName, data.castProgress)
end
