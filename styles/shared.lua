local _, EUI = ...

-- Building blocks shared by the style files. Values are VanaVista's, in 1440p pixels.

EUI.styles = EUI.styles or {}
local Kit = {}
EUI.StyleKit = Kit

Kit.STROKE_BLUE = '#062D54C8'
Kit.STROKE_RED = '#3B0B0BC8'
-- 1px edge around every aura icon (the icon is inset over this colour).
Kit.AURA_BORDER = '#4A4A4AFF'

-- Style.Header's line each side of a label, fading out toward the header's ends; coloured with
-- the palette's label colour.
Kit.HEADER_LINE = { alpha = 0.6, height = 2, gap = 8 }

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
-- Blue-leaning silver for Blizzard's gold ring art, applied over the desaturated texture.
Kit.RING_SILVER = '#9DB8F0FF'

-- 128x64 party bar on a 256x128 texture; no slicing needed at uniform half scale.
-- art: asset folder, e.g. 'hud'
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
        bg = { path = 'hud/AllyBarBgMP', color = frameColor },
        fill = { path = 'hud/AllyBarMP', color = fillColor, x = 27, width = width - 54 },
        fg = { path = 'hud/AllyBarFgMP', color = frameColor },
    }
end

-- Wide bars three-slice the hud frame art: 30px texture caps on a 256x128 texture.
function Kit.wideBar(width, frameColor, fillColor)
    return {
        width = width,
        height = 64,
        slice = { texSize = { 256, 128 }, cap = 30 },
        bg = { path = 'hud/BarBG', color = frameColor },
        fill = { path = 'hud/Bar', color = fillColor, x = 13, width = width - 26 },
        fg = { path = 'hud/BarFG', color = frameColor },
    }
end

-- Font file per kind of text: name (unit names), header (frame labels), level (level numbers),
-- health (HP and power values, HP%, threat %, state text), cast (cast bar text), timer (aura
-- countdowns), count (aura stacks). Style.Text specs pick one with font; name is the default.
Kit.FONTS = {
    name = 'Fonts\\FRIZQT__.TTF',
    header = 'Fonts\\FRIZQT__.TTF',
    level = 'Fonts\\FRIZQT__.TTF',
    health = 'grammara.ttf',
    cast = 'grammara.ttf',
    timer = 'consola.ttf',
    count = 'grammara.ttf',
}

-- Blizzard's level skull (unknown levels, corpses); a palette's levelSkull replaces it.
Kit.LEVEL_SKULL = {
    atlas = 'UI-HUD-UnitFrame-Target-HighLevelTarget_Icon',
    path = 'Interface\\TargetingFrame\\UI-TargetingFrame-Skull',
}

-- Level number on the class icon's bottom edge.
function Kit.levelBadge(p)
    return {
        size = { 32, 18 }, textSize = 13, textOffset = { 2, 0 }, color = '#FFFFFFFF', edge = 'BOTTOM', overlap = 0.5,
        skull = p.levelSkull or Kit.LEVEL_SKULL,
    }
end

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

-- Raid cell indicators around the 34px class icon at (-10,2), which spans x -10..24, y 2..36.
-- The name and HP bar start 3px right of the icon, so ranks sit on its top and bottom edges:
-- leader or assistant (never both) centred on the top edge, master looter on the bottom edge.
-- role: straddling the left edge, centred. No PvP badge, as Blizzard's raid frames; rest/combat
-- never show on cells.
function Kit.raidIndicators(p, nameX, nameY)
    return {
        fixedRanks = true,
        leader = { pos = { -2, -5 }, size = { 18, 18 } },
        assistant = { pos = { -2, -5 }, size = { 18, 18 } },
        masterLooter = { pos = { -0.5, 28 }, size = { 15, 15 } },
        rest = { pos = { 14, -5 }, size = { 20, 20 } },
        combat = { pos = { 16, -1 }, size = { 15, 15 } },
        status = { pos = { -3, 9 }, size = { 20, 20 } },
        summon = { pos = { -7, 5 }, size = { 28, 28 } },
        raidMarker = { pos = { nameX, nameY }, size = { 12, 12 } },
        role = { pos = { -18, 11 }, size = { 16, 16 } },
        flag = { pos = { nameX, nameY + 1 }, size = { 28, 11 } },
        stateColor = '#A0A0A0FF',
        healPrediction = { color = p.heals, absorbColor = p.absorbs },
    }
end

