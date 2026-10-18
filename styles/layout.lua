local _, EUI = ...

-- Ported from VanaVista layouts/styles/ffxiPartyExpanded.lua, ffxiTargetbar.lua and ffxiCastbar.lua.
-- The one frame layout; each style is this layout in a palette (styles/palettes.lua).

local Kit = EUI.StyleKit

function Kit.BuildLayout(p)
    local valueText = {
        pos = { 120, 34 }, size = 13, color = p.text, stroke = p.stroke, font = 'number', alignRight = true,
    }
    local smallValueText = { pos = { 100, 34 }, size = 10, color = p.text, stroke = p.stroke, font = 'number', alignRight = true }
    local castText = { color = p.text, size = 14, font = 'number', baseline = 34, stroke = p.stroke }
    -- A raid block's fade, from x 7 to 7 + width, with 7px over the first cell and 6 under the last.
    local function raidBackground(width)
        return {
            color = p.partyBg.color,
            alpha = p.partyBg.alpha,
            leftAlpha = p.partyBg.leftAlpha,
            pos = { 7, -7 },
            width = width,
            top = { height = 7 },
            bottom = { height = 6 },
        }
    end
    -- A raid block's label, centred on its background with header lines in the label colour, its
    -- box ending 3px above the background. A black shadow and no outline in Friz Quadrata: WoW's
    -- GameFontNormal look.
    local function raidLabel(width)
        return {
            pos = { 7, -24 },
            width = width,
            height = 14,
            txtLabel = { size = 14, color = p.label, stroke = '#000000FF', outline = '', font = 'standard' },
            line = { color = p.label, alpha = Kit.HEADER_LINE.alpha, height = Kit.HEADER_LINE.height, gap = Kit.HEADER_LINE.gap },
        }
    end

    return {
        fonts = Kit.FONTS,

        party = {
            width = 410,
            rowHeight = 46,
            rowSpacing = 13,
            -- A fade like the target's name background, behind the rows plus top/bottom padding.
            background = {
                color = p.partyBg.color,
                alpha = p.partyBg.alpha,
                leftAlpha = p.partyBg.leftAlpha,
                pos = { 7, -11 },
                width = 420,
                top = { height = 10 },
                bottom = { height = 8 },
            },
            lowHealth = Kit.LOW_HEALTH,
            hp = {
                pos = { 19, -7 },
                bar = Kit.rowBar('ffxi', p.hp, p.hp),
                txtValue = valueText,
                textColor = p.text,
                thresholds = p.hpThresholds,
                offlineColor = p.offline,
            },
            power = {
                pos = { 150, -7 },
                bar = Kit.rowBar('ffxi', p.power, p.power),
                txtValue = valueText,
                -- Keyed by UnitPowerType: 0 mana, 1 rage, 2 focus, 3 energy. Others keep the bar colour.
                colors = p.powerColors,
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
                bar = Kit.wideBar(156, p.power, p.power),
                txtValue = { pos = { 148, 34 }, size = 13, color = p.text, stroke = p.stroke, font = 'number', alignRight = true },
            },
            classIcon = {
                pos = { -13, -4 },
                size = 40,
                bg = 'jobIcons/bg',
                gradient = 'jobIcons/gradient',
                frame = 'jobIcons/frame',
            },
            -- notPresentAlpha: phased or in another group, as Blizzard's party frames fade them.
            range = { farAlpha = 0.5, notPresentAlpha = 0.6 },
            -- On the icon's bottom-right corner right of the level badge, as on the target, scaled to
            -- the 40px icon. Tinted with Blizzard's threat colours; hidden without threat.
            threat = { path = 'pips/diamondFill-16', pos = { 23.5, 28.5 }, size = { 13, 13 } },
            hover = { path = 'ffxi/Hover', pos = { 20, -8 }, size = { 390, 60 }, color = '#9C94E8AA' },
            cursor = { path = 'ffxi/Cursor', pos = { -47, 4 }, size = { 37, 24 }, color = '#FFFFFFFF', onTop = true },
            txtName = { pos = { 38, 3 }, width = 242, size = 17, color = p.name, stroke = p.stroke },
            -- Replaces the name row while the member casts, spanning the HP and power bars (x 19..278).
            -- Spell name in the target cast bar's text style, 1px higher on the bar.
            cast = {
                pos = { 19, -19 },
                bar = Kit.wideBar(259, p.cast, p.cast),
                channelColor = p.channel,
                sparkColor = p.spark,
                failure = { color = p.castFailure, hold = 1 },
                txtName = Kit.castName(castText, 219, -1),
            },
            levelBadge = Kit.levelBadge(p),
            indicators = Kit.partyIndicators(p, 38, 3),
            buffs = { pos = { 284, -6 }, size = 18, spacing = 2, max = 6, border = Kit.AURA_BORDER },
            -- dispelBorder: edges debuffs by dispel type, as on the target.
            debuffs = {
                pos = { 284, 16 }, size = 18, spacing = 2, max = 6, border = Kit.AURA_BORDER,
                dispelBorder = 'dispel', dispelColors = p.dispel,
            },
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
                txtName = { pos = { 61, 1 }, width = 156, size = 12, color = p.name, stroke = p.stroke },
                hp = {
                    pos = { 27, -13 },
                    bar = Kit.allyBar(p.hp, p.hp),
                    txtValue = smallValueText,
                    textColor = p.text,
                    thresholds = p.hpThresholds,
                },
                -- Tinted with party.power.colors.
                power = {
                    pos = { 114, -13 },
                    bar = Kit.allyBar(p.power, p.power),
                    txtValue = smallValueText,
                },
                -- Own pet only, replacing the name line while it casts, as members' cast bars do.
                -- Spans the HP line's start to the power line's end (x 52.5..216.5).
                cast = {
                    pos = { 27, -25 },
                    bar = Kit.allyBar(p.cast, p.cast, 215),
                    channelColor = p.channel,
                    sparkColor = p.spark,
                    failure = { color = p.castFailure, hold = 1 },
                    txtName = { pos = { 29, 24 }, width = 160, size = 10, color = p.text, stroke = p.stroke, font = 'number' },
                },
                -- Own hunter pet only, right of the power bar.
                happiness = { pos = { 223, 10 }, size = { 20, 19 } },
                hover = { path = 'ffxi/Hover', pos = { 20, -6 }, size = { 390, 44 }, color = '#9C94E8AA' },
                -- Points at the portrait (x 24..51, y 3..30) as the member cursor does at the class icon.
                cursor = { path = 'ffxi/Cursor', pos = { -10, 5 }, size = { 37, 24 }, color = '#FFFFFFFF' },
                -- Own pet only: debuffs then buffs in the party aura column, max of each.
                auras = { pos = { 284, 7 }, size = 18, spacing = 2, max = 3, border = Kit.AURA_BORDER },
            },
        },

        -- Raid groups: one block of up to 5 cells per subgroup, laid out groupsPerRow to a row in
        -- group order. Cells are ported from VanaVista layouts/styles/ffxiAlliance.lua: the name
        -- line with the HP value at its right end, the HP bar under it and the short MP bar below
        -- that, right of a 34px class icon. One aura line runs under the bars.
        raid = {
            width = 168,
            rowHeight = 45,
            rowSpacing = 4,
            groupsPerRow = 4,
            -- Between blocks: x from one background's right edge (or the cursor's overhang) to the
            -- next, y from one block's bottom padding to the next header.
            groupSpacing = { 8, 14 },
            background = raidBackground(165),
            -- "Group N".
            groupNumber = raidLabel(165),
            -- Main tanks then main assists (raid roles), each cell followed by its target and that
            -- unit's target, as Blizzard's raid frames list them above the groups. Own mover.
            assists = {
                label = 'Assists',
                max = 8,
                -- Over the cell and both target cells (x 7..396).
                background = raidBackground(389),
                groupNumber = raidLabel(389),
                target = {
                    width = 120,
                    -- Each target cell's left edge from the member cell's. Each bar's line starts 4px
                    -- after the attention arrow, which starts 4px after the previous bar's line
                    -- (the cell's HP line ends at x 147).
                    x = { 155, 272 },
                    -- The target bar's arrow toward the ToT, before this cell's bar line (x 11),
                    -- centred on it.
                    attention = { path = 'ffxi/attention', pos = { -4, 9 }, size = { 11, 12 }, color = '#FFFFFFFF' },
                    hp = {
                        pos = { 0, -17 },
                        bar = Kit.wideBar(120, p.hp, p.hp),
                        -- Dead only.
                        txtValue = { pos = { 106, 22 }, size = 10, color = '#A0A0A0FF', stroke = p.stroke, font = 'number', alignRight = true },
                    },
                    -- Starts over the HP bar's line, as on the cells.
                    txtName = { pos = { 11, 0 }, width = 95, size = 12, color = p.text, stroke = p.stroke },
                    raidMarker = { pos = { 11, 0 }, size = { 12, 12 } },
                    hover = { path = 'ffxi/Hover', pos = { 0, -6 }, size = { 120, 57 }, color = '#9C94E8AA' },
                    -- Names by reaction, as the target bar's; nameColor (optional) overrides them all.
                    reactionColors = p.reaction,
                    nameColor = p.targetName,
                },
            },
            -- Raid pets: Blizzard keeps them in their own section after the groups; ours is its own
            -- block with its own mover. The party pet row's portrait beside the raid cell's name and
            -- bars (txtName, hp, power), in columns of perColumn at the group columns' spacing. No
            -- auras, as on Blizzard's pet frames.
            pets = {
                label = 'Pets',
                max = 40,
                perColumn = 10,
                rowHeight = 32,
                -- The party pet portrait, its right edge on the cells' class icon's (x 24).
                portrait = { pos = { -3, 2 }, size = 27, inset = 3.5 },
                hover = { path = 'ffxi/Hover', pos = { 18, -6 }, size = { 156, 44 }, color = '#9C94E8AA' },
                -- Tip on the portrait's left edge, centred, as on the cells.
                cursor = { path = 'ffxi/Cursor', pos = { -35, 4 }, size = { 35, 23 }, color = '#FFFFFFFF' },
            },
            lowHealth = Kit.LOW_HEALTH,
            -- The bar's line starts under the name (x 27) and keeps VanaVista's right end.
            hp = {
                pos = { 16, -17 },
                bar = Kit.wideBar(142, p.hp, p.hp),
                txtValue = { pos = { 128, 22 }, size = 10, color = p.text, stroke = p.stroke, font = 'number', alignRight = true },
                textColor = p.text,
                thresholds = p.hpThresholds,
                offlineColor = p.offline,
            },
            -- Its line ends 10px before the HP bar's (x 137 vs 147). No value, as on Blizzard's raid
            -- frames.
            power = {
                pos = { 35, -8 },
                bar = Kit.allyBar(p.power, p.power),
                colors = p.powerColors,
            },
            classIcon = {
                pos = { -10, 2 },
                size = 34,
                bg = 'jobIcons/bg',
                gradient = 'jobIcons/gradient',
                frame = 'jobIcons/frame',
            },
            range = { farAlpha = 0.5, notPresentAlpha = 0.6 },
            -- On the icon's bottom-right corner, as on the target.
            threat = { path = 'pips/diamondFill-16', pos = { 19, 29 }, size = { 12, 12 } },
            hover = { path = 'ffxi/Hover', pos = { 18, -6 }, size = { 156, 57 }, color = '#9C94E8AA' },
            -- Placed against the icon as on the party rows: tip on its left edge, centred.
            cursor = { path = 'ffxi/Cursor', pos = { -42, 7.5 }, size = { 35, 23 }, color = '#FFFFFFFF', onTop = true },
            -- Ends before the HP value on the same line.
            txtName = { pos = { 27, 0 }, width = 73, size = 12, color = p.name, stroke = p.stroke },
            indicators = Kit.raidIndicators(p, 27, 0),
            -- One line under the bars, from the threat diamond's right edge. Blizzard's raid frame
            -- classes (AuraUtil.ProcessAura): debuffs with boss and role auras first, then debuffs
            -- you can dispel, then buffs you cast that others can have. Blizzard shows 5, 3 and 6;
            -- buffs are cut to fit the line. max: the demo's total.
            auras = {
                pos = { 31, 31 }, size = 12, spacing = 1, max = 11, border = Kit.AURA_BORDER,
                -- Debuffs only; buffs keep the plain edge.
                dispelBorder = 'dispel', dispelColors = p.dispel,
                processAuras = true,
                order = { 'debuffs', 'dispel', 'buffs' },
                groups = {
                    debuffs = { filter = 'HARMFUL', auraType = 'Debuff', max = 5, sort = 'UnitFrameDebuff' },
                    dispel = { filter = 'HARMFUL', auraType = 'Dispel', max = 3, sort = 'UnitFrameDebuff' },
                    buffs = { filter = 'HELPFUL', auraType = 'Buff', max = 3 },
                },
            },
        },

        -- Maxes match Blizzard's target frame (16 debuffs, 32 buffs): at most 3 lines.
        target = Kit.target(p, castText, {
            bar = 537, icon = 46, name = 17, hpp = 14, cast = 234, tot = 226, totName = 16,
            height = 120, perLine = 16, debuffs = 16, buffs = 32, combo = true,
        }),
        -- HP bar half the target's; the party's 40px icon. 16 auras at most, 8 per line; the
        -- containers cannot cap a total, so each group gets half. The cast bar covers most of the
        -- name line, so the name hides while it shows.
        focus = Kit.target(p, castText, {
            bar = 268, icon = 40, name = 15, hpp = 13, cast = 160, tot = 180, totName = 14,
            height = 100, perLine = 8, debuffs = 8, buffs = 8, label = 'Focus', castHidesName = true,
        }),
        castBar = Kit.castBar(p, castText),
    }
end
