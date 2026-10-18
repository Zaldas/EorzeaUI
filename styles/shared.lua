local _, EUI = ...

-- Building blocks shared by the style files. Values are VanaVista's, in 1440p pixels.

EUI.styles = EUI.styles or {}
local Kit = {}
EUI.StyleKit = Kit

Kit.STROKE_BLUE = '#062D54C8'
Kit.STROKE_RED = '#3B0B0BC8'
-- 1px edge around every aura icon (the icon is inset over this colour).
Kit.AURA_BORDER = '#4A4A4AFF'

-- Style.Header's grey line each side of a label, fading out toward the header's ends.
Kit.HEADER_LINE = { color = '#A0A0A0FF', alpha = 0.6, height = 2, gap = 8 }

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
-- flag: the AFK/DND badge on the name line, after any raid marker.
function Kit.partyIndicators(p, nameX, nameY)
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
        flag = { pos = { nameX, nameY + 1 }, size = { 38, 15 } },
        stateColor = '#A0A0A0FF',
        healPrediction = { color = p.heals, absorbColor = p.absorbs },
    }
end

-- Blizzard's frames tint the portrait red at 20% health or below.
Kit.LOW_HEALTH = { below = 0.2, color = '#FF0000FF' }

Kit.HP_THRESHOLDS = {
    { below = 0.25, color = '#FC8182FF' },
    { below = 0.50, color = '#F8BA80FF' },
    { below = 0.75, color = '#F3F37CFF' },
}

-- Spell name for the cast bars. text = { color, size, font, baseline, stroke }; baseline is the
-- text's bottom edge in bar pixels, shared so every name sits at the same height on its bar.
-- width (optional) truncates the name; yOffset (optional) shifts it from the shared baseline.
function Kit.castName(text, width, yOffset)
    return {
        pos = { 20, text.baseline - text.size + (yOffset or 0) },
        width = width,
        size = text.size,
        color = text.color,
        stroke = text.stroke,
        font = text.font,
    }
end

