local addonName, EUI = ...

local DEFAULTS = {
    style = 'vanadiel',
    scale = 1,
    positions = {},
}

local RANGE_TICK = 0.25

local function loadSettings()
    EorzeaUIDB = EorzeaUIDB or {}
    for key, value in pairs(DEFAULTS) do
        if EorzeaUIDB[key] == nil then
            EorzeaUIDB[key] = type(value) == 'table' and {} or value
        end
    end
    EUI.db = EorzeaUIDB
end

local function applyScale()
    EUI.RunOutOfCombat(function()
        local scale = EUI.Style.RootScale()
        EUI.PartyList.anchor:SetScale(scale)
        EUI.TargetBar.target.anchor:SetScale(scale)
        EUI.TargetBar.focus.anchor:SetScale(scale)
        EUI.castAnchor:SetScale(scale)
    end, 'scale')
    if EorzeaUIGallery and EorzeaUIGallery.ApplyScale then
        EorzeaUIGallery.ApplyScale()
    end
end

local function createPlayerCastBar(style, fonts)
    local spec = style.castBar
    local anchor = CreateFrame('Frame', 'EorzeaUICastAnchor', UIParent)
    anchor:SetSize(spec.width, spec.height)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    EUI.castAnchor = anchor
    EUI.playerCast = EUI.CastBar.Create(anchor, 'player', spec, fonts, { 0, 0 })
end

-- APIs behind optional features; missing ones are logged once per session.
local FEATURE_APIS = {
    'IsResting', 'UnitIsConnected', 'UnitIsDead', 'UnitIsGhost', 'UnitIsAFK', 'UnitIsDND',
    'GetReadyCheckStatus', 'GetRaidTargetIndex', 'C_IncomingSummon', 'UnitHasIncomingResurrection',
    'UnitPhaseReason', 'UnitInRange', 'CreateUnitHealPredictionCalculator', 'UnitGetDetailedHealPrediction',
    'UnitCastingDuration', 'C_StringUtil', 'canaccessvalue', 'UnitGroupRolesAssigned', 'UnitIsPVP',
    'UnitIsPVPFreeForAll', 'UnitFactionGroup', 'UnitThreatSituation', 'GetThreatStatusColor',
    'UnitPowerType', 'UnitIsGroupAssistant', 'C_Spell', 'C_ActionBar', 'RegisterStateDriver',
    'RegisterUnitWatch', 'SetPortraitTexture', 'HasPetUI', 'C_PetInfo',
}

