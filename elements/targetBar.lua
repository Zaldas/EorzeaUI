local _, AV = ...

-- Target bar: HP bar tinted by reaction, name, HP%, level, debuff/buff rows, target cast bar,
-- and a target-of-target mini bar. Not secure: it only displays, so it may show/hide in combat.

AV.TargetBar = {}
local TargetBar = AV.TargetBar

local Style = AV.Style

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
    local overlay = TargetBar.bar.overlay
    TargetBar.name = Style.Text(overlay, spec.txtName, fonts)
    TargetBar.hpp = Style.Text(overlay, spec.txtHpp, fonts)
    TargetBar.level = Style.Text(overlay, spec.txtLevel, fonts)

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

local function reactionColor(unit)
    local colors = TargetBar.spec.reactionColors
    local reaction = AV.SafeValue(UnitReaction, unit, 'player')
    if not reaction then
        return colors.hostile
    end
    if reaction >= 5 then
        return colors.friendly
    elseif reaction == 4 then
        return colors.neutral
    end
    return colors.hostile
end

local function tint(bar, hex)
    bar:SetFrameColor(hex)
    bar:SetFillColor(hex)
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
    local level = AV.SafeValue(UnitLevel, 'target')
    if level then
        TargetBar.level:SetText(level < 0 and 'Lv ??' or string.format('Lv %d', level))
    else
        TargetBar.level:SetText('')
    end
    tint(TargetBar.bar, reactionColor('target'))
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
    tint(TargetBar.totBar, reactionColor('targettarget'))
    TargetBar.totBar:SetRange(UnitHealthMax('targettarget'))
    TargetBar.totBar:SetValue(UnitHealth('targettarget'), true)
    pcall(TargetBar.totName.SetText, TargetBar.totName, AV.UnitDisplayName('targettarget'))
end

-- Edit Mode preview: show every part with placeholder values.
local function setLiveAurasShown(shown)
    for _, row in ipairs({ TargetBar.debuffs, TargetBar.buffs }) do
        if row.container then
            row.container:SetShown(shown)
        end
    end
end

-- data = { name, level, hpPercent, debuffs, buffs, castName, castProgress, totName, totPercent },
-- or nil to restore live updates.
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
    TargetBar.hpp:SetText(string.format('%d%%', data.hpPercent))
    TargetBar.level:SetText(string.format('Lv %d', data.level))
    tint(TargetBar.bar, TargetBar.spec.reactionColors.hostile)
    TargetBar.bar:SetRange(100)
    TargetBar.bar:SetValue(data.hpPercent)
    TargetBar.demoDebuffs:Set(data.debuffs)
    TargetBar.demoBuffs:Set(data.buffs)
    TargetBar.tot:Show()
    TargetBar.attention:Show()
    tint(TargetBar.totBar, TargetBar.spec.reactionColors.friendly)
    TargetBar.totBar:SetRange(100)
    TargetBar.totBar:SetValue(data.totPercent)
    TargetBar.totName:SetText(data.totName)
    TargetBar.cast:SetPreview(data.castName, data.castProgress)
end
