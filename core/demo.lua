local _, EUI = ...

-- Fills every frame with fixed sample data for screenshots and Edit Mode positioning.
-- Active while toggled with /ffui demo or while Edit Mode is open.

EUI.Demo = {}
local Demo = EUI.Demo

local ICON = 'Interface\\Icons\\'
local BUFFS = {
    { ICON .. 'Spell_Holy_WordFortitude', '28m' },
    { ICON .. 'Spell_Nature_Regeneration', '24m' },
    { ICON .. 'Spell_Holy_MagicalSentry', '19m' },
    { ICON .. 'Spell_Holy_FistOfJustice', '4m' },
    { ICON .. 'Spell_Holy_Renew', '11' },
    { ICON .. 'Spell_Holy_PowerWordShield', '22' },
}
-- Mostly dispellable, so the rows show their dispel-type edges.
local DEBUFFS = {
    { ICON .. 'Spell_Shadow_ShadowWordPain', '14', dispel = 'Magic' },
    { ICON .. 'Spell_Shadow_AbominationExplosion', '9', dispel = 'Disease' },
    { ICON .. 'Spell_Shadow_CurseOfSargeras', '21', dispel = 'Curse' },
    { ICON .. 'Spell_Nature_CorrosiveBreath', '2m', dispel = 'Poison' },
    { ICON .. 'Spell_Frost_FrostNova', '6' },
}

-- Target auras cover every edge the target rows draw: one debuff per dispel type plus an
-- untyped ones, and a stealable buff beside ordinary ones. More than one line's worth, so the
-- buffs wrap.
local TARGET_DEBUFFS = {
    { ICON .. 'Spell_Shadow_ShadowWordPain', '14', dispel = 'Magic' },
    { ICON .. 'Spell_Shadow_CurseOfSargeras', '21', dispel = 'Curse' },
    { ICON .. 'Ability_Poisons', '9', dispel = 'Poison' },
    { ICON .. 'Spell_Shadow_CallofBone', '2m', dispel = 'Disease' },
    { ICON .. 'Ability_Gouge', '6', dispel = 'Bleed' },
    { ICON .. 'Ability_Warrior_Sunder', '24' },
    { ICON .. 'Spell_Frost_FrostNova', '6' },
    { ICON .. 'Spell_Nature_CorrosiveBreath', '2m' },
    { ICON .. 'Spell_Shadow_AbominationExplosion', '9' },
}
local TARGET_BUFFS = {
    { ICON .. 'Spell_Holy_PowerWordShield', '22', stealable = true },
    { ICON .. 'Ability_Warrior_BattleShout', '1m' },
    { ICON .. 'Spell_Holy_WordFortitude', '28m' },
    { ICON .. 'Spell_Nature_Regeneration', '24m' },
    { ICON .. 'Spell_Holy_MagicalSentry', '19m' },
    { ICON .. 'Spell_Holy_Renew', '11' },
    { ICON .. 'Spell_Nature_Thorns', '8m' },
    { ICON .. 'Spell_Holy_GreaterBlessingofKings', '14m' },
    { ICON .. 'Spell_Nature_LightningShield', '7m' },
    { ICON .. 'Spell_Holy_DevotionAura', '3m' },
}

-- The player's name for samples; 'You' when it is missing or secret.
local function playerDisplayName()
    local name = EUI.UnitDisplayName('player')
    if not EUI.CanAccess(name) then
        return 'You'
    end
    return name
end

local function pick(list, count)
    local out = {}
    for i = 1, count do
        out[i] = list[i]
    end
    return out
end

