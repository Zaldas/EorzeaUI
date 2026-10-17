local _, AV = ...

-- Building blocks shared by the style files. Values are VanaVista's, in 1440p pixels.

AV.styles = AV.styles or {}
local Kit = {}
AV.StyleKit = Kit

Kit.STROKE_BLUE = '#062D54C8'
Kit.STROKE_RED = '#3B0B0BC8'

-- 128x64 party bar on a 256x128 texture; no slicing needed at uniform half scale.
-- art: asset folder, e.g. 'ffxi'
function Kit.rowBar(art, frameColor, fillColor)
    return {
        width = 128,
        height = 64,
        bg = { path = art .. '/BarBG', color = frameColor },
        fill = { path = art .. '/Bar', color = fillColor, x = 13, width = 102 },
        fg = { path = art .. '/BarFG', color = frameColor },
    }
end

-- Wide bars three-slice the ffxi frame art: 30px texture caps on a 256x128 texture.
function Kit.wideBar(width, frameColor, fillColor)
    return {
        width = width,
        height = 64,
        slice = { texSize = { 256, 128 }, cap = 30 },
        bg = { path = 'ffxi/BarBG', color = frameColor },
        fill = { path = 'ffxi/Bar', color = fillColor, x = 13, width = width - 26 },
        fg = { path = 'ffxi/BarFG', color = frameColor },
    }
end

Kit.FONTS = { name = 'arial.ttf', number = 'grammara.ttf', timer = 'consola.ttf', badge = 'Fonts\\FRIZQT__.TTF' }

-- Level number on the class icon's bottom edge.
Kit.levelBadge = { size = { 32, 18 }, textSize = 13, textOffset = { 2, 0 }, color = '#FFFFFFFF', edge = 'BOTTOM', overlap = 0.5 }

-- Party row indicators, in row coordinates. The class icon spans x -11..25, y -2..34.
-- nameX/nameY are the style's txtName pos; a raid marker takes that spot and shifts the name.
-- leader: crown on the icon's top edge; rowSpacing keeps it clear of the level number above.
-- assistant (upper) and masterLooter (lower): straddling the icon's right edge, mirroring
-- role/pvp on the left. Either one alone centres between the two slots.
-- rest/combat: player row only, on the icon's top-right corner. status: ready check, summon,
-- resurrect or phased, centred on the icon. role/pvp: straddling the icon's left edge.
-- tagColor: the [AFK]/[DND] prefix on the name.
function Kit.partyIndicators(nameX, nameY)
    return {
        leader = { pos = { 0, -8 }, size = { 14, 14 } },
        assistant = { pos = { 16, 2 }, size = { 14, 14 } },
        masterLooter = { pos = { 16, 17 }, size = { 14, 14 } },
        rest = { pos = { 14, -10 }, size = { 24, 24 } },
        combat = { pos = { 16, -6 }, size = { 18, 18 } },
        status = { pos = { -5, 4 }, size = { 24, 24 } },
        raidMarker = { pos = { nameX, nameY + 1 }, size = { 16, 16 } },
        role = { pos = { -18, -1 }, size = { 16, 16 } },
        pvp = { pos = { -20, 15 }, size = { 20, 20 } },
        tagColor = '#A0A0A0FF',
        stateColor = '#A0A0A0FF',
        healPrediction = { color = '#7CFC8C80', absorbColor = '#DDEEFFB3' },
    }
end

Kit.HP_THRESHOLDS = {
    { below = 0.25, color = '#FC8182FF' },
    { below = 0.50, color = '#F8BA80FF' },
    { below = 0.75, color = '#F3F37CFF' },
}

-- Spell name for the cast bars. text = { color, size, font, baseline }; baseline is the
-- text's bottom edge in bar pixels, shared so every name sits at the same height on its bar.
-- width (optional) truncates the name; yOffset (optional) shifts it from the shared baseline.
function Kit.castName(text, width, yOffset)
    return {
        pos = { 20, text.baseline - text.size + (yOffset or 0) },
        width = width,
        size = text.size,
        color = text.color,
        stroke = Kit.STROKE_BLUE,
        font = text.font,
    }
end

-- cast = { frame, fill, text } for the target's cast bar; text as in Kit.castName.
function Kit.target(cast)
    return {
        width = 786,
        height = 120,
        bar = Kit.wideBar(537, '#FF9597FF', '#FF9597FF'),
        reactionColors = {
            hostile = '#FF9597FF',
            neutral = '#F3F37CFF',
            friendly = '#95D5FFFF',
        },
        txtName = { pos = { 20, 15 }, size = 17, color = '#C8C8C8FF', stroke = Kit.STROKE_BLUE },
        txtHpp = { pos = { 515, 20 }, size = 14, color = '#C8C8C8FF', stroke = Kit.STROKE_RED, font = 'number', alignRight = true },
        txtLevel = { pos = { 520, 38 }, size = 12, color = '#C8C8C8FF', stroke = Kit.STROKE_RED, font = 'number', alignRight = true },
        debuffs = { pos = { 15, 44 }, size = 22, spacing = 3, max = 12, timers = true },
        buffs = { pos = { 15, 82 }, size = 22, spacing = 3, max = 12, timers = true },
        cast = {
            pos = { 225, -15 },
            bar = Kit.wideBar(234, cast.frame, cast.fill),
            txtName = Kit.castName(cast.text),
        },
        attention = { path = 'ffxi/attention', pos = { 545, 26 }, size = { 11, 12 }, color = '#FFFFFFFF' },
        tot = {
            pos = { 560, 0 },
            bar = Kit.wideBar(226, '#FF9597FF', '#FF9597FF'),
            txtName = { pos = { 20, 17 }, size = 16, color = '#C8C8C8FF', stroke = Kit.STROKE_RED },
        },
    }
end

function Kit.castBar(frameColor, fillColor, text)
    return {
        width = 467,
        height = 64,
        bar = Kit.wideBar(467, frameColor, fillColor),
        txtName = Kit.castName(text),
    }
end
