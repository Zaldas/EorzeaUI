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
            -- Raid only. Centred on the background (x 7..427) with header lines in the text's gold;
            -- the box ends 3px above the background's top edge (y -11). Gold with a black shadow and
            -- no outline in Friz Quadrata: WoW's GameFontNormal look.
            groupNumber = {
                pos = { 7, -32 },
                width = 420,
                height = 18,
                txtLabel = { size = 18, color = '#FFD200FF', stroke = '#000000FF', outline = '', font = 'standard' },
                line = { color = '#FFD200FF', alpha = Kit.HEADER_LINE.alpha, height = Kit.HEADER_LINE.height, gap = Kit.HEADER_LINE.gap },
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
            -- Tinted with Blizzard's threat colours; hidden without threat.
            threat = { path = 'pips/diamondFill-16', pos = { 29, 29 }, size = { 12, 12 } },
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
            levelBadge = Kit.levelBadge,
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
