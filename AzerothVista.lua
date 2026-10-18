local addonName, AV = ...

local DEFAULTS = {
    style = 'ffxiExpanded',
    scale = 1,
    positions = {},
}

local RANGE_TICK = 0.25

local function loadSettings()
    AzerothVistaDB = AzerothVistaDB or {}
    for key, value in pairs(DEFAULTS) do
        if AzerothVistaDB[key] == nil then
            AzerothVistaDB[key] = type(value) == 'table' and {} or value
        end
    end
    AV.db = AzerothVistaDB
end

local function applyScale()
    AV.RunOutOfCombat(function()
        local scale = AV.Style.RootScale()
        AV.PartyList.anchor:SetScale(scale)
        AV.TargetBar.target.anchor:SetScale(scale)
        AV.castAnchor:SetScale(scale)
    end, 'scale')
    if AzerothVistaGallery and AzerothVistaGallery.ApplyScale then
        AzerothVistaGallery.ApplyScale()
    end
end

local function createPlayerCastBar(style, fonts)
    local spec = style.castBar
    local anchor = CreateFrame('Frame', 'AzerothVistaCastAnchor', UIParent)
    anchor:SetSize(spec.width, spec.height)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    AV.castAnchor = anchor
    AV.playerCast = AV.CastBar.Create(anchor, 'player', spec, fonts, { 0, 0 })
end

-- APIs behind optional features; missing ones are logged once per session.
local FEATURE_APIS = {
    'IsResting', 'UnitIsConnected', 'UnitIsDead', 'UnitIsGhost', 'UnitIsAFK', 'UnitIsDND',
    'GetReadyCheckStatus', 'GetRaidTargetIndex', 'C_IncomingSummon', 'UnitHasIncomingResurrection',
    'UnitPhaseReason', 'UnitInRange', 'CreateUnitHealPredictionCalculator', 'UnitGetDetailedHealPrediction',
    'UnitCastingDuration', 'C_StringUtil', 'canaccessvalue', 'UnitGroupRolesAssigned', 'UnitIsPVP',
    'UnitIsPVPFreeForAll', 'UnitFactionGroup', 'UnitThreatSituation', 'GetThreatStatusColor',
    'UnitPowerType', 'UnitIsGroupAssistant', 'C_Spell', 'GetShapeshiftForm', 'RegisterStateDriver',
    'RegisterUnitWatch', 'SetPortraitTexture', 'HasPetUI', 'C_PetInfo',
}

