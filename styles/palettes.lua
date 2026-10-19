local _, EUI = ...

-- Each style is the layout (styles/layout.lua) in one of these palettes.
-- stroke: text shadow; strokeAlt: shadow on target HP%, threat % and the ToT name.
-- channel (optional): cast bar colour while channeling; casts otherwise. spark (optional): tints
-- the cast bar spark.
-- offline: party HP bar colour while the member is offline.
-- levelSkull (optional): { atlas, path } art for the level skull; atlas wins when the client has
-- it, path is an asset (relative to assets/) or a game texture.
-- heals / absorbs: incoming-heal and absorb segments on HP bars. combo: combo point pips.
-- reaction: keyed as targetBar.lua reactionKey returns. targetName (optional): one colour for
-- target names in place of the reaction colour. nameBg (optional): { alpha, leftAlpha, color }.
-- partyBg: the party list's fade, { color, alpha, leftAlpha }.
-- label: frame labels (Group N, Assists, Pets, Focus) and their header lines.
-- healthColor: party and raid HP bars by default (settings healthColor.<style>): 'blizzard'
-- (Blizzard's raid frame class colour setting), 'class' or 'palette' (hp).

local Kit = EUI.StyleKit

-- VanaVista's colours. Reaction colours are FFXI's name colours, with tapped as another
-- party's claim.
local vanadiel = {
    stroke = Kit.STROKE_BLUE,
    strokeAlt = Kit.STROKE_RED,
    text = '#F0FFFFFF',
    name = '#F0FFFFFF',
    targetText = '#C8C8C8FF',
    hp = '#FF9597FF',
    hpThresholds = Kit.HP_THRESHOLDS,
    offline = '#808080FF',
    heals = '#7CFC8C80',
    absorbs = '#DDEEFFB3',
    power = '#FFFF9CFF',
    powerColors = { [0] = '#8FB8FFFF', [1] = '#FF7A5CFF', [2] = '#FFB870FF', [3] = '#FFFF9CFF' },
    cast = '#6AB4F8FF',
    spark = '#E0F2FFFF',
    castFailure = '#FF6666FF',
    uninterruptible = '#B4B4B4FF',
    dispel = Kit.DISPEL_COLORS,
    stealable = Kit.STEALABLE_COLOR,
    reaction = {
        party = '#00FFFFFF',
        partyPvP = '#00FFFFFF',
        player = '#FFFFFFFF',
        hostilePlayer = '#FF6666FF',
        friendly = '#66FF66FF',
        neutral = '#FFFF66FF',
        unfriendly = '#FFA366FF',
        hostile = '#FF6666FF',
        tapped = '#FF66FFFF',
    },
    nameBg = { color = '#000000FF', alpha = 0.3, leftAlpha = 0.45 },
    combo = '#FFD966FF',
    partyBg = { color = '#000000FF', alpha = 0.2, leftAlpha = 0.3 },
    -- Bluish silver.
    label = '#A6BCE3FF',
    healthColor = 'palette',
}

-- Blizzard's default colours, as the Forever client reports them: PowerBarColor,
-- UnitSelectionColor, DEBUFF_TYPE_*_COLOR and NORMAL_FONT_COLOR names. heals colours everyone's
-- incoming heals in MyHealPrediction's colour; combo is COMBO_POINTS. Cast bar colours are the
-- average shade of Forever's ui-castingbar-* atlases.
local azeroth = {
    stroke = '#000000C8',
    strokeAlt = '#000000C8',
    text = '#FFFFFFFF',
    name = '#FFD200FF',
    targetText = '#FFFFFFFF',
    hp = '#00FF00FF',
    hpThresholds = {},
    offline = '#808080FF',
    heals = '#0B8869FF',
    absorbs = '#DDEEFFB3',
    power = '#FFFF00FF',
    powerColors = { [0] = '#0000FFFF', [1] = '#FF0000FF', [2] = '#FF8040FF', [3] = '#FFFF00FF' },
    cast = '#EFD53FFF',
    channel = '#6FC01AFF',
    castFailure = '#D84448FF',
    uninterruptible = '#BDB4A0FF',
    dispel = { Magic = '#0081FFFF', Curse = '#9F06E4FF', Poison = '#7BC700FF', Disease = '#F16A09FF' },
    stealable = Kit.STEALABLE_COLOR,
    reaction = {
        party = '#0000FFFF',
        partyPvP = '#00FF00FF',
        player = '#0000FFFF',
        hostilePlayer = '#FF0000FF',
        friendly = '#00FF00FF',
        neutral = '#FFFF00FF',
        unfriendly = '#FF8000FF',
        hostile = '#FF0000FF',
        tapped = '#808080FF',
    },
    targetName = '#FFD200FF',
    nameBg = { alpha = 0.4, leftAlpha = 0.5 },
    combo = '#FFF569FF',
    partyBg = { color = '#000000FF', alpha = 0.2, leftAlpha = 0.3 },
    -- NORMAL_FONT_COLOR, as on Blizzard's raid group titles.
    label = '#FFD200FF',
    healthColor = 'blizzard',
}

Kit.PALETTES = { vanadiel = vanadiel, azeroth = azeroth }

-- base with overrides over it; nested tables (reaction, powerColors) merge by key. Saved keys are
-- strings ('0' from the path colors.<style>.powerColors.0), so they map onto base's number keys.
local function overlay(base, overrides)
    local out = EUI.Settings.Copy(base)
    for key, value in pairs(overrides) do
        if out[key] == nil and tonumber(key) and out[tonumber(key)] ~= nil then
            key = tonumber(key)
        end
        if type(value) == 'table' and type(out[key]) == 'table' then
            out[key] = overlay(out[key], value)
        else
            out[key] = value
        end
    end
    return out
end

-- The named style with overrides (palette keys) over its palette.
-- style.palette names the palette it was built from.
function Kit.BuildStyle(name, overrides)
    local style = Kit.BuildLayout(overlay(Kit.PALETTES[name], overrides or {}))
    style.palette = name
    return style
end

for name, palette in pairs(Kit.PALETTES) do
    EUI.styles[name] = Kit.BuildLayout(palette)
end
