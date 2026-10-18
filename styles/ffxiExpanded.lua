local _, EUI = ...

-- Ported from VanaVista layouts/styles/ffxiPartyExpanded.lua, ffxiTargetbar.lua and ffxiCastbar.lua.

local Kit = EUI.StyleKit

local valueText = {
    pos = { 120, 34 }, size = 13, color = '#F0FFFFFF', stroke = Kit.STROKE_BLUE, font = 'number', alignRight = true,
}
local castText = { color = '#F0FFFFFF', size = 14, font = 'number', baseline = 34 }

EUI.styles.ffxiExpanded = {
    fonts = Kit.FONTS,

    party = {
        width = 410,
        rowHeight = 46,
        rowSpacing = 13,
        background = {
            color = '#FFFFFF80',
            pos = { 7, -11 },
            width = 420,
            top = { path = 'ffxi/BgTop', height = 10 },
            mid = { path = 'ffxi/BgMid' },
            bottom = { path = 'ffxi/BgBottom', height = 8 },
        },
        -- Raid only. Centred on the background (x 7..427) with header lines in the text's gold;
        -- the box ends 3px above the background's top edge (y -11). Gold with a black shadow and
        -- no outline in Friz Quadrata: WoW's GameFontNormal look.
        groupNumber = {
            pos = { 7, -32 },
            width = 420,
            height = 18,
            txtLabel = { size = 18, color = '#FFD100FF', stroke = '#000000FF', outline = '', font = 'standard' },
            line = { color = '#FFD100FF', alpha = Kit.HEADER_LINE.alpha, height = Kit.HEADER_LINE.height, gap = Kit.HEADER_LINE.gap },
        },
        -- Blizzard's party frames tint the portrait red at 20% health or below.
        lowHealth = { below = 0.2, color = '#FF0000FF' },
        hp = {
            pos = { 19, -7 },
            bar = Kit.rowBar('ffxi', '#FF9597FF', '#FF9597FF'),
            txtValue = valueText,
            textColor = '#F0FFFFFF',
            thresholds = Kit.HP_THRESHOLDS,
        },
        power = {
            pos = { 150, -7 },
            bar = Kit.rowBar('ffxi', '#FFFF9CFF', '#FFFF9CFF'),
            txtValue = valueText,
            -- Keyed by UnitPowerType: 0 mana, 1 rage, 2 focus, 3 energy. Others keep the bar colour.
            colors = { [0] = '#8FB8FFFF', [1] = '#FF7A5CFF', [2] = '#FFB870FF', [3] = '#FFFF9CFF' },
            -- Player row: the slice the current cast will spend, over the end of the fill.
            cost = { color = '#FFFFFF99', fade = 0.25 },
        },
        -- Player row, druid in bear/cat form: the form's power bar in a sub-row under the power
        -- bar (which keeps showing mana), from the HP bar's middle (x 83) to x 239, 39px short of
        -- the power bar's end. Its line (row y 40.5..53) clears both numbers above. The row grows by
        -- formRowHeight while shifted.
        formRowHeight = 22,
        formBar = {
            pos = { 83, 15 },
            bar = Kit.wideBar(156, '#FFFF9CFF', '#FFFF9CFF'),
            txtValue = { pos = { 148, 34 }, size = 13, color = '#F0FFFFFF', stroke = Kit.STROKE_BLUE, font = 'number', alignRight = true },
        },
        classIcon = {
            pos = { -13, -4 },
            size = 40,
            bg = 'jobIcons/bg',
            gradient = 'jobIcons/gradient',
            frame = 'jobIcons/frame',
        },
        range = { farAlpha = 0.55 },
        -- Tinted with Blizzard's threat colours; hidden without threat.
        threat = { path = 'pips/diamondFill-16', pos = { 29, 29 }, size = { 12, 12 } },
        hover = { path = 'ffxi/Hover', pos = { 20, -8 }, size = { 390, 60 }, color = '#9C94E8AA' },
        cursor = { path = 'ffxi/Cursor', pos = { -47, 4 }, size = { 37, 24 }, color = '#FFFFFFFF', onTop = true },
        txtName = { pos = { 38, 3 }, width = 242, size = 17, color = '#F0FFFFFF', stroke = Kit.STROKE_BLUE },
        -- Replaces the name row while the member casts, spanning the HP and power bars (x 19..278).
        -- Spell name in the target cast bar's text style, 1px higher on the bar.
        cast = {
            pos = { 19, -19 },
            bar = Kit.wideBar(259, '#6AB4F8FF', '#6AB4F8FF'),
            txtName = Kit.castName(castText, 219, -1),
        },
        levelBadge = Kit.levelBadge,
        indicators = Kit.partyIndicators(38, 3),
        buffs = { pos = { 284, -6 }, size = 18, spacing = 2, max = 6, border = Kit.AURA_BORDER },
        debuffs = { pos = { 284, 16 }, size = 18, spacing = 2, max = 6, border = Kit.AURA_BORDER },
        -- Pet sub-row at the bottom of the owner's row, which grows by rowHeight while the pet
        -- exists. A compact member row, in sub-row coordinates: name line on top, then HP and
        -- power side by side on VanaVista's short alliance bars (lines x 52.5..129.5 and
        -- 139.5..216.5, y 15..23), then happiness. Indented so the portrait starts at the owner's
        -- class icon's right edge.
        pet = {
            rowHeight = 29,
            -- The art draws this far above the sub-row, tucking it under the owner's row; the
            -- sub-row's bottom then leaves the usual rowSpacing to the next member.
            shiftUp = 3,
            -- The job frame at 0.75 scale, its right edge on the HP line's start.
            portrait = { pos = { 24, 3 }, size = 27, inset = 3.5 },
            txtName = { pos = { 61, 1 }, width = 156, size = 12, color = '#F0FFFFFF', stroke = Kit.STROKE_BLUE },
            hp = {
                pos = { 27, -13 },
                bar = Kit.allyBar('#FF9597FF', '#FF9597FF'),
                txtValue = { pos = { 100, 34 }, size = 10, color = '#F0FFFFFF', stroke = Kit.STROKE_BLUE, font = 'number', alignRight = true },
                textColor = '#F0FFFFFF',
                thresholds = Kit.HP_THRESHOLDS,
            },
            -- Tinted with party.power.colors.
            power = {
                pos = { 114, -13 },
                bar = Kit.allyBar('#FFFF9CFF', '#FFFF9CFF'),
                txtValue = { pos = { 100, 34 }, size = 10, color = '#F0FFFFFF', stroke = Kit.STROKE_BLUE, font = 'number', alignRight = true },
            },
            -- Own pet only, replacing the name line while it casts, as members' cast bars do.
            -- Spans the HP line's start to the power line's end (x 52.5..216.5).
            cast = {
                pos = { 27, -25 },
                bar = Kit.allyBar('#6AB4F8FF', '#6AB4F8FF', 215),
                txtName = { pos = { 29, 24 }, width = 160, size = 10, color = '#F0FFFFFF', stroke = Kit.STROKE_BLUE, font = 'number' },
            },
            -- Own hunter pet only, right of the power bar.
            happiness = { pos = { 223, 10 }, size = { 20, 19 } },
            hover = { path = 'ffxi/Hover', pos = { 20, -6 }, size = { 390, 44 }, color = '#9C94E8AA' },
            -- Own pet only: debuffs then buffs in the party aura column, max of each.
            auras = { pos = { 284, 7 }, size = 18, spacing = 2, max = 3, border = Kit.AURA_BORDER },
        },
    },

    -- Maxes match Blizzard's target frame (16 debuffs, 32 buffs): at most 3 lines.
    target = Kit.target({ frame = '#6AB4F8FF', fill = '#6AB4F8FF', text = castText }, {
        bar = 537, icon = 46, name = 17, hpp = 14, cast = 234, tot = 226, totName = 16,
        height = 120, perLine = 16, debuffs = 16, buffs = 32, combo = true,
    }),
    -- HP bar half the target's; the party's 40px icon. 16 auras at most, 8 per line; the
    -- containers cannot cap a total, so each group gets half. The cast bar covers most of the
    -- name line, so the name hides while it shows.
    focus = Kit.target({ frame = '#6AB4F8FF', fill = '#6AB4F8FF', text = castText }, {
        bar = 268, icon = 40, name = 15, hpp = 13, cast = 160, tot = 180, totName = 14,
        height = 100, perLine = 8, debuffs = 8, buffs = 8, label = 'Focus', castHidesName = true,
    }),
    castBar = Kit.castBar('#6AB4F8FF', '#6AB4F8FF', castText),
}