-- One flow of auras in Blizzard's unit frame classes (AuraUtil.ProcessAura): debuffs you can
-- dispel, edged by dispel type; other debuffs, boss and role auras first; then buffs you cast that
-- others can have. Any group may fill the flow; perLine * lines caps the total and the rest are
-- clipped. Icons carry a cooldown swipe, as Blizzard's party and raid frames. Party rows follow
-- Blizzard's "only dispellable debuffs" CVar for party frames.
-- spec = { pos, size, spacing, perLine, lines, lineSpacing }
function Kit.groupAuras(p, spec)
    local total = spec.perLine * spec.lines
    return {
        pos = spec.pos, size = spec.size, spacing = spec.spacing, perLine = spec.perLine, lines = spec.lines,
        lineSpacing = spec.lineSpacing, max = total, clip = true, swipe = true, border = Kit.AURA_BORDER,
        processAuras = true, dispellableOnlyCVar = 'showDispelDebuffs',
        order = { 'dispel', 'debuffs', 'buffs' },
        groups = {
            dispel = { filter = 'HARMFUL', auraType = 'Dispel', max = total, sort = 'UnitFrameDebuff', dispelBorder = 'dispel', dispelColors = p.dispel },
            debuffs = { filter = 'HARMFUL', auraType = 'Debuff', max = total, sort = 'UnitFrameDebuff' },
            buffs = { filter = 'HELPFUL', auraType = 'Buff', max = total },
        },
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
--         castHidesName, combo, compact, totDebuffs, castNearIcon }: widths of the HP, cast and
-- mini bars, the icon's side, text sizes, the anchor height, the aura row's line length and
-- maxes (no debuffs: no aura row), an optional header label, whether the name line hides while
-- the unit casts, whether combo points show, the raid Assists cells' tighter spacing between the
-- HP bar, the attention arrow and the mini bar, the mini bar's debuff count (default 4), and
-- whether the cast bar starts beside the icon (else its right end is 70px before the bar's).
-- Everything else is placed from these.
function Kit.target(p, castText, size)
    local barWidth, iconSize = size.bar, size.icon
    -- The icon is centred on y 28 (the name's top to the bar line's bottom), its right edge 5px
    -- before the fill.
    local iconX, iconY = 8 - iconSize, 28 - iconSize / 2
    local nameX, nameY, nameRight = 20, 32 - size.name, barWidth - 64
    -- The aura row's top; the click areas end there.
    local aurasY = 44
    local auraSize, auraLineSpacing = 22, 16
    -- Compact: the arrow starts 4px after the HP line's end (11px inside a wide bar) and the mini
    -- bar's line 4px after the 11px arrow.
    local attentionX, totX = barWidth + 8, barWidth + 23
    if size.compact then
        attentionX = barWidth - 11 + 4
        totX = attentionX + 11 + 4 - 11
    end
    local totDebuffs = size.totDebuffs or 4
    -- castNearIcon: the uninterruptible lock (2px left of the bar) starts 6px past the icon's
    -- right edge, clear of the classification bracket's 4px overhang.
    local castX = size.castNearIcon and iconX + iconSize + 8 or barWidth - 70 - size.cast
    local bar = Kit.wideBar(barWidth, p.hp, p.hp)
    local levelBadge = Kit.levelBadge(p)
    -- Debuffs then buffs in one row, wrapping after perLine; lineSpacing leaves room for timers.
    -- dispelBorder: 'dispel' edges debuffs by dispel type; 'stealable' edges stealable buffs.
    -- Blizzard's target order: your auras first, then in the order they landed.
    -- hostileAuras replaces auras on hostile NPCs, as Blizzard's target frame filters them: your
    -- debuffs, other players' debuffs flagged for everyone (nameplateShowAll), and NPCs' debuffs;
    -- other players' remaining debuffs are hidden. Three disjoint groups share the debuff cap.
    local auras, hostileAuras
    if size.debuffs then
        local function auraRow(order, groups)
            return {
                pos = { 25, aurasY }, size = auraSize, spacing = 3, perLine = size.perLine, lineSpacing = auraLineSpacing,
                timers = true, border = Kit.AURA_BORDER, sort = 'Default', swipe = true, order = order, groups = groups,
            }
        end
        local function debuffs(filter, max, candidates)
            return { filter = filter, max = max, candidates = candidates, dispelBorder = 'dispel', dispelColors = p.dispel }
        end
        local buffs = { max = size.buffs, dispelBorder = 'stealable', dispelColors = { Magic = p.stealable } }
        auras = auraRow({ 'HARMFUL', 'HELPFUL' }, { HARMFUL = debuffs('HARMFUL', size.debuffs), HELPFUL = buffs })
        local others = math.max(1, math.floor(size.debuffs / 5))
        hostileAuras = auraRow({ 'mine', 'shared', 'npc', 'HELPFUL' }, {
            mine = debuffs('HARMFUL|PLAYER', size.debuffs - 2 * others, { nameplateShowAll = false }),
            shared = debuffs('HARMFUL', others, { isFromPlayerOrPlayerPet = true, nameplateShowAll = true }),
            npc = debuffs('HARMFUL', others, { isFromPlayerOrPlayerPet = false }),
            HELPFUL = buffs,
        })
    end
    -- Everything drawn, at full aura rows: combo points, PvP badge and icon on the left; the
    -- header, else the leader crown, on top; the level badge or the aura rows at the bottom.
    local left = size.combo and iconX - 30 or iconX - 11
    local top = size.label and iconY - 24 or iconY - 8
    local bottom = iconY + iconSize + levelBadge.size[2] * levelBadge.overlap
    if size.debuffs then
        local lines = math.ceil((size.debuffs + size.buffs) / size.perLine)
        bottom = math.max(bottom, aurasY + lines * (auraSize + auraLineSpacing))
    end
    return {
        width = totX + size.tot,
        height = size.height,
        -- Edit Mode handle (EditMode.Register's box).
        editBox = { left = -left, top = -top, right = 0, bottom = bottom - size.height },
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
        levelBadge = levelBadge,
        -- Quest bosses (UnitIsQuestBoss): Blizzard's quest badge on the icon's top-left corner.
        questBoss = {
            atlas = 'UI-HUD-UnitFrame-Target-PortraitOn-Boss-Quest',
            path = 'Interface\\TargetingFrame\\PortraitQuestBadge',
            pos = { iconX - 4, iconY - 4 },
            size = { 16, 16 },
        },
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
        txtThreat = { pos = { barWidth - 14, 38 }, size = 12, color = p.targetText, stroke = p.strokeAlt, font = 'health', alignRight = true },
        lowHealth = Kit.LOW_HEALTH,
        -- Replaces HP% while the unit is dead, unconscious or offline.
        stateColor = '#A0A0A0FF',
        -- The HP bar while the unit is offline.
        offlineColor = p.offline,
        -- right: the name truncates there, clear of the HP% text.
        txtName = { pos = { nameX, nameY }, size = size.name, color = p.targetText, stroke = p.stroke, right = nameRight },
        -- Before the name, which shifts right while it shows; as on the party rows.
        raidMarker = { pos = { nameX, nameY + 1 }, size = { 16, 16 } },
        -- AFK/DND on players, after any raid marker.
        flag = { pos = { nameX, nameY + 1 }, size = { 38, 15 } },
        healPrediction = { color = p.heals, absorbColor = p.absorbs },
        txtHpp = { pos = { barWidth - 14, 20 }, size = size.hpp, color = p.targetText, stroke = p.strokeAlt, font = 'health', alignRight = true },
        auras = auras,
        hostileAuras = hostileAuras,
        -- Above the HP bar.
        cast = {
            pos = { castX, -15 },
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
                lock = { path = 'hud/lock', pos = { -2, 25 }, size = { 14, 14 }, color = '#FFFFFFFF' },
            },
        },
        attention = { path = 'hud/attention', pos = { attentionX, 26 }, size = { 11, 12 }, color = '#FFFFFFFF' },
        -- Optional label centred from the icon to halfway along the mini bar, its box ending 2px
        -- above the leader crown (top at iconY - 8), with header lines.
        header = size.label and {
            label = size.label,
            pos = { iconX, iconY - 24 },
            width = totX + size.tot / 2 - iconX,
            height = 14,
            txtLabel = { size = 14, color = p.label, stroke = p.stroke, font = 'header' },
            line = { color = p.label, alpha = Kit.HEADER_LINE.alpha, height = Kit.HEADER_LINE.height, gap = Kit.HEADER_LINE.gap },
        } or nil,
        -- The unit's target.
        tot = {
            pos = { totX, 0 },
            bar = Kit.wideBar(size.tot, p.hp, p.hp),
            txtName = { pos = { 20, 33 - size.totName }, size = size.totName, color = p.targetText, stroke = p.strokeAlt, right = size.tot - 14 },
            raidMarker = { pos = { 20, 18 }, size = { 15, 15 } },
            -- DEAD, UNCONSCIOUS or OFFLINE at the bar's right end, on the name's line; the name
            -- ends 4px before it.
            txtState = { pos = { size.tot - 14, 33 - size.totName }, size = size.totName, color = '#A0A0A0FF', stroke = p.strokeAlt, font = 'health', alignRight = true },
            click = { pos = { 0, 10 }, size = { size.tot, aurasY - 10 } },
            -- Debuffs under the bar; Blizzard's target-of-target frame shows 4.
            auras = totDebuffs > 0 and {
                pos = { 20, aurasY }, size = 16, spacing = 2, max = totDebuffs, border = Kit.AURA_BORDER,
                dispelBorder = 'dispel', dispelColors = p.dispel, sort = 'Default', swipe = true,
            } or nil,
        },
    }
end

function Kit.castBar(p, castText)
    local width = 467
    local txtName = Kit.castName(castText)
    return {
        width = width,
        height = 64,
        -- Edit Mode handle (EditMode.Register's box): the spell name's top to the bar line's bottom
        -- (y 36 of the art).
        editBox = { top = -txtName.pos[2], bottom = -(64 - 36) },
        bar = Kit.wideBar(width, p.cast, p.cast),
        channelColor = p.channel,
        sparkColor = p.spark,
        failure = { color = p.castFailure, hold = 1 },
        txtName = txtName,
    }
end
