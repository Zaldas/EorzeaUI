local _, EUI = ...

-- Fills every frame with fixed sample data for screenshots and Edit Mode positioning.
-- Active while toggled with /eui demo or while Edit Mode is open.

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
local DEBUFFS = {
    { ICON .. 'Spell_Shadow_ShadowWordPain', '14' },
    { ICON .. 'Spell_Shadow_AbominationExplosion', '9' },
    { ICON .. 'Spell_Shadow_CurseOfSargeras', '21' },
    { ICON .. 'Spell_Nature_CorrosiveBreath', '2m' },
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

local function target()
    return {
        name = 'Defias Pillager', level = 18, classification = 'elite', colorKey = 'hostile', pvp = 'Horde', leader = true, raidMarker = 8, threat = 3, threatPercent = 100, combo = 3, portraitUnit = 'player', hpPercent = 46,
        debuffs = TARGET_DEBUFFS, buffs = TARGET_BUFFS,
        castName = 'Fireball', castProgress = 0.6, castNotInterruptible = true,
        totName = playerDisplayName(), totColorKey = 'party', totPercent = 92,
    }
end

-- A crowd-controlled caster: the usual focus target.
local function focus()
    return {
        name = 'Defias Conjurer', level = 17, colorKey = 'hostile', leader = true, raidMarker = 5, portraitUnit = 'player', hpPercent = 78,
        debuffs = { { ICON .. 'Spell_Nature_Polymorph', '41', dispel = 'Magic' }, TARGET_DEBUFFS[1] },
        buffs = { { ICON .. 'Spell_Frost_FrostArmor02', '9m', stealable = true } },
        castName = 'Frostbolt', castProgress = 0.3,
        totName = 'Brightmane Stormhold', totColorKey = 'party', totPercent = 100,
    }
end

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

function Demo.Refresh()
    local active = Demo.toggled or EUI.EditMode.unlocked
    if active == Demo.active then
        return
    end
    Demo.active = active
    EUI.PartyList.SetDemo(active and members() or nil)
    EUI.TargetBar.target:SetPreview(active and target() or nil)
    EUI.TargetBar.focus:SetPreview(active and focus() or nil)
    EUI.playerCast:SetPreview(active and 'Flash of Light' or nil, 0.45)
end
