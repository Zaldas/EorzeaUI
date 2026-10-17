local _, AV = ...

-- Building blocks shared by the style files. Values are VanaVista's, in 1440p pixels.

AV.styles = AV.styles or {}
local Kit = {}
AV.StyleKit = Kit

Kit.STROKE_BLUE = '#062D54C8'
Kit.STROKE_RED = '#3B0B0BC8'

-- 128x64 party bar on a 256x128 texture; no slicing needed at uniform half scale.
-- art = 'xiv' | 'ffxi'
function Kit.rowBar(art, frameColor, fillColor, glowColor)
    return {
        width = 128,
        height = 64,
        bg = { path = art .. '/BarBG', color = frameColor },
        fill = { path = art .. '/Bar', color = fillColor, x = 13, width = 102 },
        fg = { path = art .. '/BarFG', color = frameColor },
        glow = { path = art .. '/BarGlow', color = glowColor, width = 6 },
        glowSides = { path = art .. '/BarGlowSides', color = glowColor, x = 11, width = 2 },
    }
end

-- Wide bars three-slice the ffxi frame art: 30px texture caps on a 256x128 texture.
function Kit.wideBar(width, frameColor, fillColor, glowColor)
    return {
        width = width,
        height = 64,
        slice = { texSize = { 256, 128 }, cap = 30 },
        bg = { path = 'ffxi/BarBG', color = frameColor },
        fill = { path = 'ffxi/Bar', color = fillColor, x = 13, width = width - 26 },
        fg = { path = 'ffxi/BarFG', color = frameColor },
        glow = glowColor and { path = 'ffxi/BarGlow', color = glowColor, width = 8 } or nil,
    }
end

Kit.FONTS = { name = 'arial.ttf', number = 'grammara.ttf', timer = 'consola.ttf', badge = 'Fonts\\FRIZQT__.TTF' }

-- Level number on the class icon's bottom edge.
Kit.levelBadge = { size = { 32, 18 }, textSize = 13, textOffset = { 2, 0 }, color = '#FFFFFFFF', edge = 'BOTTOM', overlap = 0.5 }

Kit.HP_THRESHOLDS = {
    { below = 0.25, color = '#FC8182FF' },
    { below = 0.50, color = '#F8BA80FF' },
    { below = 0.75, color = '#F3F37CFF' },
}

-- cast = { frame, fill, text, textFont, textSize } colours for the target's cast bar.
function Kit.target(cast)
    return {
        width = 786,
        height = 120,
        bar = Kit.wideBar(537, '#FF9597FF', '#FF9597FF', '#FFF2F2FF'),
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
        -- The spell name's baseline lands where the player cast bar's 17px text does (y 32),
        -- so it overlaps the bar by the same fraction at any text size.
        cast = {
            pos = { 225, -15 },
            bar = Kit.wideBar(234, cast.frame, cast.fill),
            txtName = { pos = { 20, 32 - cast.textSize }, size = cast.textSize, color = cast.text, stroke = Kit.STROKE_BLUE, font = cast.textFont },
        },
        attention = { path = 'ffxi/attention', pos = { 545, 26 }, size = { 11, 12 }, color = '#FFFFFFFF' },
        tot = {
            pos = { 560, 0 },
            bar = Kit.wideBar(226, '#FF9597FF', '#FF9597FF', '#FFF2F2FF'),
            txtName = { pos = { 20, 17 }, size = 16, color = '#C8C8C8FF', stroke = Kit.STROKE_RED },
        },
    }
end

function Kit.castBar(frameColor, fillColor, textColor)
    return {
        width = 467,
        height = 64,
        bar = Kit.wideBar(467, frameColor, fillColor),
        txtName = { pos = { 20, 15 }, size = 17, color = textColor, stroke = Kit.STROKE_BLUE },
    }
end
