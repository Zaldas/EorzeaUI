local _, EUI = ...

-- Every user option: its saved path and default, how it reaches the built style, and where the
-- settings window shows it. apply(style, value) writes into the style spec; elements read those
-- fields (hidden, disabled, textMode, show, ...) at update time, so live options take effect
-- through their refresh. Options marked reload are read when the frames are built.

EUI.Config = EUI.Config or {}
local Config = EUI.Config
local Settings = EUI.Settings
local Kit = EUI.StyleKit

local defs = {}
local reloadPaths = {}

-- def = { path, default, reload, combat, label, apply(style, value), refresh (REFRESH key), blizzard }
-- combat: the change moves secure frames, so in combat it waits for combat to end.
-- blizzard = { cvars, read() }: the value 'blizzard' applies read()'s value, re-read when one of
-- cvars changes.
local function option(def)
    if def.blizzard then
        local apply = def.apply
        def.apply = function(style, value)
            if value == 'blizzard' then
                value = def.blizzard.read()
            end
            apply(style, value)
        end
    end
    if def.default ~= nil then
        Settings.Declare(def.path, def.default)
    end
    defs[#defs + 1] = def
    if def.reload then
        reloadPaths[#reloadPaths + 1] = def.path
    end
    return def
end

function Config.ReloadPaths()
    return reloadPaths
end

-- The name the reload bar uses for a reload option.
function Config.ReloadLabel(path)
    for _, def in ipairs(defs) do
        if def.path == path then
            return def.label or path
        end
    end
    return path
end

-- Every option definition, in declaration order.
function Config.Options()
    return defs
end

local function forTargets(style, fn)
    fn(style.target)
    fn(style.focus)
    fn(style.boss)
end

-- Gives each section its own copy of tables the layout shares across sections and styles.
local function ownTables(style)
    if style.ownTables then
        return
    end
    style.ownTables = true
    style.fonts = Settings.Copy(style.fonts)
    style.party.lowHealth = Settings.Copy(style.party.lowHealth)
    style.raid.lowHealth = Settings.Copy(style.raid.lowHealth)
    forTargets(style, function(spec)
        spec.lowHealth = Settings.Copy(spec.lowHealth)
    end)
end

local REFRESH = {
    rows = function()
        EUI.PartyList.RefreshAll()
        EUI.RaidList.RefreshAll()
        EUI.RaidPets.RefreshAll()
    end,
    bars = function()
        EUI.TargetBar.ForEach(function(bar)
            bar:Refresh()
        end)
    end,
    rowsAndBars = function()
        EUI.PartyList.RefreshAll()
        EUI.PartyList.ForEachVisiblePet(function(pet)
            pet:Refresh()
        end)
        EUI.RaidList.RefreshAll()
        EUI.RaidPets.RefreshAll()
        EUI.TargetBar.ForEach(function(bar)
            bar:Refresh()
        end)
    end,
    hostile = function()
        EUI.TargetBar.ForEach(function(bar)
            bar.hostileNpc = nil
            bar:UpdateAuraFilter()
        end)
    end,
    raidSections = function()
        EUI.RaidList.ApplyManagerFilters()
    end,
    auraPolicy = function()
        EUI.AuraRow.OnCVarChanged(nil)
    end,
    playerCast = function()
        EUI.playerCast:Update()
    end,
    scale = function()
        EUI.ApplyScale()
    end,
    raidLayout = function()
        EUI.RaidList.ApplyLayoutSize()
    end,
    raidSpacing = function()
        EUI.RaidList.ApplySpacing()
    end,
    raidLabels = function()
        EUI.RaidList.ApplyLabels()
    end,
    partyLayout = function()
        EUI.PartyList.ApplyLayout()
    end,
}

-- Shown samples are drawn once; redraw them after a live change.
local function redrawDemo()
    EUI.Demo.Redraw()
end

---------------------------------------------------------------------------------------------
-- Options

local HP_TEXT = {
    { 'current', 'Current', 'Current health, as 12,480.' },
    { 'missing', 'Missing', 'Health missing, as -1,240; blank at full health.' },
    { 'percent', 'Percent', 'Health percent, as 87%.' },
    { 'none', 'None', 'No HP number; the bar only.' },
}
local FOLLOW = {
    { 'blizzard', 'Blizzard', "Follow Blizzard's own option for its frames." },
    { 'on', 'On', 'Only debuffs you can dispel.' },
    { 'off', 'Off', 'Every debuff.' },
}
local SECTION_SHOW = {
    { 'blizzard', 'Blizzard', "Follow the raid manager's Hide button and filters." },
    { 'show', 'Show', 'Always shown in a raid.' },
    { 'hide', 'Hide', 'Never shown.' },
}
local BUFFS = {
    { 'blizzard', 'Blizzard', "Only buffs you or your pet cast that can go on others, as Blizzard's group frames." },
    { 'all', 'All Buffs', 'Every buff on the unit. 12 party slots fill fast in raids.' },
}

local function readCVar(name)
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    if not get then
        return nil
    end
    local ok, value = pcall(get, name)
    return ok and value or nil
end

-- Blizzard's status text (Interface > Status Text) and raid frame health text; it has no mode
-- for both, which reads as current. Unreadable values fall back to current.
local STATUS_TEXT = { NUMERIC = 'current', PERCENT = 'percent', BOTH = 'current', NONE = 'none' }
local RAID_HEALTH_TEXT = { health = 'current', losthealth = 'missing', perc = 'percent', none = 'none' }

local function followValue(value)
    if value == 'on' then
        return true
    elseif value == 'off' then
        return false
    end
    return nil
end

-- Party and raid rows share these indicator toggles, keyed as in Kit.partyIndicators.
local INDICATORS = {
    { 'leader', 'Leader Crown' },
    { 'assistant', 'Assistant and Master Looter', nil, { 'assistant', 'masterLooter' } },
    { 'role', 'Role Icon' },
    { 'pvp', 'PvP Badge', 'On the class icon or portrait. Raid cells have none.' },
    { 'raidMarker', 'Raid Marker' },
    { 'flag', 'AFK / DND Tag' },
    { 'status', 'Centre Status Icon', 'Ready check, summon, resurrection, phased and other-group icons.' },
    { 'rest', 'Resting and Combat Icons', 'Your own row only.' },
}
for _, entry in ipairs(INDICATORS) do
    local keys = entry[4] or { entry[1] }
    entry.def = option({
        path = 'indicators.' .. entry[1],
        default = true,
        refresh = 'rowsAndBars',
        -- Target, focus and boss bars carry the leader, PvP, raid marker and flag specs at their
        -- top level; the target-of-target name has its own marker.
        apply = function(style, value)
            local sections = { style.party.indicators, style.raid.indicators, style.target, style.focus, style.boss }
            for _, section in ipairs(sections) do
                for _, key in ipairs(keys) do
                    if section[key] then
                        section[key].hidden = not value
                    end
                end
            end
            if entry[1] == 'raidMarker' then
                forTargets(style, function(spec)
                    spec.tot.raidMarker.hidden = not value
                end)
            end
        end,
    })
end

option({ path = 'indicators.threat', default = true, refresh = 'rowsAndBars', apply = function(style, value)
    style.party.threat.hidden = not value
    style.party.pet.threat.hidden = not value
    style.raid.threat.hidden = not value
    forTargets(style, function(spec)
        spec.threat.hidden = not value
    end)
end })
option({ path = 'indicators.healPrediction', default = true, refresh = 'rowsAndBars', apply = function(style, value)
    style.party.indicators.healPrediction.hidden = not value
    style.raid.indicators.healPrediction.hidden = not value
    forTargets(style, function(spec)
        spec.healPrediction.hidden = not value
    end)
end })
option({ path = 'indicators.lowHealth', default = true, refresh = 'rowsAndBars', apply = function(style, value)
    style.party.lowHealth.hidden = not value
    style.raid.lowHealth.hidden = not value
    forTargets(style, function(spec)
        spec.lowHealth.hidden = not value
    end)
end })

option({ path = 'party.hpText', default = 'current', refresh = 'rows',
    blizzard = { cvars = { 'statusTextDisplay' }, read = function()
        return STATUS_TEXT[readCVar('statusTextDisplay')] or 'current'
    end },
    apply = function(style, value)
    style.party.hp.textMode = value
end })
option({ path = 'party.castBars', default = true, refresh = 'rows', apply = function(style, value)
    style.party.cast.disabled = not value
end })
option({ path = 'party.petCast', default = true, refresh = 'rows', apply = function(style, value)
    style.party.pet.cast.disabled = not value
end })
option({ path = 'party.farAlpha', default = 0.5, apply = function(style, value)
    style.party.range.farAlpha = value
end })
option({ path = 'party.notPresentAlpha', default = 0.6, apply = function(style, value)
    style.party.range.notPresentAlpha = value
end })
option({ path = 'party.rowSpacing', default = 13, combat = true, refresh = 'partyLayout', label = 'Party Row Spacing', apply = function(style, value)
    style.party.rowSpacing = value
end })
option({ path = 'party.playerFrame', default = 'standalone', reload = true, label = 'Your Frame', apply = function(style, value)
    style.party.standalone = value == 'standalone'
end })
option({ path = 'party.growUp', default = false, combat = true, refresh = 'partyLayout', label = 'Party Grows Upward', apply = function(style, value)
    style.party.growUp = value
end })
option({ path = 'party.dispellable', default = 'blizzard', refresh = 'auraPolicy', apply = function(style, value)
    style.party.auras.dispellableOnly = followValue(value)
    style.party.pet.auras.dispellableOnly = followValue(value)
end })
option({ path = 'party.buffs', default = 'blizzard', reload = true, label = 'Party Buffs', apply = function(style, value)
    for _, auras in ipairs({ style.party.auras, style.party.pet.auras }) do
        auras.groups.buffs.auraType = value ~= 'all' and 'Buff' or nil
    end
end })

option({ path = 'raid.hpText', default = 'current', refresh = 'rows',
    blizzard = { cvars = { 'raidFramesHealthText' }, read = function()
        return RAID_HEALTH_TEXT[readCVar('raidFramesHealthText')] or 'current'
    end },
    apply = function(style, value)
    style.raid.hp.textMode = value
end })
option({ path = 'raid.power', default = 'all', refresh = 'rows',
    blizzard = { cvars = { 'raidFramesDisplayPowerBars', 'raidFramesDisplayOnlyHealerPowerBars' }, read = function()
        if readCVar('raidFramesDisplayPowerBars') == '0' then
            return 'none'
        elseif readCVar('raidFramesDisplayOnlyHealerPowerBars') == '1' then
            return 'healers'
        end
        return 'all'
    end },
    apply = function(style, value)
    style.raid.power.show = value
end })
option({ path = 'raid.farAlpha', default = 0.5, apply = function(style, value)
    style.raid.range.farAlpha = value
end })
-- Per raid size (EUI.RaidList.SIZES); RaidList reads them for the size in use.
local RAID_LAYOUT_DEFAULTS = { [10] = 2, [25] = 5, [40] = 4 }
for _, size in ipairs(EUI.RaidList.SIZES) do
    option({ path = string.format('raid.layouts.%d.groupsPerRow', size), default = RAID_LAYOUT_DEFAULTS[size],
        combat = true, refresh = 'raidLayout', label = 'Raid Groups per Row', apply = function() end })
    option({ path = string.format('raid.layouts.%d.scale', size), default = 1, combat = true, refresh = 'raidLayout',
        label = 'Raid Layout Scale', apply = function() end })
    option({ path = string.format('raid.layouts.%d.petsPerColumn', size), default = 10, combat = true, refresh = 'raidLayout',
        label = 'Pets per Column', apply = function() end })
    option({ path = string.format('raid.layouts.%d.petsScale', size), default = 1, combat = true, refresh = 'raidLayout',
        label = 'Pets Layout Scale', apply = function() end })
end
option({ path = 'raid.previewSize', default = 40, apply = function() end })
option({ path = 'raid.rowSpacing', default = 4, combat = true, refresh = 'raidSpacing', label = 'Raid Cell Spacing', apply = function(style, value)
    style.raid.rowSpacing = value
end })
option({ path = 'raid.groupSpacingX', default = 8, combat = true, refresh = 'raidSpacing', label = 'Raid Group Column Gap', apply = function(style, value)
    style.raid.groupSpacing[1] = value
end })
option({ path = 'raid.groupSpacingY', default = 14, combat = true, refresh = 'raidSpacing', label = 'Raid Group Row Gap', apply = function(style, value)
    style.raid.groupSpacing[2] = value
end })
option({ path = 'raid.groupLabels', default = true, refresh = 'raidLabels', label = 'Raid Group Labels', apply = function(style, value)
    style.raid.groupNumber.hidden = not value
end })
-- 'show' / 'hide' force the section; 'blizzard' (nil) follows the raid manager.
local function sectionShown(value)
    if value == 'show' then
        return true
    elseif value == 'hide' then
        return false
    end
    return nil
end
option({ path = 'raid.assists', default = 'blizzard', combat = true, refresh = 'raidSections', label = 'Assists Section', apply = function(style, value)
    style.raid.assists.show = sectionShown(value)
end })
option({ path = 'raid.pets', default = 'blizzard', combat = true, refresh = 'raidSections', label = 'Pets Section', apply = function(style, value)
    style.raid.pets.show = sectionShown(value)
end })
-- Per palette (styles/palettes.lua healthColor); only the built palette's applies.
for name, palette in pairs(Kit.PALETTES) do
    option({ path = 'healthColor.' .. name, default = palette.healthColor or 'palette', refresh = 'rows',
        blizzard = { cvars = { 'raidFramesDisplayClassColor' }, read = function()
            return readCVar('raidFramesDisplayClassColor') == '0' and 'palette' or 'class'
        end },
        apply = function(style, value)
            if style.palette == name then
                style.party.hp.classColor = value == 'class'
                style.raid.hp.classColor = value == 'class'
            end
        end })
end
option({ path = 'raid.dispellable', default = 'blizzard', refresh = 'auraPolicy', apply = function(style, value)
    style.raid.auras.dispellableOnly = followValue(value)
end })
option({ path = 'raid.buffs', default = 'blizzard', reload = true, label = 'Raid Buffs', apply = function(style, value)
    style.raid.auras.groups.buffs.auraType = value ~= 'all' and 'Buff' or nil
end })

option({ path = 'target.hostileFilter', default = true, refresh = 'hostile', apply = function(style, value)
    forTargets(style, function(spec)
        if spec.hostileAuras then
            spec.hostileAuras.disabled = not value
        end
    end)
end })
option({ path = 'target.combo', default = true, refresh = 'bars', apply = function(style, value)
    if style.target.comboPoints then
        style.target.comboPoints.hidden = not value
    end
end })
option({ path = 'target.threatText', default = true, apply = function(style, value)
    forTargets(style, function(spec)
        spec.txtThreat.hidden = not value
    end)
end })
option({ path = 'target.castBars', default = 'on', refresh = 'bars',
    blizzard = { cvars = { 'showTargetCastbar' }, read = function()
        return readCVar('showTargetCastbar') == '0' and 'off' or 'on'
    end },
    apply = function(style, value)
        forTargets(style, function(spec)
            spec.cast.disabled = value == 'off'
        end)
    end })
option({ path = 'castBar.enabled', default = true, refresh = 'playerCast', apply = function(style, value)
    style.castBar.disabled = not value
end })

local FONT_FILES = {
    { 'Fonts\\FRIZQT__.TTF', 'Friz Quadrata' },
    { 'Fonts\\ARIALN.TTF', 'Arial Narrow' },
    { 'Fonts\\MORPHEUS.TTF', 'Morpheus' },
    { 'grammara.ttf', 'Grammara' },
    { 'consola.ttf', 'Consolas' },
}
-- Kit.FONTS slots by page group: { key, label, tip, sample }. The sample shows one of each kind of
-- text the slot draws, or two of the one kind it draws.
local FONT_GROUPS = {
    { 'Names and labels', {
        { 'name', 'Unit Names', 'Names on party rows, raid cells, pets, target, focus, boss and their targets.',
            'Zal-Das   Defias Conjurer' },
        { 'header', 'Frame Labels', 'The Group N, Assists, Pets, Focus, Boss and Totems headers.',
            'Group 1   Focus' },
        { 'level', 'Level Numbers', 'The level on each class icon and portrait.', '60   7' },
    } },
    { 'Bars', {
        { 'health', 'Health and Power', 'HP and power values, HP%, threat % and Dead / Offline text.',
            '12,480   87%   Dead' },
        { 'cast', 'Cast Bar Text', 'Spell names on every cast bar, and Interrupted / Failed.',
            'Heal   Interrupted' },
    } },
    { 'Auras', {
        { 'timer', 'Countdowns', 'Time left on aura icons.', '28m   6' },
        { 'count', 'Stack Counts', 'Stack counts on aura icons.', '3   10' },
    } },
}
local FONT_SLOTS = {}
for _, group in ipairs(FONT_GROUPS) do
    for _, slot in ipairs(group[2]) do
        FONT_SLOTS[#FONT_SLOTS + 1] = slot
    end
end
for _, slot in ipairs(FONT_SLOTS) do
    option({ path = 'fonts.' .. slot[1], default = Kit.FONTS[slot[1]], reload = true, label = slot[2] .. ' font', apply = function(style, value)
        style.fonts[slot[1]] = value
    end })
end

option({ path = 'auraBorder', default = Kit.AURA_BORDER, reload = true, label = 'Aura Icon Edge' })
-- Defaults in core/settings.lua; read when the style is built.
option({ path = 'style', reload = true, label = 'Palette' })
option({ path = 'colors', reload = true, label = 'Colours' })

-- Per-frame multipliers on the root scale, keyed as the Edit Mode frames.
local SCALED_FRAMES = {
    { 'player', 'Player' },
    { 'party', 'Party' },
    { 'raid', 'Raid Groups' },
    { 'assists', 'Assists' },
    { 'pets', 'Raid Pets' },
    { 'target', 'Target' },
    { 'focus', 'Focus' },
    { 'boss', 'Boss' },
    { 'cast', 'Your Cast Bar' },
    { 'totems', 'Totems' },
}
for _, frame in ipairs(SCALED_FRAMES) do
    option({ path = 'scales.' .. frame[1], default = 1, combat = true, refresh = 'scale', label = frame[2] .. ' scale',
        apply = function() end })
end

---------------------------------------------------------------------------------------------
-- Applying

-- Before the style is built: options the layout copies into many specs.
function Config.BeforeBuild()
    Kit.AURA_BORDER = Settings.Get('auraBorder')
end

-- Re-applies options set to 'blizzard' that follow cvar.
function Config.OnCVarChanged(cvar)
    if not Config.style or type(cvar) ~= 'string' then
        return
    end
    cvar = cvar:lower()
    for _, def in ipairs(defs) do
        if def.blizzard and Settings.Get(def.path) == 'blizzard' then
            for _, name in ipairs(def.blizzard.cvars) do
                if name:lower() == cvar then
                    def.apply(Config.style, 'blizzard')
                    local refresh = def.refresh and REFRESH[def.refresh]
                    if refresh then
                        refresh()
                    end
                    redrawDemo()
                    break
                end
            end
        end
    end
end

-- Writes every option into style (a freshly built one, before the frames exist).
function Config.ApplyOptions(style)
    ownTables(style)
    for _, def in ipairs(defs) do
        if def.apply then
            def.apply(style, Settings.Get(def.path))
        end
    end
end

-- Once the frames exist: live options re-apply and refresh on change.
function Config.Initialize(style)
    for _, def in ipairs(defs) do
        if not def.reload and def.apply then
            local function changed()
                def.apply(style, Settings.Get(def.path))
                local refresh = def.refresh and REFRESH[def.refresh]
                if refresh then
                    refresh()
                end
                redrawDemo()
            end
            Settings.OnChange(def.path, function()
                if def.combat then
                    if InCombatLockdown() then
                        Config.NoteCombatChange(def.label or def.path)
                    end
                    -- The style keeps the built value until the frames can follow it.
                    EUI.RunOutOfCombat(changed, 'option:' .. def.path)
                else
                    changed()
                end
            end)
        end
    end
    Settings.OnChange('style', function()
        Config.RebuildPage('colors')
    end)
    -- The Scale page shows each frame's final scale; the raid layout sliders follow the raid size.
    local function scaleChanged()
        Config.scaleChanged = true
        Config.Refresh()
    end
    Settings.OnChange('scale', function()
        if InCombatLockdown() then
            Config.NoteCombatChange('Scale')
        end
        scaleChanged()
    end)
    Settings.OnChange('raid.previewSize', Config.Refresh)
    for _, frame in ipairs(SCALED_FRAMES) do
        Settings.OnChange('scales.' .. frame[1], scaleChanged)
    end
    Config.style = style
    Config.SnapshotBuilt()
    Config.RegisterBlizzardEntry()
    Config.RegisterMinimapButton()
end

---------------------------------------------------------------------------------------------
-- Pages
-- Item kinds: header (label), note (text), toggle / choice / slider / color bound to path, or
-- with get/set; buttons ({ label, run(button), tip, labelFn, variant, icon }); palettes; about.
-- Every control carries a tip, shown under its label; reload items say so in it.
-- choice.style: 'tabs', or 'font' (a font file per choice, with a sample); else segmented.
-- slider.final: fn() -> the frame's final scale, for the scale table. art: fn() -> pieces for
-- the row's tile, as EUI.Indicators.Samples.
-- enabled (optional): fn() -> whether the control can be used, re-read on Refresh.
-- defaultValue (optional): fn() -> the value a reset returns to, for items without a saved path.

local RELOAD_TIP = '|cfff0ddb3Applies after a reload.|r'

local function tip(text, reload)
    if reload then
        return text .. '\n' .. RELOAD_TIP
    end
    return text
end

local function toggle(path, label, text)
    return { kind = 'toggle', path = path, label = label, tip = text }
end

local function choice(path, label, choices, text, reload)
    return { kind = 'choice', path = path, label = label, choices = choices, tip = tip(text, reload) }
end

-- choices with a leading 'Blizzard' choice explained by text.
local function withBlizzard(choices, text)
    local out = { { 'blizzard', 'Blizzard', text } }
    for _, entry in ipairs(choices) do
        out[#out + 1] = entry
    end
    return out
end

local function percent(v)
    return string.format('%d%%', math.floor(v * 100 + 0.5))
end

local function styleChoices()
    local names = {}
    for name in pairs(Kit.PALETTES) do
        names[#names + 1] = name
    end
    table.sort(names)
    local LABELS = {
        vanadiel = { "Vana'diel", "VanaVista's colours: pastel red HP, pale blue casts, FFXI name colours." },
        azeroth = { 'Azeroth', "Blizzard's colours: green HP, gold casts, reaction-coloured names." },
    }
    local out = {}
    for _, name in ipairs(names) do
        local label = LABELS[name] or { name, name }
        out[#out + 1] = { name, label[1], label[2] }
    end
    return out
end

local general = {
    {
        kind = 'buttons', label = 'Frame Positions',
        tip = 'Put every frame back at its default spot. Move, under Frame Control, shows the drag handles.',
        buttons = {
            {
                label = 'Reset Positions', tip = 'Put every frame back at its default spot.',
                run = function() SlashCmdList.EORZEAUI('reset') end,
            },
        },
    },
    choice('style', 'Palette', styleChoices(), 'Colours for every frame. Colour overrides are kept per palette.', true),
    toggle('castBar.enabled', 'Player Cast Bar', 'The cast bar under your character. Off leaves casts to your party row.'),
}

local scale = {
    {
        kind = 'slider', path = 'scale', label = 'Global Scale', min = 0.5, max = 2, step = 0.05, format = '%.2f\195\151',
        width = 320, emphasis = true,
        tip = "Multiplies every frame below. Frames are sized for 1440p and scaled to your screen height; WoW's UI Scale slider is ignored.",
    },
    { kind = 'header', label = 'Each Frame' },
}
for _, frame in ipairs(SCALED_FRAMES) do
    local path = 'scales.' .. frame[1]
    local text = string.format('Size of the %s frame, times the scale for all frames.', frame[2]:lower())
    if frame[1] == 'raid' then
        text = text .. ' The raid size layouts on the Raid page multiply it again.'
    elseif frame[1] == 'player' then
        text = text .. ' Only while your frame is standalone (Party page).'
    end
    scale[#scale + 1] = {
        kind = 'slider', path = path, label = frame[2], min = 0.5, max = 2, step = 0.05, format = '%.2f',
        final = function() return Settings.Get('scale') * Settings.Get(path) end,
        tip = text,
    }
    if frame[1] == 'player' then
        scale[#scale].enabled = function() return Settings.Get('party.playerFrame') == 'standalone' end
    end
end
scale[#scale + 1] = {
    kind = 'note', color = '#F0DDB3FF', shown = function() return Config.scaleChanged end,
    text = 'Scale changed: frames grow and shrink from their anchor point, so their positions on screen move. Turn on Move, under Frame Control, to put them back.',
}

local party = {
    { kind = 'header', label = 'Health and Power' },
    choice('party.hpText', 'HP Text', withBlizzard(HP_TEXT, "Follow Blizzard's Status Text setting; Both reads as Current."),
        'The number on each HP bar.'),
    toggle('party.castBars', 'Cast Bars on Member Rows', 'Replaces the name line while a member casts.'),
    toggle('party.petCast', 'Cast Bar on Your Pet Row', "Replaces your pet's name line while it casts."),
    { kind = 'header', label = 'Auras' },
    choice('party.dispellable', 'Only Dispellable Debuffs', FOLLOW,
        "Blizzard follows Interface > Party Frames' \"Show only dispellable debuffs\"."),
    choice('party.buffs', 'Buffs Shown', BUFFS, 'Which buffs fill the aura slots beside each row.', true),
    { kind = 'header', label = 'Layout' },
    choice('party.playerFrame', 'Your Frame', {
        { 'standalone', 'Standalone', "Your own frame and mover, as Blizzard's player frame. The party list shows members only and hides with none." },
        { 'merged', 'In the Party List', 'Your row heads the party list and stays alone in a raid.' },
    }, 'Where your row shows.', true),
    toggle('party.growUp', 'Grow Upward',
        "Rows stack up from the party list's bottom edge; your row is the bottom one while it is in the list."),
    {
        kind = 'slider', path = 'party.rowSpacing', label = 'Row Spacing', min = 0, max = 30, step = 1, format = '%d px',
        tip = 'Gap between rows. Below 5 the leader crown overlaps the level number of the row above.',
    },
    {
        kind = 'slider', path = 'party.farAlpha', label = 'Out of Range', min = 0.1, max = 1, step = 0.05, format = percent,
        tip = "Opacity of members out of range. Blizzard's raid-style frames use 50%.",
    },
    {
        kind = 'slider', path = 'party.notPresentAlpha', label = 'Phased / Elsewhere', min = 0.1, max = 1, step = 0.05, format = percent,
        tip = "Opacity of phased members and members in another group. Blizzard's party frames use 60%.",
    },
}

local INDICATOR_TIPS = {
    leader = 'Crown on the class icon of the group leader.',
    assistant = 'Hollow crown and loot bag on the class icon of raid assistants and the master looter.',
    role = 'Tank, healer or damage icon on the class icon, or the main tank and assist icons in a raid.',
    raidMarker = 'Raid target marker before the name.',
    flag = 'AFK or DND badge on the name line.',
}
local INDICATOR_GROUPS = {
    { 'Identity', { 'leader', 'assistant', 'role', 'pvp', 'raidMarker' } },
    { 'Status', { 'flag', 'status', 'rest' } },
}

-- The active palette's colour for key, with the user's override.
local function activeColor(key)
    local styleName = Settings.Get('style')
    local palette = Kit.PALETTES[styleName] or {}
    return Settings.Get(string.format('colors.%s.%s', styleName, key)) or palette[key] or '#FFFFFFFF'
end

-- Art for the indicators drawn without an icon of their own (EUI.Indicators.Samples covers the rest).
local EXTRA_SAMPLES = {
    -- A sliver of HP bar with the incoming heals after it.
    healPrediction = function()
        return {
            { fill = activeColor('hp'), size = { 22, 8 }, gap = 0 },
            { fill = activeColor('heals'), size = { 10, 8 }, gap = 0 },
            { fill = activeColor('absorbs'), size = { 6, 8 } },
        }
    end,
    -- Your class icon, tinted as below 20% health.
    lowHealth = function()
        local _, class = UnitClass('player')
        local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
        return { {
            path = 'Interface\\TargetingFrame\\UI-Classes-Circles', coords = coords, size = { 20, 20 },
            color = Kit.LOW_HEALTH.color,
        } }
    end,
}

-- art: fn() -> the pieces the row's tile shows, read when the page is built.
local function artToggle(path, label, text, key)
    local item = toggle(path, label, text)
    item.art = EXTRA_SAMPLES[key] or function()
        return EUI.Indicators.Samples()[key]
    end
    return item
end
local indicators = {}
for _, group in ipairs(INDICATOR_GROUPS) do
    indicators[#indicators + 1] = { kind = 'header', label = group[1] }
    for _, key in ipairs(group[2]) do
        for _, entry in ipairs(INDICATORS) do
            if entry[1] == key then
                indicators[#indicators + 1] = artToggle(entry.def.path, entry[2], entry[3] or INDICATOR_TIPS[key], key)
            end
        end
    end
end
indicators[#indicators + 1] = { kind = 'header', label = 'Combat' }
indicators[#indicators + 1] = artToggle('indicators.threat', 'Threat Diamond',
    "On the class icon or portrait, tinted with Blizzard's threat colours.", 'threat')
indicators[#indicators + 1] = artToggle('indicators.healPrediction', 'Incoming Heals and Absorbs',
    'Heals on the way and shields, past the end of the HP fill.', 'healPrediction')
indicators[#indicators + 1] = artToggle('indicators.lowHealth', 'Low-Health Red Tint',
    'Tints the class icon or portrait red below 20% health.', 'lowHealth')

local raid = {
    { kind = 'header', label = 'Cells' },
    choice('raid.hpText', 'HP Text', withBlizzard(HP_TEXT, "Follow Blizzard's raid frame Health Text setting."),
        'The number at the end of the name line.'),
    choice('raid.power', 'Power Bars', withBlizzard({
        { 'all', 'All', 'Every member.' },
        { 'healers', 'Healers', 'Only members with the healer role.' },
        { 'none', 'None', 'No power bars.' },
    }, "Follow Blizzard's raid frame power bar settings."), 'The short power bar under each HP bar.'),
    {
        kind = 'slider', path = 'raid.farAlpha', label = 'Out of Range', min = 0.1, max = 1, step = 0.05, format = percent,
        tip = "Opacity of cells out of range. Blizzard's raid frames use 50%.",
    },
    { kind = 'header', label = 'Auras' },
    choice('raid.dispellable', 'Only Dispellable Debuffs', FOLLOW,
        "Blizzard follows Interface > Raid Frames' \"Display only dispellable debuffs\"."),
    choice('raid.buffs', 'Buffs Shown', BUFFS, 'Which buffs fill the aura line under each cell.', true),
    { kind = 'header', label = 'Layout' },
    toggle('raid.groupLabels', 'Group Labels', 'The "Group N" headers; the Pets label shares them.'),
    choice('raid.assists', 'Assists Section', SECTION_SHOW, 'Main tanks and assists with their targets.'),
    choice('raid.pets', 'Pets Section', SECTION_SHOW, "Every raid member's pet, in its own block."),
    {
        kind = 'slider', path = 'raid.rowSpacing', label = 'Cell Spacing', min = 0, max = 20, step = 1, format = '%d px',
        tip = 'Gap between cells in a group, in Assists and in Pets. Small gaps let the leader crown overlap the level number of the cell above.',
    },
    {
        kind = 'slider', path = 'raid.groupSpacingX', label = 'Group Gap Across', min = 0, max = 40, step = 1, format = '%d px',
        tip = 'Gap between groups side by side, and between Pets columns.',
    },
    {
        kind = 'slider', path = 'raid.groupSpacingY', label = 'Group Gap Down', min = 0, max = 40, step = 1, format = '%d px',
        tip = 'Gap between a row of groups and the Group N labels of the next.',
    },
    { kind = 'header', label = 'Layout by Raid Size' },
    { kind = 'note', text = "A raid uses the layout of the smallest size that holds its members. Sizes are Blizzard's Edit Mode raid sizes: 2, 5 and 8 groups." },
    choice('raid.previewSize', 'Raid Size', {
        { 10, '10 players', 'Edit the 10-player layout; the demo shows 2 groups.' },
        { 25, '25 players', 'Edit the 25-player layout; the demo shows 5 groups.' },
        { 40, '40 players', 'Edit the 40-player layout; the demo shows 8 groups.' },
    }, "The layout the sliders below edit, and the size the demo and Edit Mode show, as Blizzard's Edit Mode Raid Size."),
}
-- Picks which layout the sliders edit; section resets leave it.
raid[#raid].noReset = true
raid[#raid].style = 'tabs'
-- The sliders edit the layout of the chosen raid size.
local function layoutPath(key)
    return string.format('raid.layouts.%d.%s', Settings.Get('raid.previewSize'), key)
end
raid[#raid + 1] = {
    kind = 'slider', label = 'Groups per Row', min = 1, max = 8, step = 1, format = '%d',
    range = function() return 1, EUI.RaidList.GroupCount() end,
    get = function() return math.min(Settings.Get(layoutPath('groupsPerRow')), EUI.RaidList.GroupCount()) end,
    set = function(value) Settings.Set(layoutPath('groupsPerRow'), value) end,
    pathFn = function() return layoutPath('groupsPerRow') end,
    tip = 'Groups side by side before the next row starts, in raids of the chosen size: up to 2 for 10 players, 5 for 25, 8 for 40.',
}
raid[#raid + 1] = {
    kind = 'slider', label = 'Scale', min = 0.5, max = 2, step = 0.05, format = '%.2f',
    get = function() return Settings.Get(layoutPath('scale')) end,
    set = function(value) Settings.Set(layoutPath('scale'), value) end,
    pathFn = function() return layoutPath('scale') end,
    tip = 'Size of the raid groups in raids of the chosen size, times the raid scale on the Scale page.',
}
raid[#raid + 1] = {
    kind = 'slider', label = 'Pets per Column', min = 1, max = 40, step = 1, format = '%d',
    range = function() return EUI.RaidPets.PerColumnRange(Settings.Get('raid.previewSize')) end,
    get = function()
        local low, high = EUI.RaidPets.PerColumnRange(Settings.Get('raid.previewSize'))
        return math.max(low, math.min(high, Settings.Get(layoutPath('petsPerColumn'))))
    end,
    set = function(value) Settings.Set(layoutPath('petsPerColumn'), value) end,
    pathFn = function() return layoutPath('petsPerColumn') end,
    tip = 'Pets stacked in a column before the next column starts, in raids of the chosen size. At most 8 columns: at least 2 per column for 10 players, 4 for 25, 5 for 40.',
}
raid[#raid + 1] = {
    kind = 'slider', label = 'Pets Scale', min = 0.5, max = 2, step = 0.05, format = '%.2f',
    get = function() return Settings.Get(layoutPath('petsScale')) end,
    set = function(value) Settings.Set(layoutPath('petsScale'), value) end,
    pathFn = function() return layoutPath('petsScale') end,
    tip = 'Size of the Pets block in raids of the chosen size, times the raid pets scale on the Scale page.',
}

-- The target, focus and boss bars' options close the General page.
local target = {
    { kind = 'header', label = 'Target, Focus & Boss' },
    toggle('target.hostileFilter', "Hide Others' Debuffs on Hostile NPCs",
        "As Blizzard's target frame: your debuffs, debuffs flagged for everyone and NPCs' own. Off shows every debuff."),
    toggle('target.combo', 'Combo Points', 'Your combo points beside the target icon. Target bar only.'),
    toggle('target.threatText', 'Threat Percent', 'Your threat percent under the HP%.'),
    choice('target.castBars', 'Cast Bars', withBlizzard({
        { 'on', 'On', 'Shown while the unit casts.' },
        { 'off', 'Off', 'Never shown.' },
    }, "Follow Blizzard's Show Target Cast Bar setting."), 'The cast bar above the HP bar.'),
}
for _, item in ipairs(target) do
    general[#general + 1] = item
end

local fontItems = {}
for _, group in ipairs(FONT_GROUPS) do
    fontItems[#fontItems + 1] = { kind = 'header', label = group[1] }
    for _, slot in ipairs(group[2]) do
        fontItems[#fontItems + 1] = {
            kind = 'choice', style = 'font', path = 'fonts.' .. slot[1], label = slot[2], choices = FONT_FILES,
            preview = slot[4], tip = tip(slot[3], true),
        }
    end
end

-- Palette keys with a swatch, for the palette chosen in settings: { key, label, tip, alpha,
-- fallback key }. alpha: the swatch edits alpha.
local COLOR_GROUPS = {
    { 'Bars', {
        { 'hp', 'Health', 'HP bar fill and frame on every frame.' },
        { 'heals', 'Incoming Heals', 'Heals on the way, past the end of the HP fill.', true },
        { 'absorbs', 'Absorbs', 'Shields, after incoming heals.', true },
        { 'offline', 'Offline Health', 'HP bar of offline members.' },
        { 'powerColors.0', 'Mana', 'Power bar while it shows mana.' },
        { 'powerColors.1', 'Rage', 'Power bar while it shows rage.' },
        { 'powerColors.2', 'Focus', 'Power bar while it shows focus.' },
        { 'powerColors.3', 'Energy', 'Power bar while it shows energy.' },
        { 'power', 'Other Power', 'Power bar frame, and the fill for other power types.' },
    } },
    { 'Cast bars', {
        { 'cast', 'Casting', 'Cast bars while a spell is cast.' },
        { 'channel', 'Channeling', 'Cast bars while a spell is channeled.', false, 'cast' },
        { 'castFailure', 'Interrupted / Failed', 'The bar held full after an interrupted or failed cast.' },
        { 'uninterruptible', 'Uninterruptible', "Target casts you can't interrupt." },
    } },
    { 'Text', {
        { 'name', 'Party Names', 'Names on party rows and raid cells.' },
        { 'text', 'Numbers', 'HP and power values and spell names.' },
        { 'targetText', 'Target Text', 'HP% and threat % on target, focus and boss bars.' },
        { 'label', 'Frame Labels', 'Group N, Assists, Pets, Focus, Boss and Totems headers.' },
    } },
    { 'Target names by reaction', {
        { 'reaction.party', 'Party members', 'Members of your group.' },
        { 'reaction.player', 'Players', 'Other players you cannot attack.' },
        { 'reaction.hostilePlayer', 'Hostile players', 'Players you can attack.' },
        { 'reaction.friendly', 'Friendly NPCs', 'NPCs friendly to you.' },
        { 'reaction.neutral', 'Neutral NPCs', 'NPCs that attack only when attacked.' },
        { 'reaction.unfriendly', 'Unfriendly NPCs', 'NPCs one step below neutral.' },
        { 'reaction.hostile', 'Hostile NPCs', 'NPCs that attack on sight.' },
        { 'reaction.tapped', 'Tapped by others', 'Mobs another player or group has claimed.' },
    } },
    { 'Auras', {
        { 'dispel.Magic', 'Magic edge', 'Edge of Magic debuffs.' },
        { 'dispel.Curse', 'Curse edge', 'Edge of Curse debuffs.' },
        { 'dispel.Poison', 'Poison edge', 'Edge of Poison debuffs.' },
        { 'dispel.Disease', 'Disease edge', 'Edge of Disease debuffs.' },
        { 'stealable', 'Stealable Buff Edge', 'Edge of buffs you can spellsteal on the target.' },
    } },
    { 'Other', {
        { 'combo', 'Combo Points', 'The combo point diamonds beside the target icon.' },
    } },
}

local function paletteValue(palette, key)
    local value = palette
    for part in key:gmatch('[^.]+') do
        if type(value) ~= 'table' then
            return nil
        end
        value = value[tonumber(part) or part]
    end
    return value
end

local function colorItems()
    local styleName = Settings.Get('style')
    local palette = Kit.PALETTES[styleName] or {}
    local items = {
        { kind = 'header', label = 'Palette' },
        {
            kind = 'palettes', path = 'style', label = 'Palette', choices = styleChoices(), noReset = true,
            tip = tip('Colours for every frame. Colour overrides are kept per palette.', true),
        },
        choice('healthColor.' .. styleName, 'Health colour', withBlizzard({
            { 'class', 'Class', 'HP bars in the class colour.' },
            { 'palette', 'Palette', 'HP bars in the Health colour below.' },
        }, "Follow Blizzard's raid frame Display Class Colors setting."),
            'HP bar fill and line on party rows and raid cells. Kept per palette; applies at once.'),
    }
    for _, group in ipairs(COLOR_GROUPS) do
        items[#items + 1] = { kind = 'header', label = group[1] }
        for _, entry in ipairs(group[2]) do
            local key, label, text, alpha, fallback = entry[1], entry[2], entry[3], entry[4], entry[5]
            local path = string.format('colors.%s.%s', styleName, key)
            local function default()
                return paletteValue(palette, key) or (fallback and paletteValue(palette, fallback)) or '#FFFFFFFF'
            end
            items[#items + 1] = {
                kind = 'color', label = label, alpha = alpha, tip = tip(text, true),
                get = function() return Settings.Get(path) or default() end,
                set = function(hex) Settings.Set(path, hex) end,
                isDefault = function() return Settings.Get(path) == nil end,
                reset = function() Settings.Set(path, nil) end,
                defaultValue = default,
            }
        end
    end
    items[#items + 1] = { kind = 'header', label = 'Every Palette' }
    items[#items + 1] = {
        kind = 'color', label = 'Aura Icon Edge', tip = tip('The edge around aura icons without a dispel colour.', true),
        get = function() return Settings.Get('auraBorder') end,
        set = function(hex) Settings.Set('auraBorder', hex) end,
        isDefault = function() return Settings.Get('auraBorder') == Settings.Default('auraBorder') end,
        reset = function() Settings.Reset('auraBorder') end,
        defaultValue = function() return Settings.Default('auraBorder') end,
    }
    return items
end

local about = {
    { kind = 'hero' },
    { kind = 'header', label = 'Slash Commands' },
    { kind = 'command', command = '/ffui', text = 'Open these settings.' },
    { kind = 'command', command = '/ffui demo', text = 'Fill every frame with sample units.' },
    { kind = 'command', command = '/ffui unlock', text = 'Show drag handles on every frame; /ffui lock hides them.' },
    { kind = 'command', command = '/ffui reset', text = 'Put every frame back at its default spot.' },
    { kind = 'command', command = '/ffui scale <n>', text = 'Set the global scale, as on the Scale page.' },
    { kind = 'command', command = '/ffui style <name>', text = 'Switch palette and reload.' },
    { kind = 'command', command = '/ffui log', text = "List what EorzeaUI recorded: missing game functions, failed reads, blocked actions. /ffui log clear empties it." },
    { kind = 'header', label = 'Troubleshooting' },
    { kind = 'faq', label = 'A frame went off screen', text = 'Type /ffui reset, or use Reset Positions on the General page.' },
    { kind = 'faq', label = "A change didn't take effect", text = 'Palette, colours, fonts and buff rules apply after a reload; the footer lists any waiting. Settings changed in combat apply when combat ends.' },
    { kind = 'faq', label = 'A warning or error showed up', text = '/ffui log lists what EorzeaUI recorded. It is saved with your settings on reload or logout.' },
    { kind = 'header', label = 'Credits' },
    { kind = 'note', color = '#A9B6CBFF', text = 'A fan-made addon in the style of Final Fantasy menus. Not affiliated with Blizzard Entertainment or Square Enix. Settings fonts: Inter and Cinzel, under the SIL Open Font License.' },
}

-- group: the page list heading. icon: assets/settings art. demo: the demo sections
-- (EUI.Demo.SECTIONS) shown while the page is open. reloadNote: every option on the page applies
-- after a reload.
local ALL = EUI.Demo.SECTIONS
Config.PAGES = {
    { key = 'general', group = 'Frames', label = 'General', icon = 'navGeneral', items = general, demo = { 'cast', 'target' },
        tip = 'The palette, frame positions, your cast bar, and the target, focus and boss bars.' },
    { key = 'party', group = 'Frames', label = 'Party', icon = 'navParty', items = party, demo = { 'party' },
        tip = 'Party rows: health text, cast bars, auras and how the list is laid out.' },
    { key = 'raid', group = 'Frames', label = 'Raid', icon = 'navRaid', items = raid, demo = { 'raid' },
        tip = 'Raid cells, groups, the Assists section and pets.' },
    { key = 'scale', group = 'Frames', label = 'Scale', icon = 'navLayout', items = scale, demo = ALL,
        tip = "Size every frame together, then fine-tune each one. A frame's final size is the global scale times its own." },
    { key = 'indicators', group = 'Display', label = 'Indicators', icon = 'navIndicators', items = indicators,
        demo = { 'party', 'raid', 'target' },
        tip = 'Each indicator shows on every frame that draws it: party rows, raid cells, and the target, focus and boss bars.' },
    { key = 'colors', group = 'Display', label = 'Colours', icon = 'navColors', items = colorItems, demo = ALL, reloadNote = true,
        tip = 'Colours of the active palette. Pick a starting point, then adjust any swatch.' },
    { key = 'fonts', group = 'Display', label = 'Fonts', icon = 'navFonts', items = fontItems, demo = ALL, reloadNote = true,
        tip = 'The typeface for each kind of text.' },
    { key = 'about', group = 'Addon', label = 'Info', icon = 'navAbout', items = about,
        tip = 'Version, slash commands and help.' },
}
