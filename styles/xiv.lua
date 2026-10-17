local _, AV = ...

-- Ported from VanaVista layouts/styles/xivParty.lua, xivTargetbar.lua and xivCastbar.lua.
-- Positions are relative to the element that owns them, in 1440p pixels, y down.

local Kit = AV.StyleKit

local bar = Kit.rowBar('xiv', '#FFFFFFFF', '#FFFFFFFF', '#FFFFFFFF')
local valueText = {
    pos = { 120, 35 }, size = 13, color = '#F0FFFFFF', stroke = Kit.STROKE_BLUE, font = 'number', alignRight = true,
}
local castText = { color = '#E8C040FF', size = 17, baseline = 32 }

AV.styles.xiv = {
    fonts = Kit.FONTS,

    party = {
        width = 410,
        rowHeight = 46,
        background = {
            color = '#FFFFFFDD',
            pos = { 0, -21 },
            width = 377,
            top = { path = 'xiv/BgTop', height = 21 },
            mid = { path = 'xiv/BgMid' },
            bottom = { path = 'xiv/BgBottom', height = 21 },
        },
        hp = {
            pos = { 19, -7 },
            bar = bar,
            txtValue = valueText,
            textColor = '#F0FFFFFF',
            thresholds = Kit.HP_THRESHOLDS,
        },
        power = {
            pos = { 150, -7 },
            bar = bar,
            txtValue = valueText,
        },
        classIcon = {
            pos = { -11, -2 },
            size = 36,
            bg = 'jobIcons/bg',
            gradient = 'jobIcons/gradient',
            frame = 'jobIcons/frame',
        },
        leader = { path = 'xiv/Leader', pos = { -24, -8 }, size = { 24, 24 }, color = '#E6E159FF' },
        range = {
            near = { path = 'xiv/Range', pos = { 30, 28.5 }, size = { 14, 12 }, color = '#FFFFFFFF' },
            far = { path = 'xiv/RangeFar', pos = { 30, 28.5 }, size = { 14, 12 }, color = '#FFFFFFFF' },
            farAlpha = 0.55,
        },
        hover = { path = 'xiv/Hover', pos = { 20, -8 }, size = { 390, 60 }, color = '#FFFFFFAA' },
        cursor = { path = 'xiv/Cursor', pos = { 20, -8 }, size = { 390, 60 }, color = '#FFFFFFFF' },
        txtName = { pos = { 34, 1 }, width = 246, size = 17, color = '#F0FFFFFF', stroke = Kit.STROKE_BLUE },
        levelBadge = Kit.levelBadge,
        buffs = { pos = { 284, -6 }, size = 18, spacing = 2, max = 6 },
        debuffs = { pos = { 284, 16 }, size = 18, spacing = 2, max = 6 },
    },

    target = Kit.target({ frame = '#E8C040FF', fill = '#E2E2DBFF', text = castText }),
    castBar = Kit.castBar('#E8C040FF', '#E2E2DBFF', castText),
}