-- p: the palette (styles/palettes.lua); castText as in Kit.castName.
-- size = { bar, icon, name, hpp, cast, tot, totName, height, perLine, debuffs, buffs, label,
--         castHidesName, combo }: widths of the HP, cast and mini bars, the icon's side, text
-- sizes, the anchor height, the aura row's line length and maxes, an optional header label,
-- whether the name line hides while the unit casts, and whether combo points show. Everything
-- else is placed from these.
function Kit.target(p, castText, size)
    local barWidth, iconSize = size.bar, size.icon
    -- The icon is centred on y 28 (the name's top to the bar line's bottom), its right edge 5px
    -- before the fill.
    local iconX, iconY = 8 - iconSize, 28 - iconSize / 2
    local nameX, nameY, nameRight = 20, 32 - size.name, barWidth - 64
    -- The aura row's top; the click areas end there.
    local aurasY = 44
    local totX = barWidth + 23
    local bar = Kit.wideBar(barWidth, p.hp, p.hp)
    return {
        width = totX + size.tot,
        height = size.height,
        bar = bar,
        -- Keyed by the unit's reaction as Blizzard's target frame tracks it
        -- (UnitInfo.ReactionKey). They tint the separator and nameBg; the name too unless
        -- nameColor is set.
        reactionColors = p.reaction,
        nameColor = p.targetName,
        -- From under the icon, the icon art's height, fading like the separator to pad past the
        -- name's end (width is the cap). color, when set, replaces the reaction tint.
        nameBg = p.nameBg and {
            pos = { iconX + iconSize / 8, iconY + iconSize / 8 },
            width = nameRight - iconX - iconSize / 8,
            height = iconSize * 3 / 4,
            pad = 0,
            fadeMin = 40,
            color = p.nameBg.color,
            alpha = p.nameBg.alpha,
            leftAlpha = p.nameBg.leftAlpha,
        } or nil,
        -- Non-attackable NPCs: this line replaces the HP bar, over its fill area at the line's
        -- centre, in the reaction colour at `alpha` mid-line, fading to `leftAlpha` at the icon
        -- end and to 0 at the right.
        separator = { pos = { bar.fill.x, 31 }, width = bar.fill.width, height = 2, alpha = 0.6, leftAlpha = 0.4 },
        -- Class icon for players, portrait for NPCs, in the party job frame. inset keeps the
        -- party's 5px-at-40 ratio.
        icon = {
            pos = { iconX, iconY },
            size = iconSize,
            inset = iconSize / 8,
            bg = 'jobIcons/bg',
            gradient = 'jobIcons/gradient',
            frame = 'jobIcons/frame',
        },
        -- Corner bracket by UnitClassification on the icon's top-right, offset 4px up and right so
        -- its inner outline sits on the frame's outer edge. Unlisted classifications show none.
        -- The art is 56px in the canvas's top-right; drawn at the texture's 64px so both arms
        -- rasterise alike.
        tier = {
            pos = { iconX + iconSize + 4 - 64, iconY - 4 },
            size = 64,
            paths = { worldboss = 'tiers/boss', elite = 'tiers/elite', rareelite = 'tiers/rareElite', rare = 'tiers/rare' },
        },
        levelBadge = Kit.levelBadge,
        -- Straddles the icon's left edge in its lower half, as on the party rows.
        pvp = { pos = { iconX - 11, iconY + 22 }, size = { 22, 22 } },
        -- Your combo points on the unit (size.combo only): a zigzag left of the PvP badge, centred
        -- on the icon, filling upward from pip 1 at the bottom. Steps keep dx == dy so facing
        -- 45-degree edges line up; the diamonds' ink is 14px, so |dx| + |dy| = 14 makes them touch.
        comboPoints = size.combo and {
            pos = { iconX - 30, iconY + iconSize / 2 - 22 },
            size = { 16, 16 },
            offsets = { { 7, 28 }, { 0, 21 }, { 7, 14 }, { 0, 7 }, { 7, 0 } },
            fill = 'pips/diamondFill-16',
            outline = 'pips/diamondLine-16',
            color = p.combo,
        } or nil,
        -- Crown centred on the icon's top edge, as on the party rows.
        leader = { pos = { iconX + iconSize / 2 - 8, iconY - 8 }, size = { 16, 16 } },
        -- Secure click area: left-click targets, right-click opens the unit menu, hover shows the
        -- tooltip. Spans the icon and bar from the icon's top to the aura row's top.
        click = { pos = { iconX, iconY }, size = { barWidth - iconX, aurasY - iconY } },
        -- Your threat on the unit: a diamond on the icon's bottom-right corner, right of the
        -- level badge, tinted with Blizzard's threat colours, and the percent under HP% (raw, or
        -- lead while tanking).
        threat = { path = 'pips/diamondFill-16', pos = { 1.5, iconY + iconSize - 8.5 }, size = { 15, 15 } },
        txtThreat = { pos = { barWidth - 14, 38 }, size = 12, color = p.targetText, stroke = p.strokeAlt, font = 'number', alignRight = true },
        lowHealth = Kit.LOW_HEALTH,
        -- Replaces HP% while the unit is dead or unconscious.
        stateColor = '#A0A0A0FF',
        -- right: the name truncates there, clear of the HP% text.
        txtName = { pos = { nameX, nameY }, size = size.name, color = p.targetText, stroke = p.stroke, right = nameRight },
        -- Before the name, which shifts right while it shows; as on the party rows.
        raidMarker = { pos = { nameX, nameY + 1 }, size = { 16, 16 } },
        -- AFK/DND on players, after any raid marker.
        flag = { pos = { nameX, nameY + 1 }, size = { 38, 15 } },
        healPrediction = { color = p.heals, absorbColor = p.absorbs },
        txtHpp = { pos = { barWidth - 14, 20 }, size = size.hpp, color = p.targetText, stroke = p.strokeAlt, font = 'number', alignRight = true },
        -- Debuffs then buffs in one row, wrapping after perLine; lineSpacing leaves room for timers.
        -- dispelBorder: 'dispel' edges debuffs by dispel type; 'stealable' edges stealable buffs.
        auras = {
            pos = { 25, aurasY }, size = 22, spacing = 3, perLine = size.perLine, lineSpacing = 16, timers = true, border = Kit.AURA_BORDER,
            groups = {
                HARMFUL = { max = size.debuffs, dispelBorder = 'dispel', dispelColors = p.dispel },
                HELPFUL = { max = size.buffs, dispelBorder = 'stealable', dispelColors = { Magic = p.stealable } },
            },
        },
        -- Above the HP bar, its right end 70px before the bar's.
        cast = {
            pos = { barWidth - 70 - size.cast, -15 },
            bar = Kit.wideBar(size.cast, p.cast, p.cast),
            channelColor = p.channel,
            sparkColor = p.spark,
            txtName = Kit.castName(castText),
            hidesName = size.castHidesName,
            -- Interrupted or failed: the bar holds full in `color` for `hold` seconds.
            failure = { color = p.castFailure, hold = 1 },
            -- Casts that cannot be interrupted tint the whole bar and show VanaVista's lock left of it.
            uninterruptible = {
                color = p.uninterruptible,
                lock = { path = 'ffxi/lock', pos = { -2, 25 }, size = { 14, 14 }, color = '#FFFFFFFF' },
            },
        },
        attention = { path = 'ffxi/attention', pos = { barWidth + 8, 26 }, size = { 11, 12 }, color = '#FFFFFFFF' },
        -- Optional label centred from the icon to a third into the mini bar, its box ending 2px
        -- above the leader crown (top at iconY - 8), with header lines.
        header = size.label and {
            label = size.label,
            pos = { iconX, iconY - 24 },
            width = totX + size.tot / 3 - iconX,
            height = 14,
            txtLabel = { size = 14, color = p.targetText, stroke = p.stroke },
            line = Kit.HEADER_LINE,
        } or nil,
        -- The unit's target.
        tot = {
            pos = { totX, 0 },
            bar = Kit.wideBar(size.tot, p.hp, p.hp),
            txtName = { pos = { 20, 33 - size.totName }, size = size.totName, color = p.targetText, stroke = p.strokeAlt, right = size.tot - 14 },
            raidMarker = { pos = { 20, 18 }, size = { 15, 15 } },
            click = { pos = { 0, 10 }, size = { size.tot, aurasY - 10 } },
            -- Up to 4 debuffs under the bar, as Blizzard's target-of-target frame shows.
            auras = {
                pos = { 20, aurasY }, size = 16, spacing = 2, max = 4, border = Kit.AURA_BORDER,
                dispelBorder = 'dispel', dispelColors = p.dispel,
            },
        },
    }
end

function Kit.castBar(p, castText)
    local width = 467
    return {
        width = width,
        height = 64,
        bar = Kit.wideBar(width, p.cast, p.cast),
        channelColor = p.channel,
        sparkColor = p.spark,
        failure = { color = p.castFailure, hold = 1 },
        txtName = Kit.castName(castText),
    }
end