local function logCapabilities()
    local missing = {}
    for _, name in ipairs(FEATURE_APIS) do
        if _G[name] == nil then
            missing[#missing + 1] = name
        end
    end
    AV.Log('capabilities: %s', #missing == 0 and 'all feature APIs present' or 'missing ' .. table.concat(missing, ', '))
end

local function initialize()
    if not AV.styles[AV.db.style] then
        AV.db.style = DEFAULTS.style
    end
    local style = AV.styles[AV.db.style]
    local fonts = style.fonts
    AV.LogSession()
    logCapabilities()
    AV.inCombat = AV.SafeBool(UnitAffectingCombat, 'player')

    local suf = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded('SleekUnitFrames')
    if suf then
        AV.Print('Sleek Unit Frames is also loaded; both hide the same Blizzard frames. Disable one.')
    end

    AV.PartyList.Create(style, fonts)
    AV.TargetBar.Create(style, fonts)
    createPlayerCastBar(style, fonts)

    local partyBg = AV.PartyList.background
    AV.EditMode.Register('party', AV.PartyList.anchor, 'Party', { partyBg.top, partyBg.bottom })
    AV.EditMode.Register('target', AV.TargetBar.target.anchor, 'Target')
    AV.EditMode.Register('cast', AV.castAnchor, 'Cast bar')
    AV.EditMode.Initialize()

    AV.Blizzard.HideReplaced()
    applyScale()

    C_Timer.NewTicker(RANGE_TICK, AV.Guard('range ticker', function()
        AV.PartyList.ForEachVisibleRow(function(row)
            row:UpdateRange()
        end)
        AV.TargetBar.ForEach(function(bar)
            bar:UpdateIdentity()
            bar:UpdateThreat()
            bar:UpdateTargetOfTarget()
        end)
    end))

    AV.ready = true
    AV.PartyList.RefreshAll()
    AV.TargetBar.target:Refresh()
end

-- Unit events route to the party row, pet sub-row and target-style bar showing that unit.
local function onUnitEvent(event, unit, arg3)
    local row = AV.PartyList.RowForUnit(unit)
    local pet = AV.PartyList.PetForUnit(unit)
    local bar = AV.TargetBar.ForUnit(unit)
    if event == 'UNIT_HEALTH' or event == 'UNIT_MAXHEALTH' then
        if row then row:UpdateHealth(event == 'UNIT_HEALTH') end
        if pet then pet:UpdateHealth(event == 'UNIT_HEALTH') end
        if bar then bar:UpdateHealth(event == 'UNIT_HEALTH') end
    elseif event == 'UNIT_POWER_UPDATE' or event == 'UNIT_MAXPOWER' or event == 'UNIT_DISPLAYPOWER' then
        if row then
            row:UpdatePower(event == 'UNIT_POWER_UPDATE')
            row:UpdateCombo()
        end
        if pet then pet:UpdatePower(event == 'UNIT_POWER_UPDATE') end
    elseif event == 'UNIT_PET' then
        -- unit is the owner, possibly by another token than its row's ('player' for a raidN row).
        AV.PartyList.ForEachVisiblePet(function(visiblePet)
            visiblePet:Refresh()
        end)
    elseif event == 'UNIT_PORTRAIT_UPDATE' then
        if pet then pet:UpdatePortrait() end
        if bar then bar:UpdateIcon() end
    elseif event == 'UNIT_HAPPINESS' then
        if pet then pet:UpdateHappiness() end
    elseif event == 'UNIT_NAME_UPDATE' or event == 'UNIT_LEVEL' then
        if row then row:UpdateName() end
        if pet then pet:UpdateName() end
        if bar then bar:Refresh() end
    elseif event == 'UNIT_TARGET' then
        if bar then bar:UpdateTargetOfTarget() end
    elseif event == 'UNIT_HEAL_PREDICTION' or event == 'UNIT_ABSORB_AMOUNT_CHANGED' then
        if row then row:UpdateHealPrediction() end
        if bar then bar:UpdateHealPrediction() end
    elseif event == 'UNIT_CONNECTION' then
        if row then row:UpdateState() end
    elseif event == 'UNIT_FLAGS' or event == 'PLAYER_FLAGS_CHANGED' then
        if row then
            row:UpdateFlags()
            row:UpdateState()
            row:UpdatePvP()
        end
        if bar then
            bar:UpdateIdentity()
        end
        -- PLAYER_FLAGS_CHANGED may name the target by another token (party1, raid3).
        local flagBar = event == 'PLAYER_FLAGS_CHANGED' and AV.TargetBar.target or bar
        if flagBar then
            flagBar:UpdateFlags()
        end
    elseif event == 'UNIT_FACTION' then
        if row then row:UpdatePvP() end
        if bar then bar:UpdateIdentity() end
    elseif event == 'UNIT_THREAT_SITUATION_UPDATE' then
        if row then row:UpdateThreat() end
    elseif event == 'INCOMING_SUMMON_CHANGED' or event == 'INCOMING_RESURRECT_CHANGED' or event == 'UNIT_PHASE' then
        if row then row:UpdateStatusIcon() end
    elseif event:find('^UNIT_SPELLCAST_') then
        if unit == 'player' then AV.playerCast:Update() end
        if row then
            row:UpdateCast()
            row:UpdateCostPreview(event, arg3)
        end
        if pet then pet:UpdateCast() end
        if bar then
            if event == 'UNIT_SPELLCAST_INTERRUPTED' then
                bar.cast:ShowFailure(INTERRUPTED or 'Interrupted')
            elseif event == 'UNIT_SPELLCAST_FAILED' then
                bar.cast:ShowFailure(FAILED or 'Failed')
            else
                bar.cast:Update()
            end
        end
    end
end

local UNIT_EVENTS = {
    'UNIT_HEALTH', 'UNIT_MAXHEALTH', 'UNIT_POWER_UPDATE', 'UNIT_MAXPOWER', 'UNIT_DISPLAYPOWER',
    'UNIT_NAME_UPDATE', 'UNIT_LEVEL', 'UNIT_TARGET',
    'UNIT_SPELLCAST_START', 'UNIT_SPELLCAST_STOP', 'UNIT_SPELLCAST_FAILED', 'UNIT_SPELLCAST_INTERRUPTED',
    'UNIT_SPELLCAST_DELAYED', 'UNIT_SPELLCAST_CHANNEL_START', 'UNIT_SPELLCAST_CHANNEL_STOP',
    'UNIT_SPELLCAST_CHANNEL_UPDATE', 'UNIT_SPELLCAST_SUCCEEDED', 'UNIT_SPELLCAST_INTERRUPTIBLE',
    'UNIT_SPELLCAST_NOT_INTERRUPTIBLE',
    'UNIT_HEAL_PREDICTION', 'UNIT_ABSORB_AMOUNT_CHANGED', 'UNIT_CONNECTION', 'UNIT_FLAGS', 'PLAYER_FLAGS_CHANGED',
    'INCOMING_SUMMON_CHANGED', 'INCOMING_RESURRECT_CHANGED', 'UNIT_PHASE', 'UNIT_FACTION',
    'UNIT_THREAT_SITUATION_UPDATE', 'UNIT_PET', 'UNIT_PORTRAIT_UPDATE', 'UNIT_HAPPINESS',
}

local GLOBAL_EVENTS = {
    'ADDON_LOADED', 'PLAYER_ENTERING_WORLD', 'PLAYER_REGEN_ENABLED', 'PLAYER_REGEN_DISABLED',
    'PLAYER_TARGET_CHANGED', 'GROUP_ROSTER_UPDATE', 'PARTY_LEADER_CHANGED', 'UI_SCALE_CHANGED',
    'DISPLAY_SIZE_CHANGED', 'PLAYER_UPDATE_RESTING', 'PLAYER_DEAD', 'PLAYER_ALIVE', 'PLAYER_UNGHOST',
    'READY_CHECK', 'READY_CHECK_CONFIRM', 'READY_CHECK_FINISHED', 'RAID_TARGET_UPDATE',
    'ADDON_ACTION_BLOCKED', 'ADDON_ACTION_FORBIDDEN', 'PLAYER_ROLES_ASSIGNED', 'ROLE_CHANGED_INFORM',
    'PARTY_LOOT_METHOD_CHANGED', 'UPDATE_SHAPESHIFT_FORM', 'PET_UI_UPDATE',
}

local function forEachRow(method)
    AV.PartyList.ForEachVisibleRow(function(row)
        row[method](row)
    end)
end

local events = CreateFrame('Frame')
-- Registering an event the client does not know raises an error.
for _, list in ipairs({ GLOBAL_EVENTS, UNIT_EVENTS }) do
    for _, name in ipairs(list) do
        local ok, err = pcall(events.RegisterEvent, events, name)
        if not ok then
            AV.LogOnce('event:' .. name, 'event %s not registered: %s', name, tostring(err))
        end
    end
end

events:SetScript('OnEvent', AV.Guard('OnEvent', function(_, event, arg1, arg2, arg3)
    if event == 'ADDON_LOADED' then
        if arg1 == addonName then
            loadSettings()
            -- Secure frames cannot be created in combat (e.g. a /reload mid-fight).
            AV.RunOutOfCombat(initialize)
            events:UnregisterEvent('ADDON_LOADED')
        end
        return
    end
    if event == 'ADDON_ACTION_BLOCKED' or event == 'ADDON_ACTION_FORBIDDEN' then
        if arg1 == addonName then
            AV.Log('%s: %s', event, tostring(arg2))
        end
        return
    end
    if event == 'PLAYER_REGEN_ENABLED' or event == 'PLAYER_REGEN_DISABLED' then
        -- InCombatLockdown() still reports the old state inside these handlers.
        AV.inCombat = event == 'PLAYER_REGEN_DISABLED'
        if not AV.inCombat then
            AV.FlushOutOfCombat()
        end
        if AV.ready then
            forEachRow('UpdatePlayerState')
            forEachRow('UpdateThreat')
        end
        return
    end
    if not AV.ready then
        return
    end

    if event == 'PLAYER_ENTERING_WORLD' then
        applyScale()
        AV.Blizzard.HideReplaced()
        AV.PartyList.UpdateGroupFilter()
        AV.PartyList.RefreshAll()
        AV.PartyList.UpdateFormRows()
        AV.TargetBar.ForEach(function(bar)
            bar:Refresh()
        end)
        AV.playerCast:Update()
    elseif event == 'PLAYER_TARGET_CHANGED' then
        AV.TargetBar.target:Refresh()
        AV.PartyList.ForEachVisibleRow(function(row)
            row:UpdateCursor()
            row:UpdateCombo()
        end)
    elseif event == 'GROUP_ROSTER_UPDATE' then
        AV.PartyList.UpdateGroupFilter()
        AV.PartyList.RefreshAll()
        AV.PartyList.UpdateFormRows()
    elseif event == 'PARTY_LEADER_CHANGED' then
        AV.PartyList.ForEachVisibleRow(function(row)
            row:UpdateLeader()
            row:UpdateGroupRoles()
        end)
    elseif event == 'PARTY_LOOT_METHOD_CHANGED' then
        forEachRow('UpdateGroupRoles')
    elseif event == 'UPDATE_SHAPESHIFT_FORM' then
        forEachRow('UpdatePower')
        forEachRow('UpdateCombo')
        AV.PartyList.UpdateBackground()
    elseif event == 'UI_SCALE_CHANGED' or event == 'DISPLAY_SIZE_CHANGED' then
        applyScale()
    elseif event == 'PLAYER_UPDATE_RESTING' then
        forEachRow('UpdatePlayerState')
    elseif event == 'PLAYER_DEAD' or event == 'PLAYER_ALIVE' or event == 'PLAYER_UNGHOST' then
        forEachRow('UpdateState')
    elseif event:find('^READY_CHECK') then
        AV.PartyList.OnReadyCheck(event)
    elseif event == 'RAID_TARGET_UPDATE' then
        forEachRow('UpdateRaidMarker')
        AV.TargetBar.ForEach(function(bar)
            bar:UpdateRaidMarker()
        end)
    elseif event == 'PLAYER_ROLES_ASSIGNED' or event == 'ROLE_CHANGED_INFORM' then
        forEachRow('UpdateRole')
    elseif event == 'PET_UI_UPDATE' then
        AV.PartyList.ForEachVisiblePet(function(pet)
            pet:UpdateHappiness()
        end)
    else
        onUnitEvent(event, arg1, arg3)
    end
end))

SLASH_AZEROTHVISTA1 = '/av'
SlashCmdList.AZEROTHVISTA = function(msg)
    msg = (msg or ''):lower()
    if msg == 'unlock' then
        AV.EditMode.SetUnlocked(true)
    elseif msg == 'lock' then
        AV.EditMode.SetUnlocked(false)
    elseif msg:match('^scale') then
        local value = tonumber(msg:match('^scale%s+([%d%.]+)'))
        if value and value > 0.2 and value < 4 then
            AV.db.scale = value
            applyScale()
        end
        AV.Print('scale %.2f', AV.db.scale)
    elseif msg == 'demo' then
        AV.Demo.Toggle()
    elseif msg == 'gallery' or msg == 'gallery target' then
        AV.Demo.ToggleGallery(msg == 'gallery target' and 'target' or 'party')
    elseif msg == 'log' then
        AV.PrintLog(15)
    elseif msg == 'log clear' then
        AV.ClearLog()
    elseif msg:match('^style') then
        local requested = msg:match('^style%s+(%S+)')
        local match
        for name in pairs(AV.styles) do
            if requested and name:lower() == requested then
                match = name
            end
        end
        if match then
            AV.db.style = match
            ReloadUI()
        else
            local names = {}
            for name in pairs(AV.styles) do
                names[#names + 1] = name
            end
            table.sort(names)
            AV.Print('style is %s; available: %s', AV.db.style, table.concat(names, ', '))
        end
    elseif msg == 'reset' then
        AV.RunOutOfCombat(function()
            AV.db.positions = {}
            AV.EditMode.RestorePosition('party', AV.PartyList.anchor)
            AV.EditMode.RestorePosition('target', AV.TargetBar.target.anchor)
            AV.EditMode.RestorePosition('cast', AV.castAnchor)
        end)
    else
        AV.Print('/av demo | gallery [target] | style <name> | unlock | lock | scale <n> | reset | log [clear]  (Edit Mode also unlocks)')
    end
end
