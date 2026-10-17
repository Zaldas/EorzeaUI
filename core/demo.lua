local _, AV = ...

-- Fills every frame with fixed sample data for screenshots and Edit Mode positioning.
-- Active while toggled with /av demo or while Edit Mode is open.

AV.Demo = {}
local Demo = AV.Demo

local ICON = 'Interface\\Icons\\'
local BUFFS = {
    { ICON .. 'Spell_Holy_WordFortitude', '28m' },
    { ICON .. 'Spell_Nature_Regeneration', '24m' },
    { ICON .. 'Spell_Holy_MagicalSentry', '19m' },
    { ICON .. 'Spell_Holy_FistOfJustice', '4m' },
    { ICON .. 'Spell_Holy_Renew', '11' },
    { ICON .. 'Spell_Holy_PowerWordShield', '22' },
}
local DEBUFFS = {
    { ICON .. 'Spell_Shadow_ShadowWordPain', '14' },
    { ICON .. 'Spell_Shadow_AbominationExplosion', '9' },
    { ICON .. 'Spell_Shadow_CurseOfSargeras', '21' },
    { ICON .. 'Spell_Nature_CorrosiveBreath', '2m' },
    { ICON .. 'Spell_Frost_FrostNova', '6' },
}

local function pick(list, count)
    local out = {}
    for i = 1, count do
        out[i] = list[i]
    end
    return out
end

-- Pet auras run debuffs then buffs in one row.
local function petAuras(debuffCount, buffCount)
    local out = pick(DEBUFFS, debuffCount)
    for i = 1, buffCount do
        out[#out + 1] = BUFFS[i]
    end
    return out
end

local HUNTER_PET = {
    name = 'Fang', icon = ICON .. 'Ability_Hunter_Pet_Wolf', hp = 1640, hpMax = 1920, power = 70, powerMax = 100, powerType = 2,
    happiness = 3, auras = petAuras(1, 2),
}
local IMP = {
    name = 'Zhaztak', icon = ICON .. 'Spell_Shadow_SummonImp', hp = 980, hpMax = 1210, power = 860, powerMax = 1350, powerType = 0,
    cast = 'Firebolt',
}

local function members()
    local playerName = AV.UnitDisplayName('player') or 'You'
    local playerClass = select(2, UnitClass('player')) or 'PALADIN'
    local playerFaction = UnitFactionGroup and UnitFactionGroup('player') or 'Alliance'
    return {
        { name = playerName, class = playerClass, level = UnitLevel('player') or 60, leader = true, hp = 2870, hpMax = 3120, power = 2940, powerMax = 4200,
          resting = true, pvp = playerFaction, powerType = 0, buffs = pick(BUFFS, 4), debuffs = {}, pet = HUNTER_PET },
        { name = 'Brightmane Stormhold', class = 'WARRIOR', level = 60, hp = 4560, hpMax = 4560, power = 35, powerMax = 100,
          status = 'ready', raidMarker = 8, role = 'TANK', threat = 3, powerType = 1, masterLooter = true, buffs = pick(BUFFS, 3), debuffs = pick(DEBUFFS, 1) },
        { name = 'Velisandre Ashby', class = 'PRIEST', level = 59, hp = 1590, hpMax = 2480, incoming = 520, absorb = 240, power = 3360, powerMax = 4200,
          tag = 'AFK', role = 'HEALER', cast = 'Greater Heal', powerType = 0, assistant = true, masterLooter = true, buffs = pick(BUFFS, 6), debuffs = {} },
        { name = 'Korgath Ironhide', class = 'DRUID', level = 60, hp = 480, hpMax = 2890, power = 1800, powerMax = 3000, targeted = true,
          status = 'waiting', role = 'DAMAGER', raidMarker = 1, threat = 1, powerType = 0, combo = 3, form = { powerType = 3, power = 100, powerMax = 100 }, buffs = pick(BUFFS, 2), debuffs = pick(DEBUFFS, 2) },
        { name = 'Ashwind Vale', class = 'WARLOCK', level = 58, hp = 1720, hpMax = 2350, power = 2100, powerMax = 3400,
          powerType = 0, status = 'notready', buffs = pick(BUFFS, 3), debuffs = pick(DEBUFFS, 3), pet = IMP },
    }
end

local function target()
    return {
        name = 'Defias Pillager', level = 18, classification = 'elite', colorKey = 'claimed', portraitUnit = 'player', hpPercent = 46,
        debuffs = pick(DEBUFFS, 4), buffs = pick(BUFFS, 1),
        castName = 'Fireball', castProgress = 0.6,
        totName = AV.UnitDisplayName('player') or 'You', totColorKey = 'party', totPercent = 92,
    }
end

function Demo.Toggle()
    if InCombatLockdown() then
        AV.Print('demo mode cannot change in combat')
        return
    end
    Demo.toggled = not Demo.toggled
    Demo.Refresh()
    AV.Print('demo mode %s', Demo.toggled and 'on' or 'off')
end

local GALLERY = 'AzerothVista_Gallery'

-- Loads the AzerothVista_Gallery addon on first use; it builds its window when first shown.
function Demo.ToggleGallery()
    if not AV.ready then
        return
    end
    local loaded, reason = C_AddOns.LoadAddOn(GALLERY)
    if not loaded then
        AV.Print('%s not loaded: %s', GALLERY, tostring(reason))
        return
    end
    AzerothVistaGallery.Toggle()
end

-- The gallery's only way into this addon. Valid once the party list exists.
AzerothVista = {
    -- Returns a non-secure demo row: row:ShowDemo(member), row:DemoHeight(member).
    CreateDemoRow = function(parent, index)
        return AV.PartyRow.CreateDemo(parent, AV.PartyList.style, AV.PartyList.fonts, index)
    end,
    StackDemoRows = function(...)
        return AV.PartyList.StackDemoRows(...)
    end,
    CreateBackground = function(anchor)
        return AV.PartyList.CreateBackground(anchor)
    end,
    RootScale = function()
        return AV.Style.RootScale()
    end,
}

function Demo.Refresh()
    local active = Demo.toggled or AV.EditMode.unlocked
    if active == Demo.active then
        return
    end
    Demo.active = active
    AV.PartyList.SetDemo(active and members() or nil)
    AV.TargetBar.SetPreview(active and target() or nil)
    AV.playerCast:SetPreview(active and 'Flash of Light' or nil, 0.45)
end
