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

local function members()
    local playerName = AV.UnitDisplayName('player') or 'You'
    local playerClass = select(2, UnitClass('player')) or 'PALADIN'
    local playerFaction = UnitFactionGroup and UnitFactionGroup('player') or 'Alliance'
    return {
        { name = playerName, class = playerClass, level = UnitLevel('player') or 60, leader = true, hp = 2870, hpMax = 3120, power = 2940, powerMax = 4200,
          resting = true, pvp = playerFaction, buffs = pick(BUFFS, 4), debuffs = {} },
        { name = 'Brightmane Stormhold', class = 'WARRIOR', level = 60, hp = 4560, hpMax = 4560, power = 35, powerMax = 100,
          status = 'ready', raidMarker = 8, role = 'TANK', buffs = pick(BUFFS, 3), debuffs = pick(DEBUFFS, 1) },
        { name = 'Velisandre Ashby', class = 'PRIEST', level = 59, hp = 1590, hpMax = 2480, incoming = 520, power = 3360, powerMax = 4200,
          tag = 'AFK', role = 'HEALER', buffs = pick(BUFFS, 6), debuffs = {} },
        { name = 'Korgath Ironhide', class = 'ROGUE', level = 60, hp = 1100, hpMax = 2890, power = 100, powerMax = 100, targeted = true,
          status = 'waiting', role = 'DAMAGER', raidMarker = 1, buffs = pick(BUFFS, 2), debuffs = pick(DEBUFFS, 2) },
        { name = 'Ashwind Vale', class = 'MAGE', level = 58, hp = 0, hpMax = 2350, power = 920, powerMax = 4200, far = true,
          state = 'dead', buffs = pick(BUFFS, 3), debuffs = pick(DEBUFFS, 3) },
    }
end

local function target()
    return {
        name = 'Defias Pillager', level = 18, hpPercent = 46,
        debuffs = pick(DEBUFFS, 4), buffs = pick(BUFFS, 1),
        castName = 'Fireball', castProgress = 0.6,
        totName = AV.UnitDisplayName('player') or 'You', totPercent = 92,
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
