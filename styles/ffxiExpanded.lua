local _, AV = ...

-- Ported from VanaVista layouts/styles/ffxiPartyExpanded.lua, ffxiTargetbar.lua and ffxiCastbar.lua.

local Kit = AV.StyleKit

local valueText = {
    pos = { 120, 34 }, size = 13, color = '#F0FFFFFF', stroke = Kit.STROKE_BLUE, font = 'number', alignRight = true,
}
local castText = { color = '#F0FFFFFF', size = 14, font = 'number', baseline = 34 }

AV.styles.ffxiExpanded = {
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
        -- Raid only. Centred on the background (x 7..427); the text's bottom overlaps the
        -- background's top edge (y -11) by 3px, as the name overlaps the HP bar. Gold with a black
        -- shadow and no outline in Friz Quadrata: WoW's GameFontNormal look.
        groupNumber = { pos = { 217, -26 }, size = 18, color = '#FFD100FF', stroke = '#000000FF', outline = '', font = 'standard', alignCenter = true },
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
        -- bar (which keeps showing mana), from the HP bar's middle (x 83) to the power bar's end
        -- (x 278). Its line (row y 40.5..53) clears both numbers above. The row grows by
        -- formRowHeight while shifted.
        formRowHeight = 22,
        formBar = {
            pos = { 83, 15 },
            bar = Kit.wideBar(195, '#FFFF9CFF', '#FFFF9CFF'),
            txtValue = { pos = { 187, 34 }, size = 13, color = '#F0FFFFFF', stroke = Kit.STROKE_BLUE, font = 'number', alignRight = true },
        },
        -- Player row only. Pip 1 sits under the power bar's line (row y 18.5..31, fill from
        -- x 162). Steps keep dx == dy so facing 45-degree edges line up; the diamonds' ink is
        -- 14px, so |dx| + |dy| = 14 makes them touch; tighter merges them.
        comboPoints = {
            pos = { 161, 31 },
            size = { 16, 16 },
            offsets = { { 0, 0 }, { 7, -7 }, { 14, 0 }, { 21, -7 }, { 28, 0 } },
            fill = 'pips/diamondFill-16',
            outline = 'pips/diamondLine-16',
            color = '#FFD966FF',
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
        threat = { path = 'ffxi/Range', pos = { 30, 30 }, size = { 10, 10 } },
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
        buffs = { pos = { 284, -6 }, size = 18, spacing = 2, max = 6 },
        debuffs = { pos = { 284, 16 }, size = 18, spacing = 2, max = 6 },
        -- Pet sub-row at the bottom of the owner's row, which grows by rowHeight while the pet
        -- exists. A compact member row, in sub-row coordinates: name line on top, then HP and
        -- power side by side on VanaVista's short alliance bars (lines x 29.5..106.5 and
        -- 116.5..193.5, y 15..23), then happiness.
        pet = {
            rowHeight = 29,
            -- The art draws this far above the sub-row, tucking it under the owner's row; the
            -- sub-row's bottom then leaves the usual rowSpacing to the next member.
            shiftUp = 3,
            -- The job frame at 0.75 scale, its right edge on the HP line's start.
            portrait = { pos = { 1, 3 }, size = 27, inset = 3.5 },
            txtName = { pos = { 38, 1 }, width = 156, size = 12, color = '#F0FFFFFF', stroke = Kit.STROKE_BLUE },
            hp = {
                pos = { 4, -13 },
                bar = Kit.allyBar('#FF9597FF', '#FF9597FF'),
                txtValue = { pos = { 100, 34 }, size = 10, color = '#F0FFFFFF', stroke = Kit.STROKE_BLUE, font = 'number', alignRight = true },
                textColor = '#F0FFFFFF',
                thresholds = Kit.HP_THRESHOLDS,
            },
            -- Tinted with party.power.colors.
            power = {
                pos = { 91, -13 },
                bar = Kit.allyBar('#FFFF9CFF', '#FFFF9CFF'),
                txtValue = { pos = { 100, 34 }, size = 10, color = '#F0FFFFFF', stroke = Kit.STROKE_BLUE, font = 'number', alignRight = true },
            },
            -- Own pet only, replacing the name line while it casts, as members' cast bars do.
            -- Spans the HP line's start to the power line's end (x 29.5..193.5).
            cast = {
                pos = { 4, -25 },
                bar = Kit.allyBar('#6AB4F8FF', '#6AB4F8FF', 215),
                txtName = { pos = { 29, 24 }, width = 160, size = 10, color = '#F0FFFFFF', stroke = Kit.STROKE_BLUE, font = 'number' },
            },
            -- Own hunter pet only, right of the power bar.
            happiness = { pos = { 200, 10 }, size = { 20, 19 } },
            hover = { path = 'ffxi/Hover', pos = { 20, -6 }, size = { 390, 44 }, color = '#9C94E8AA' },
            -- Own pet only: debuffs then buffs in the party aura column, max of each.
            auras = { pos = { 284, 7 }, size = 18, spacing = 2, max = 3 },
        },
    },

    target = Kit.target({ frame = '#6AB4F8FF', fill = '#6AB4F8FF', text = castText }),
    castBar = Kit.castBar('#6AB4F8FF', '#6AB4F8FF', castText),
}