local function logCapabilities()
    local missing = {}
    for _, name in ipairs(FEATURE_APIS) do
        if _G[name] == nil then
            missing[#missing + 1] = name
        end
    end
    EUI.Log('capabilities: %s', #missing == 0 and 'all feature APIs present' or 'missing ' .. table.concat(missing, ', '))
end

local function initialize()
    if not EUI.styles[EUI.db.style] then
        EUI.db.style = DEFAULTS.style
    end
    local style = EUI.styles[EUI.db.style]
    local fonts = style.fonts
    EUI.LogSession()
    logCapabilities()
    EUI.inCombat = EUI.SafeBool(UnitAffectingCombat, 'player')

    local suf = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded('SleekUnitFrames')
    if suf then
        EUI.Print('Sleek Unit Frames is also loaded; both hide the same Blizzard frames. Disable one.')
    end

    EUI.PartyList.Create(style, fonts)
    EUI.TargetBar.Create(style, fonts)
    createPlayerCastBar(style, fonts)

    local partyBg = EUI.PartyList.background
    EUI.EditMode.Register('party', EUI.PartyList.anchor, 'Party', { partyBg.top, partyBg.bottom })
    EUI.EditMode.Register('target', EUI.TargetBar.target.anchor, 'Target')
    EUI.EditMode.Register('focus', EUI.TargetBar.focus.anchor, 'Focus')
    EUI.EditMode.Register('cast', EUI.castAnchor, 'Cast bar')
    EUI.EditMode.Initialize()

    EUI.Blizzard.HideReplaced()
    applyScale()

    C_Timer.NewTicker(RANGE_TICK, EUI.Guard('range ticker', function()
        EUI.PartyList.ForEachVisibleRow(function(row)
            row:UpdateRange()
        end)
        EUI.TargetBar.ForEach(function(bar)
            bar:UpdateIdentity()
            bar:UpdateThreat()
            bar:UpdateTargetOfTarget()
        end)
    end))

    EUI.ready = true
    EUI.PartyList.RefreshAll()
    EUI.TargetBar.ForEach(function(bar)
        bar:Refresh()
    end)
end

-- Unit events route to the party row, pet sub-row and target-style bar showing that unit.
local function onUnitEvent(event, unit, arg3, arg4, arg5)
    local row = EUI.PartyList.RowForUnit(unit)
    local pet = EUI.PartyList.PetForUnit(unit)
    local bar = EUI.TargetBar.ForUnit(unit)
    if event == 'UNIT_HEALTH' or event == 'UNIT_MAXHEALTH' then
        if row then row:UpdateHealth(event == 'UNIT_HEALTH') end
        if pet then pet:UpdateHealth(event == 'UNIT_HEALTH') end
        if bar then bar:UpdateHealth(event == 'UNIT_HEALTH') end
    elseif event == 'UNIT_POWER_UPDATE' or event == 'UNIT_MAXPOWER' or event == 'UNIT_DISPLAYPOWER' then
        if row then
            row:UpdatePower(event == 'UNIT_POWER_UPDATE')
        end
        if unit == 'player' then EUI.TargetBar.target:UpdateCombo() end
        if pet then pet:UpdatePower(event == 'UNIT_POWER_UPDATE') end
    elseif event == 'UNIT_PET' then
        -- unit is the owner, possibly by another token than its row's ('player' for a raidN row).
        EUI.PartyList.ForEachVisiblePet(function(visiblePet)
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
        if bar then
            bar:UpdateName()
            bar:UpdateLevel()
        end
    elseif event == 'UNIT_TARGET' then
        if bar then bar:UpdateTargetOfTarget() end
    elseif event == 'UNIT_HEAL_PREDICTION' or event == 'UNIT_ABSORB_AMOUNT_CHANGED' then
        if row then row:UpdateHealPrediction() end
        if bar then bar:UpdateHealPrediction() end
    elseif event == 'UNIT_CONNECTION' then
        if row then
            row:UpdateState()
            row:UpdateStatusIcon()
        end
    elseif event == 'UNIT_FLAGS' or event == 'PLAYER_FLAGS_CHANGED' then
        if row then
            row:UpdateFlags()
            row:UpdateState()
            row:UpdatePvP()
            row:UpdateStatusIcon()
        end
        if bar then
            bar:UpdateIdentity()
        end
        -- PLAYER_FLAGS_CHANGED may name the unit by another token (party1, raid3).
        if event == 'PLAYER_FLAGS_CHANGED' then
            EUI.TargetBar.ForEach(function(each)
                each:UpdateFlags()
            end)
        elseif bar then
            bar:UpdateFlags()
        end
    elseif event == 'UNIT_FACTION' then
        if row then row:UpdatePvP() end
        if bar then
            bar:UpdateIdentity()
            bar:UpdateLevel()
        end
        -- Whether you can attack a unit also follows your own faction and PvP state.
        if unit == 'player' then
            EUI.TargetBar.ForEach(function(each)
                each:UpdateLevel()
            end)
        end
    elseif event == 'UNIT_CLASSIFICATION_CHANGED' then
        if bar then bar:UpdateTier() end
    elseif event == 'UNIT_THREAT_SITUATION_UPDATE' then
        if row then row:UpdateThreat() end
    elseif event == 'INCOMING_SUMMON_CHANGED' or event == 'INCOMING_RESURRECT_CHANGED' or event == 'UNIT_PHASE' then
        if row then row:UpdateStatusIcon() end
    elseif event:find('^UNIT_SPELLCAST_') then
        if unit == 'player' then EUI.playerCast:Update() end
        if row then
            row:UpdateCast()
            row:UpdateCostPreview(event, arg3)
        end
        if pet then pet:UpdateCast() end
        if bar then
            if event == 'UNIT_SPELLCAST_INTERRUPTED' then
                bar.cast:ShowFailure(INTERRUPTED or 'Interrupted', arg5)
            elseif event == 'UNIT_SPELLCAST_FAILED' then
                bar.cast:ShowFailure(FAILED or 'Failed', arg4, true)
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
    'UNIT_CLASSIFICATION_CHANGED',
}

local GLOBAL_EVENTS = {
    'ADDON_LOADED', 'PLAYER_ENTERING_WORLD', 'PLAYER_REGEN_ENABLED', 'PLAYER_REGEN_DISABLED',
    'PLAYER_TARGET_CHANGED', 'GROUP_ROSTER_UPDATE', 'PARTY_LEADER_CHANGED', 'UI_SCALE_CHANGED',
    'DISPLAY_SIZE_CHANGED', 'PLAYER_UPDATE_RESTING', 'PLAYER_DEAD', 'PLAYER_ALIVE', 'PLAYER_UNGHOST',
    'READY_CHECK', 'READY_CHECK_CONFIRM', 'READY_CHECK_FINISHED', 'RAID_TARGET_UPDATE',
    'ADDON_ACTION_BLOCKED', 'ADDON_ACTION_FORBIDDEN', 'PLAYER_ROLES_ASSIGNED', 'ROLE_CHANGED_INFORM',
    'PARTY_LOOT_METHOD_CHANGED', 'UPDATE_SHAPESHIFT_FORM', 'PET_UI_UPDATE', 'PLAYER_FOCUS_CHANGED',
    'COMBO_TARGET_CHANGED',
}

local function forEachRow(method)
    EUI.PartyList.ForEachVisibleRow(function(row)
        row[method](row)
    end)
end

local events = CreateFrame('Frame')
-- Registering an event the client does not know raises an error.
for _, list in ipairs({ GLOBAL_EVENTS, UNIT_EVENTS }) do
    for _, name in ipairs(list) do
        local ok, err = pcall(events.RegisterEvent, events, name)
        if not ok then
            EUI.LogOnce('event:' .. name, 'event %s not registered: %s', name, tostring(err))
        end
    end
end

events:SetScript('OnEvent', EUI.Guard('OnEvent', function(_, event, arg1, arg2, arg3, arg4, arg5)
    if event == 'ADDON_LOADED' then
        if arg1 == addonName then
            EUI.BindLog()
            loadSettings()
            -- Secure frames cannot be created in combat (e.g. a /reload mid-fight).
            EUI.RunOutOfCombat(initialize)
            events:UnregisterEvent('ADDON_LOADED')
        end
        return
    end
    if event == 'ADDON_ACTION_BLOCKED' or event == 'ADDON_ACTION_FORBIDDEN' then
        if arg1 == addonName then
            EUI.Log('%s: %s', event, tostring(arg2))
        end
        return
    end
    if event == 'PLAYER_REGEN_ENABLED' or event == 'PLAYER_REGEN_DISABLED' then
        -- InCombatLockdown() still reports the old state inside these handlers.
        EUI.inCombat = event == 'PLAYER_REGEN_DISABLED'
        if not EUI.inCombat then
            EUI.FlushOutOfCombat()
        end
        if EUI.ready then
            forEachRow('UpdatePlayerState')
            forEachRow('UpdateThreat')
        end
        return
    end
    if not EUI.ready then
        return
    end

    if event == 'PLAYER_ENTERING_WORLD' then
        applyScale()
        EUI.Blizzard.HideReplaced()
        EUI.PartyList.OnRosterChanged()
        EUI.PartyList.RefreshAll()
        EUI.PartyList.UpdateFormRows()
        EUI.TargetBar.ForEach(function(bar)
            bar:Refresh()
        end)
        EUI.playerCast:Update()
    elseif event == 'PLAYER_TARGET_CHANGED' then
        EUI.TargetBar.target:Refresh()
        EUI.PartyList.ForEachVisibleRow(function(row)
            row:UpdateCursor()
        end)
    elseif event == 'COMBO_TARGET_CHANGED' then
        EUI.TargetBar.target:UpdateCombo()
    elseif event == 'PLAYER_FOCUS_CHANGED' then
        EUI.TargetBar.focus:Refresh()
    elseif event == 'GROUP_ROSTER_UPDATE' then
        EUI.PartyList.OnRosterChanged()
        EUI.PartyList.RefreshAll()
        EUI.PartyList.UpdateFormRows()
    elseif event == 'PARTY_LEADER_CHANGED' then
        EUI.PartyList.ForEachVisibleRow(function(row)
            row:UpdateLeader()
            row:UpdateGroupRoles()
        end)
    elseif event == 'PARTY_LOOT_METHOD_CHANGED' then
        forEachRow('UpdateGroupRoles')
    elseif event == 'UPDATE_SHAPESHIFT_FORM' then
        forEachRow('UpdatePower')
        EUI.TargetBar.target:UpdateCombo()
        EUI.PartyList.UpdateBackground()
    elseif event == 'UI_SCALE_CHANGED' or event == 'DISPLAY_SIZE_CHANGED' then
        applyScale()
    elseif event == 'PLAYER_UPDATE_RESTING' then
        forEachRow('UpdatePlayerState')
    elseif event == 'PLAYER_DEAD' or event == 'PLAYER_ALIVE' or event == 'PLAYER_UNGHOST' then
        forEachRow('UpdateState')
    elseif event:find('^READY_CHECK') then
        EUI.PartyList.OnReadyCheck(event)
    elseif event == 'RAID_TARGET_UPDATE' then
        forEachRow('UpdateRaidMarker')
        EUI.TargetBar.ForEach(function(bar)
            bar:UpdateRaidMarker()
        end)
    elseif event == 'PLAYER_ROLES_ASSIGNED' or event == 'ROLE_CHANGED_INFORM' then
        forEachRow('UpdateRole')
    elseif event == 'PET_UI_UPDATE' then
        EUI.PartyList.ForEachVisiblePet(function(pet)
            pet:UpdateHappiness()
        end)
    else
        onUnitEvent(event, arg1, arg3, arg4, arg5)
    end
end))

SLASH_EORZEAUI1 = '/eui'
SlashCmdList.EORZEAUI = function(msg)
    msg = (msg or ''):lower()
    if msg == 'unlock' then
        EUI.EditMode.SetUnlocked(true)
    elseif msg == 'lock' then
        EUI.EditMode.SetUnlocked(false)
    elseif msg:match('^scale') then
        local value = tonumber(msg:match('^scale%s+([%d%.]+)'))
        if value and value > 0.2 and value < 4 then
            EUI.db.scale = value
            applyScale()
        end
        EUI.Print('scale %.2f', EUI.db.scale)
    elseif msg == 'demo' then
        EUI.Demo.Toggle()
    elseif msg == 'gallery' or msg == 'gallery target' then
        EUI.Demo.ToggleGallery(msg == 'gallery target' and 'target' or 'party')
    elseif msg == 'log' then
        EUI.PrintLog(15)
    elseif msg == 'log clear' then
        EUI.ClearLog()
    elseif msg:match('^style') then
        local requested = msg:match('^style%s+(%S+)')
        local match
        for name in pairs(EUI.styles) do
            if requested and name:lower() == requested then
                match = name
            end
        end
        if match then
            EUI.db.style = match
            ReloadUI()
        else
            local names = {}
            for name in pairs(EUI.styles) do
                names[#names + 1] = name
            end
            table.sort(names)
            EUI.Print('style is %s; available: %s', EUI.db.style, table.concat(names, ', '))
        end
    elseif msg == 'reset' then
        EUI.RunOutOfCombat(function()
            EUI.db.positions = {}
            EUI.EditMode.RestorePosition('party', EUI.PartyList.anchor)
            EUI.EditMode.RestorePosition('target', EUI.TargetBar.target.anchor)
            EUI.EditMode.RestorePosition('focus', EUI.TargetBar.focus.anchor)
            EUI.EditMode.RestorePosition('cast', EUI.castAnchor)
        end)
    else
        EUI.Print('/eui demo | gallery [target] | style <name> | unlock | lock | scale <n> | reset | log [clear]  (Edit Mode also unlocks)')
    end
end
