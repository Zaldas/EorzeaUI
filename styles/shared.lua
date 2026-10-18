local _, AV = ...

-- Building blocks shared by the style files. Values are VanaVista's, in 1440p pixels.

AV.styles = AV.styles or {}
local Kit = {}
AV.StyleKit = Kit

Kit.STROKE_BLUE = '#062D54C8'
Kit.STROKE_RED = '#3B0B0BC8'
-- 1px edge around every aura icon (the icon is inset over this colour).
Kit.AURA_BORDER = '#4A4A4AFF'

-- Pastel takes on Blizzard's debuff-type colours, keyed by dispel type name. An aura with no
-- dispel type keeps the plain edge.
Kit.DISPEL_COLORS = {
    Magic = '#7FBFFFFF',
    Curse = '#C58CFFFF',
    Poison = '#8CD98CFF',
    Disease = '#D9B880FF',
    Bleed = '#FF9597FF',
}
-- Stealable buffs (always Magic): lighter than the Magic debuff edge.
Kit.STEALABLE_COLOR = '#BFE3FFFF'

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

-- VanaVista's short alliance bar (AllyBar*MP): a 128x64 frame whose line spans x 26..102,
-- y 28..36 (soft edge 23..105, 26..38), filled over x 27..101.
-- width (optional, default 128) three-slices the art; the line keeps 26px ends, the fill 27px.
-- Texture columns 56..199 are uniform, so 60px caps keep the rounded ends intact.
function Kit.allyBar(frameColor, fillColor, width)
    width = width or 128
    return {
        width = width,
        height = 64,
        slice = width ~= 128 and { texSize = { 256, 128 }, cap = 60 } or nil,
        bg = { path = 'ffxi/AllyBarBgMP', color = frameColor },
        fill = { path = 'ffxi/AllyBarMP', color = fillColor, x = 27, width = width - 54 },
        fg = { path = 'ffxi/AllyBarFgMP', color = frameColor },
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

-- name: unit names; standard: other WoW-default text (level numbers, raid group label).
Kit.FONTS = { name = 'Fonts\\FRIZQT__.TTF', number = 'grammara.ttf', timer = 'consola.ttf', standard = 'Fonts\\FRIZQT__.TTF' }

-- Level number on the class icon's bottom edge.
Kit.levelBadge = { size = { 32, 18 }, textSize = 13, textOffset = { 2, 0 }, color = '#FFFFFFFF', edge = 'BOTTOM', overlap = 0.5 }

-- Party row indicators, in row coordinates. The class icon spans x -13..27, y -4..36; its visible
-- frame edge is ~1.5px inside that.
-- nameX/nameY are the style's txtName pos; a raid marker takes that spot and shifts the name.
-- leader: crown on the icon's top edge; rowSpacing keeps it clear of the level number above.
-- assistant (upper) and masterLooter (lower): straddling the icon's right edge, mirroring
-- role/pvp on the left. Either one alone centres between the two slots.
-- rest/combat: player row only, on the icon's top-right corner. status: ready check, summon,
-- resurrect or phased, centred on the icon. role/pvp: straddling the icon's left edge.
-- tagColor: the [AFK]/[DND] prefix on the name.
function Kit.partyIndicators(nameX, nameY)
    return {
        leader = { pos = { 0, -10 }, size = { 14, 14 } },
        assistant = { pos = { 18, 2 }, size = { 14, 14 } },
        masterLooter = { pos = { 18, 17 }, size = { 14, 14 } },
        rest = { pos = { 16, -12 }, size = { 24, 24 } },
        combat = { pos = { 18, -8 }, size = { 18, 18 } },
        status = { pos = { -5, 4 }, size = { 24, 24 } },
        -- The summon atlases carry more padding; same centre as status.
        summon = { pos = { -9, 0 }, size = { 32, 32 } },
        raidMarker = { pos = { nameX, nameY + 1 }, size = { 16, 16 } },
        role = { pos = { -20, -1 }, size = { 16, 16 } },
        pvp = { pos = { -22, 15 }, size = { 20, 20 } },
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
        -- VanaVista's target name colours: FFXI's entity and claim colours, with WoW tapping
        -- standing in for claim.
        nameColors = {
            npc = '#66FF66FF',
            party = '#00FFFFFF',
            player = '#FFFFFFFF',
            unclaimed = '#FFFF66FF',
            claimed = '#FF6666FF',
            otherClaim = '#FF66FFFF',
            hostilePlayer = '#FF6666FF',
        },
        -- Non-attackable NPCs: this line replaces the HP bar, over its fill area (x 13..524)
        -- at the line's centre, in the name colour at `alpha` mid-line, fading to `leftAlpha`
        -- at the icon end and to 0 at the right.
        separator = { pos = { 13, 31 }, width = 511, height = 2, alpha = 0.6, leftAlpha = 0.4 },
        -- Class icon for players, portrait for NPCs, in the party job frame. Spans x -38..8,
        -- y 5..51, centred on the name's top to the bar line's bottom, its right edge 5px
        -- before the fill. inset keeps the party's 5px-at-40 ratio.
        icon = {
            pos = { -38, 5 },
            size = 46,
            inset = 5.75,
            bg = 'jobIcons/bg',
            gradient = 'jobIcons/gradient',
            frame = 'jobIcons/frame',
            -- Frame tint by UnitClassification; others keep the art's colour.
            classification = { worldboss = '#FFD100FF', elite = '#FFD100FF', rareelite = '#D0D8E8FF', rare = '#D0D8E8FF' },
        },
        levelBadge = Kit.levelBadge,
        -- Straddles the icon's left edge in its lower half, as on the party rows.
        pvp = { pos = { -49, 27 }, size = { 22, 22 } },
        -- Crown centred on the icon's top edge, as on the party rows.
        leader = { pos = { -23, -3 }, size = { 16, 16 } },
        -- Secure click area: left-click targets, right-click opens the unit menu, hover shows the
        -- tooltip. Spans the icon and bar from the icon's top to the debuff row's top.
        click = { pos = { -38, 5 }, size = { 575, 39 } },
        -- Your threat on the target: a diamond on the icon's top-right corner, tinted with
        -- Blizzard's threat colours, and the percent under HP% (raw, or lead while tanking).
        threat = { path = 'ffxi/Range', pos = { 3, 0 }, size = { 12, 12 } },
        txtThreat = { pos = { 523, 38 }, size = 12, color = '#C8C8C8FF', stroke = Kit.STROKE_RED, font = 'number', alignRight = true },
        lowHealth = { below = 0.2, color = '#FF0000FF' },
        txtName = { pos = { 20, 15 }, size = 17, color = '#C8C8C8FF', stroke = Kit.STROKE_BLUE },
        -- Before the name, which shifts right while it shows; as on the party rows.
        raidMarker = { pos = { 20, 16 }, size = { 16, 16 } },
        healPrediction = { color = '#7CFC8C80', absorbColor = '#DDEEFFB3' },
        txtHpp = { pos = { 523, 20 }, size = 14, color = '#C8C8C8FF', stroke = Kit.STROKE_RED, font = 'number', alignRight = true },
        -- dispelBorder: 'dispel' edges debuffs by dispel type; 'stealable' edges stealable buffs.
        debuffs = { pos = { 15, 44 }, size = 22, spacing = 3, max = 12, timers = true, border = Kit.AURA_BORDER, dispelBorder = 'dispel', dispelColors = Kit.DISPEL_COLORS },
        buffs = { pos = { 15, 82 }, size = 22, spacing = 3, max = 12, timers = true, border = Kit.AURA_BORDER, dispelBorder = 'stealable', dispelColors = { Magic = Kit.STEALABLE_COLOR } },
        cast = {
            pos = { 233, -15 },
            bar = Kit.wideBar(234, cast.frame, cast.fill),
            txtName = Kit.castName(cast.text),
            -- Interrupted or failed: the bar holds full in `color` for `hold` seconds.
            failure = { color = '#FF6666FF', hold = 1 },
            -- Casts that cannot be interrupted tint the whole bar.
            uninterruptible = { color = '#B4B4B4FF' },
        },
        attention = { path = 'ffxi/attention', pos = { 545, 26 }, size = { 11, 12 }, color = '#FFFFFFFF' },
        tot = {
            pos = { 560, 0 },
            bar = Kit.wideBar(226, '#FF9597FF', '#FF9597FF'),
            txtName = { pos = { 20, 17 }, size = 16, color = '#C8C8C8FF', stroke = Kit.STROKE_RED },
            raidMarker = { pos = { 20, 18 }, size = { 15, 15 } },
            click = { pos = { 0, 10 }, size = { 226, 34 } },
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
