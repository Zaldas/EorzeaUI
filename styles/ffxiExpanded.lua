local _, AV = ...

-- Ported from VanaVista layouts/styles/ffxiPartyExpanded.lua, ffxiTargetbar.lua and ffxiCastbar.lua.
-- Same row geometry as xiv; FFXI art and colours.

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
            bar = Kit.rowBar('ffxi', '#FF9597FF', '#FF9597FF', '#FFF2F2FF'),
            txtValue = valueText,
            textColor = '#F0FFFFFF',
            thresholds = Kit.HP_THRESHOLDS,
        },
        power = {
            pos = { 150, -7 },
            bar = Kit.rowBar('ffxi', '#FFFF9CFF', '#FFFF9CFF', '#FFFFF2FF'),
            txtValue = valueText,
        },
        classIcon = {
            pos = { -11, -2 },
            size = 36,
            bg = 'jobIcons/bg',
            gradient = 'jobIcons/gradient',
            frame = 'jobIcons/frame',
        },
        leader = { path = 'ffxi/Leader', pos = { 28, 10 }, size = { 7, 5 }, color = '#E6E159FF' },
        range = {
            near = { path = 'ffxi/Range', pos = { 30, 30 }, size = { 10, 10 }, color = '#FFFFFFFF' },
            far = { path = 'ffxi/RangeFar', pos = { 30, 30 }, size = { 10, 10 }, color = '#FFFFFFFF' },
            farAlpha = 0.55,
        },
        hover = { path = 'ffxi/Hover', pos = { 20, -8 }, size = { 390, 60 }, color = '#9C94E8AA' },
        cursor = { path = 'ffxi/Cursor', pos = { -38, 4 }, size = { 37, 24 }, color = '#FFFFFFFF' },
        txtName = { pos = { 38, 3 }, width = 242, size = 17, color = '#F0FFFFFF', stroke = Kit.STROKE_BLUE },
        levelBadge = Kit.levelBadge,
        buffs = { pos = { 284, -6 }, size = 18, spacing = 2, max = 6 },
        debuffs = { pos = { 284, 16 }, size = 18, spacing = 2, max = 6 },
    },

    target = Kit.target({ frame = '#6AB4F8FF', fill = '#6AB4F8FF', text = castText }),
    castBar = Kit.castBar('#6AB4F8FF', '#6AB4F8FF', castText),
}
