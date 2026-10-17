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
        rowSpacing = 5,
        background = {
            color = '#FFFFFFDD',
            pos = { 7, -11 },
            width = 420,
            top = { path = 'ffxi/BgTop', height = 10 },
            mid = { path = 'ffxi/BgMid' },
            bottom = { path = 'ffxi/BgBottom', height = 8 },
        },
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
            pos = { -11, -2 },
            size = 36,
            bg = 'jobIcons/bg',
            gradient = 'jobIcons/gradient',
            frame = 'jobIcons/frame',
        },
        range = { farAlpha = 0.55 },
        -- Tinted with Blizzard's threat colours; hidden without threat.
        threat = { path = 'ffxi/Range', pos = { 30, 30 }, size = { 10, 10 } },
        hover = { path = 'ffxi/Hover', pos = { 20, -8 }, size = { 390, 60 }, color = '#9C94E8AA' },
        cursor = { path = 'ffxi/Cursor', pos = { -45, 4 }, size = { 37, 24 }, color = '#FFFFFFFF', onTop = true },
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
    },

    target = Kit.target({ frame = '#6AB4F8FF', fill = '#6AB4F8FF', text = castText }),
    castBar = Kit.castBar('#6AB4F8FF', '#6AB4F8FF', castText),
}