-- count entries, repeating list; the first keeps list's order.
local function cycle(list, count)
    local out = {}
    for i = 1, count do
        out[i] = list[(i - 1) % #list + 1]
    end
    return out
end

-- One aura flow, in the live order. Called when the demo builds its samples: StaticIcons loads
-- after this file.
local function petAuras(debuffCount, buffCount)
    return EUI.StaticIcons.Grouped(pick(DEBUFFS, debuffCount), pick(BUFFS, buffCount))
end

local HUNTER_PET = {
    name = 'Fang', icon = ICON .. 'Ability_Hunter_Pet_Wolf', hp = 1640, hpMax = 1920, power = 70, powerMax = 100, powerType = 2,
    happiness = 3, attacking = true, threat = 3,
}
local IMP = {
    name = 'Zhaztak', icon = ICON .. 'Spell_Shadow_SummonImp', hp = 980, hpMax = 1210, power = 860, powerMax = 1350, powerType = 0,
    cast = 'Firebolt', threat = 1,
}

local function members()
    HUNTER_PET.auras = petAuras(1, 2)
    IMP.auras = petAuras(2, 1)
    local playerName = playerDisplayName()
    local playerClass = select(2, UnitClass('player')) or 'PALADIN'
    local playerFaction = UnitFactionGroup and UnitFactionGroup('player') or 'Alliance'
    return {
        { name = playerName, class = playerClass, level = UnitLevel('player') or 60, leader = true, hp = 2870, hpMax = 3120, power = 2940, powerMax = 4200,
          resting = true, pvp = playerFaction, powerType = 0, buffs = pick(BUFFS, 4), debuffs = {}, pet = HUNTER_PET },
        { name = 'Brightmane Stormhold', class = 'WARRIOR', level = 60, hp = 4560, hpMax = 4560, power = 35, powerMax = 100,
          status = 'ready', raidMarker = 8, role = 'TANK', threat = 3, powerType = 1, masterLooter = true, buffs = pick(BUFFS, 3), debuffs = pick(DEBUFFS, 1) },
        { name = 'Velisandre Ashby', class = 'PRIEST', level = 59, hp = 1590, hpMax = 2480, incoming = 520, absorb = 240, power = 3360, powerMax = 4200,
          tag = 'DND', role = 'HEALER', cast = 'Greater Heal', powerType = 0, assistant = true, masterLooter = true, buffs = pick(BUFFS, 6), debuffs = {} },
        { name = 'Korgath Ironhide', class = 'DRUID', level = 60, hp = 480, hpMax = 2890, power = 1800, powerMax = 3000, targeted = true,
          status = 'waiting', role = 'DAMAGER', raidMarker = 1, threat = 1, powerType = 0, form = { powerType = 3, power = 100, powerMax = 100 }, buffs = pick(BUFFS, 2), debuffs = pick(DEBUFFS, 2) },
        { name = 'Ashwind Vale', class = 'WARLOCK', level = 58, hp = 1720, hpMax = 2350, power = 2100, powerMax = 3400,
          powerType = 0, status = 'notready', buffs = pick(BUFFS, 3), debuffs = pick(DEBUFFS, 3), pet = IMP },
    }
end

-- A full 40-player raid: you lead group 1; tanks, healers and a few states spread over the rest.
local RAID_CLASSES = { 'WARRIOR', 'PRIEST', 'MAGE', 'ROGUE', 'DRUID', 'HUNTER', 'WARLOCK', 'PALADIN', 'SHAMAN' }
local RAID_POWER = { WARRIOR = 1, ROGUE = 3 }
local RAID_ROLES = { WARRIOR = 'TANK', PRIEST = 'HEALER', DRUID = 'HEALER', PALADIN = 'HEALER', SHAMAN = 'HEALER' }
local NAME_STARTS = { 'Ael', 'Bran', 'Cor', 'Dra', 'Eli', 'Fen', 'Gar', 'Hal', 'Ish', 'Jor', 'Kael', 'Lio', 'Mor' }
local NAME_ENDS = { 'dor', 'wyn', 'ric', 'tha', 'mir' }
-- By raid slot (group * 5 + member): states and markers the cells show.
local RAID_EXTRAS = {
    [2] = { raidMarker = 8, threat = 3, assistant = true, auraCounts = { 5, 6 } },
    [4] = { status = 'ready' },
    [7] = { targeted = true, incoming = 640 },
    [9] = { state = 'dead' },
    [12] = { far = true },
    [14] = { status = 'notready', tag = 'AFK' },
    [18] = { state = 'offline' },
    [21] = { raidMarker = 1, threat = 1 },
    [26] = { status = 'summonPending' },
    [31] = { status = 'resurrect', state = 'dead' },
    [35] = { far = true, absorb = 400 },
}

local function raidMembers()
    local groups = {}
    for g = 1, 8 do
        local list = {}
        for m = 1, 5 do
            local slot = (g - 1) * 5 + m
            local class = RAID_CLASSES[(slot - 1) % #RAID_CLASSES + 1]
            local hpMax = class == 'WARRIOR' and 5200 or 3100
            local member = {
                name = NAME_STARTS[(slot - 1) % #NAME_STARTS + 1] .. NAME_ENDS[(slot - 1) % #NAME_ENDS + 1],
                class = class, role = RAID_ROLES[class] or 'DAMAGER',
                hp = math.floor(hpMax * (0.35 + (slot * 37 % 65) / 100)), hpMax = hpMax,
                powerType = RAID_POWER[class] or 0, power = 60, powerMax = 100,
            }
            for key, value in pairs(RAID_EXTRAS[slot] or {}) do
                member[key] = value
            end
            if member.auraCounts then
                member.auras = petAuras(member.auraCounts[1], member.auraCounts[2])
            end
            list[m] = member
        end
        groups[g] = list
    end
    local you = groups[1][1]
    you.name, you.class, you.leader, you.role = playerDisplayName(), select(2, UnitClass('player')) or 'PALADIN', true, nil
    return groups
end

-- A full Assists block: four main tanks, each on a mob, then four main assists on the tanks'
-- mobs, picked from the demo raid; their cells show the raid role in place of the assigned one.
local ASSIST_MOBS = {
    { name = 'Ragnaros', colorKey = 'hostile', hpPercent = 64, raidMarker = 8, targeted = true },
    { name = 'Son of Flame', colorKey = 'hostile', hpPercent = 38, raidMarker = 7 },
    { name = 'Son of Flame', colorKey = 'hostile', hpPercent = 81, raidMarker = 6 },
    { name = 'Lava Surger', colorKey = 'hostile', hpPercent = 22, raidMarker = 5 },
}
-- { group, member, role, mob }
local ASSIST_PICKS = {
    { 2, 5, 'MAINTANK', 1 }, { 4, 4, 'MAINTANK', 2 }, { 3, 1, 'MAINTANK', 3 }, { 7, 2, 'MAINTANK', 4 },
    { 6, 3, 'MAINASSIST', 2 }, { 5, 5, 'MAINASSIST', 1 }, { 8, 4, 'MAINASSIST', 3 }, { 1, 2, 'MAINASSIST', 4 },
}

local function assistMembers(groups)
    local function flagged(member, role)
        local copy = {}
        for key, value in pairs(member) do
            copy[key] = value
        end
        copy.role = role
        return copy
    end
    -- Each mob targets the tank on it.
    local tanks = {}
    for _, entry in ipairs(ASSIST_PICKS) do
        if entry[3] == 'MAINTANK' then
            tanks[entry[4]] = groups[entry[1]][entry[2]]
        end
    end
    local out = {}
    for i, entry in ipairs(ASSIST_PICKS) do
        local tank = tanks[entry[4]]
        out[i] = {
            member = flagged(groups[entry[1]][entry[2]], entry[3]),
            target = ASSIST_MOBS[entry[4]],
            tot = { name = tank.name, colorKey = 'party', hpPercent = math.floor(tank.hp / tank.hpMax * 100) },
        }
    end
    return out
end

-- A full pets block: a pet for every member of the demo raid, in raid order, alternating beasts
-- and imps.
local RAID_PET_KINDS = {
    { icon = ICON .. 'Ability_Hunter_Pet_Wolf', powerType = 2, hpMax = 1920 },
    { icon = ICON .. 'Spell_Shadow_SummonImp', powerType = 0, hpMax = 1210 },
}
local RAID_PET_NAMES = { 'Fang', 'Zhaztak', 'Grimtooth', 'Vexira', 'Shadowclaw', 'Brakkus', 'Skitter', 'Fizznik' }

local function raidPets(groups)
    local pets = {}
    for _, list in ipairs(groups) do
        for _, member in ipairs(list) do
            local n = #pets + 1
            local kind = RAID_PET_KINDS[(n - 1) % #RAID_PET_KINDS + 1]
            pets[n] = {
                name = RAID_PET_NAMES[(n - 1) % #RAID_PET_NAMES + 1], icon = kind.icon, ownerClass = member.class,
                hp = math.floor(kind.hpMax * (0.4 + (n * 23 % 60) / 100)), hpMax = kind.hpMax,
                power = 70, powerMax = 100, powerType = kind.powerType,
            }
        end
    end
    pets[2].targeted = true
    pets[#pets].far = true
    return pets
end

local function target()
    return {
        name = 'Defias Pillager', level = 18, classification = 'elite', colorKey = 'hostile', pvp = 'Horde', leader = true, raidMarker = 8, threat = 3, threatPercent = 100, combo = 3, portraitUnit = 'player', hpPercent = 46,
        debuffs = cycle(TARGET_DEBUFFS, 16), buffs = cycle(TARGET_BUFFS, 32),
        castName = 'Fireball', castProgress = 0.6, castNotInterruptible = true,
        totName = playerDisplayName(), totColorKey = 'party', totPercent = 92,
        totDebuffs = { TARGET_DEBUFFS[1], TARGET_DEBUFFS[3], TARGET_DEBUFFS[6] },
    }
end

-- A crowd-controlled caster: the usual focus target.
local function focus()
    return {
        name = 'Defias Conjurer', level = 17, colorKey = 'hostile', leader = true, raidMarker = 5, portraitUnit = 'player', hpPercent = 78,
        questBoss = true,
        debuffs = cycle({ { ICON .. 'Spell_Nature_Polymorph', '41', dispel = 'Magic' }, unpack(TARGET_DEBUFFS) }, 8),
        buffs = cycle({ { ICON .. 'Spell_Frost_FrostArmor02', '9m', stealable = true }, unpack(TARGET_BUFFS, 2) }, 8),
        castName = 'Frostbolt', castProgress = 0.3,
        totName = 'Brightmane Stormhold', totColorKey = 'party', totPercent = 100,
    }
end

-- An encounter filling every slot: the boss casting on its tank, a lieutenant on a healer, two
-- adds, and a dead one.
local function bosses()
    return {
        {
            name = 'Ragnaros', level = -1, classification = 'worldboss', colorKey = 'hostile', raidMarker = 8, portraitUnit = 'player',
            hpPercent = 64, threat = 3, threatPercent = 100, castName = 'Wrath of Ragnaros', castProgress = 0.4, castNotInterruptible = true,
            totName = 'Brightmane Stormhold', totColorKey = 'party', totPercent = 81,
        },
        {
            name = 'Majordomo Executus', level = 63, classification = 'elite', colorKey = 'hostile', raidMarker = 7, portraitUnit = 'player',
            hpPercent = 38, threat = 1, threatPercent = 72,
            totName = 'Velisandre Ashby', totColorKey = 'party', totPercent = 55,
        },
        {
            name = 'Son of Flame', level = 62, classification = 'elite', colorKey = 'hostile', raidMarker = 6, portraitUnit = 'player',
            hpPercent = 81, threat = 2, threatPercent = 96,
            totName = 'Korgath Ironhide', totColorKey = 'party', totPercent = 17,
        },
        {
            name = 'Lava Surger', level = 62, classification = 'elite', colorKey = 'hostile', raidMarker = 5, portraitUnit = 'player',
            hpPercent = 22, castName = 'Surge', castProgress = 0.7,
            totName = 'Ashwind Vale', totColorKey = 'party', totPercent = 0, totState = 'dead',
        },
        {
            name = 'Flamewaker Healer', level = 62, classification = 'elite', colorKey = 'hostile', portraitUnit = 'player',
            hpPercent = 0, dead = true,
        },
    }
end

-- A shaman's four totems: { icon, time left, duration }.
local TOTEMS = {
    { ICON .. 'Spell_Fire_SearingTotem', 29, 55 },
    { ICON .. 'Spell_Nature_EarthBindTotem', 95, 120 },
    { ICON .. 'INV_Spear_04', 47, 60 },
    { ICON .. 'Spell_Nature_Windfury', 112, 120 },
}

function Demo.Toggle()
    if InCombatLockdown() then
        EUI.Print('demo mode cannot change in combat')
        return
    end
    Demo.toggled = not Demo.toggled
    Demo.Refresh()
    EUI.Print('demo mode %s', Demo.toggled and 'on' or 'off')
end

local GALLERY = 'EorzeaUI_Gallery'

-- Loads the EorzeaUI_Gallery addon on first use; it builds each window when first shown.
-- kind: 'party' or 'target'.
function Demo.ToggleGallery(kind)
    if not EUI.ready then
        return
    end
    if not (C_AddOns and C_AddOns.LoadAddOn) then
        EUI.Print('cannot load %s: C_AddOns.LoadAddOn missing', GALLERY)
        return
    end
    local loaded, reason = C_AddOns.LoadAddOn(GALLERY)
    if not loaded then
        EUI.Print('%s not loaded: %s', GALLERY, tostring(reason))
        return
    end
    EorzeaUIGallery.Toggle(kind)
end

-- The gallery's only way into this addon. Valid once the party list exists.
EorzeaUI = {
    -- Returns a non-secure demo row: row:ShowDemo(member), row:DemoHeight(member).
    CreateDemoRow = function(parent)
        return EUI.PartyRow.CreateDemo(parent, EUI.PartyList.style, EUI.PartyList.fonts)
    end,
    StackDemoRows = function(...)
        return EUI.PartyList.StackDemoRows(...)
    end,
    -- Returns a demo target bar: bar:SetPreview(data); bar.anchor is its frame, bar.spec its style.
    CreateDemoTarget = function(parent)
        local live = EUI.TargetBar.target
        return EUI.TargetBar.CreateDemo(parent, live.spec, live.fonts)
    end,
    CreateBackground = function(anchor)
        return EUI.PartyList.CreateBackground(anchor)
    end,
    RootScale = function()
        return EUI.Style.RootScale()
    end,
}

-- The demo shows by section: all of them while toggled or in Edit Mode, else the sections the
-- settings window's page asks for (Demo.SetPageSections).
Demo.SECTIONS = { 'party', 'raid', 'target', 'cast', 'totems' }
local shown = {}

local SHOW = {
    party = function(on)
        EUI.PartyList.SetDemo(on and members() or nil)
    end,
    raid = function(on)
        local raid = on and raidMembers() or nil
        local assists = raid and assistMembers(raid)
        -- The raid preview size (settings raid.previewSize) keeps its first groups.
        if raid then
            for g = EUI.Settings.Get('raid.previewSize') / 5 + 1, #raid do
                raid[g] = {}
            end
        end
        EUI.RaidList.SetDemo(raid, assists)
        EUI.RaidPets.SetDemo(raid and raidPets(raid))
        EUI.RaidList.ApplyLayoutSize()
    end,
    target = function(on)
        EUI.TargetBar.target:SetPreview(on and target() or nil)
        EUI.TargetBar.focus:SetPreview(on and focus() or nil)
        local bossSamples = on and bosses() or {}
        for i, bar in ipairs(EUI.TargetBar.bosses) do
            bar:SetPreview(bossSamples[i])
        end
    end,
    cast = function(on)
        EUI.playerCast:SetPreview(on and 'Flash of Light' or nil, 0.45)
    end,
    totems = function(on)
        EUI.TotemBar.SetPreview(on and TOTEMS or nil)
    end,
}

function Demo.IsShowing(section)
    return shown[section] == true
end

-- Demo.active: any section shows.
function Demo.Refresh()
    local all = Demo.toggled or EUI.EditMode.unlocked
    local any = false
    for _, section in ipairs(Demo.SECTIONS) do
        local want = (all or (Demo.pageSections and Demo.pageSections[section])) and true or false
        if want ~= (shown[section] == true) then
            shown[section] = want
            SHOW[section](want)
        end
        any = any or want
    end
    Demo.active = any
end

-- sections: a list of Demo.SECTIONS names, or nil for none. Waits for combat to end.
function Demo.SetPageSections(sections)
    local set
    if sections then
        set = {}
        for _, section in ipairs(sections) do
            set[section] = true
        end
    end
    Demo.pageSections = set
    EUI.RunOutOfCombat(Demo.Refresh, 'demoRefresh')
end

-- Draws the shown sections again from fresh samples (after a settings change).
function Demo.Redraw()
    EUI.RunOutOfCombat(function()
        for _, section in ipairs(Demo.SECTIONS) do
            if shown[section] then
                SHOW[section](true)
            end
        end
    end, 'demoRedraw')
end
