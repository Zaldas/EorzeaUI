local addonName, EUI = ...

local Settings = EUI.Settings

local RANGE_TICK = 0.25

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
    'UnitCastingDuration', 'UnitInOtherParty', 'C_StringUtil', 'canaccessvalue', 'UnitGroupRolesAssigned', 'UnitIsPVP',
    'UnitIsPVPFreeForAll', 'UnitFactionGroup', 'UnitThreatSituation', 'GetThreatStatusColor',
    'UnitPowerType', 'UnitIsGroupAssistant', 'C_Spell', 'C_ActionBar', 'RegisterStateDriver',
    'RegisterUnitWatch', 'SetPortraitTexture', 'HasPetUI', 'C_PetInfo', 'UnitHealthPercent', 'C_CurveUtil',
    'CurveConstants', 'UnitDetailedThreatSituation', 'UnitReaction', 'UnitIsCorpse', 'HasLFGRestrictions',
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

-- Blizzard plays this from the target and focus frames' OnHide, which never fires while they sit
-- in the hidden parent. Soft target changes stay silent, as there.
local hadUnit = {}
local function checkUnitLost(unit)
    local exists = UnitExists(unit) == true
    if hadUnit[unit] and not exists and not (IsTargetLoose and IsTargetLoose())
        and PlaySound and SOUNDKIT and SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT then
        PlaySound(SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT, nil, true)
    end
    hadUnit[unit] = exists
end

local function seedLostUnits()
    hadUnit.target = UnitExists('target') == true
    hadUnit.focus = UnitExists('focus') == true
end

local function initialize()
    if not EUI.styles[Settings.Get('style')] then
        Settings.Reset('style')
    end
    local styleName = Settings.Get('style')
    local style = EUI.StyleKit.BuildStyle(styleName, Settings.Get('colors.' .. styleName))
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

    applyScale()
    Settings.OnChange('scale', applyScale)

    C_Timer.NewTicker(RANGE_TICK, EUI.Guard('range ticker', function()
        EUI.PartyList.ForEachVisibleRow(function(row)
            row:UpdateRange()
        end)
        EUI.PartyList.ForEachVisiblePet(function(pet)
            pet:UpdateRange()
        end)
        EUI.TargetBar.ForEach(function(bar)
            bar:UpdateIdentity()
            bar:UpdateThreat()
            bar:UpdateTargetOfTarget()
        end)
    end))

    EUI.ready = true
    -- Last, so a failed setup leaves Blizzard's frames in place.
    EUI.Blizzard.HideReplaced()
    EUI.PartyList.RefreshAll()
    EUI.TargetBar.ForEach(function(bar)
        bar:Refresh()
    end)
    seedLostUnits()
end

local function forEachRow(method)
    EUI.PartyList.ForEachVisibleRow(function(row)
        row[method](row)
    end)
end

local function forEachBar(method)
    EUI.TargetBar.ForEach(function(bar)
        bar[method](bar)
    end)
end

-- Unit events, by the frames showing the event's unit: row (party row), pet (pet sub-row), bar
-- (target or focus bar). Each is a method name, a list of them, or fn(frame, event, arg3, arg4,
-- arg5). smooth, when set, is passed to named methods (UpdateHealth/UpdatePower ease the change).
-- also(unit, event, arg3, arg4, arg5) runs once per event, for frames not tied to the unit.
local UNIT_ROUTES = {
    UNIT_HEALTH = { row = 'UpdateHealth', pet = 'UpdateHealth', bar = 'UpdateHealth', smooth = true },
    UNIT_MAXHEALTH = { row = 'UpdateHealth', pet = 'UpdateHealth', bar = 'UpdateHealth', smooth = false },
    UNIT_NAME_UPDATE = { row = 'UpdateName', pet = 'UpdateName', bar = { 'UpdateName', 'UpdateLevel' } },
    -- The difficulty colour of every bar's level follows the player's level.
    UNIT_LEVEL = {
        row = 'UpdateName',
        pet = 'UpdateName',
        bar = { 'UpdateName', 'UpdateLevel' },
        also = function(unit)
            if unit == 'player' then
                forEachBar('UpdateLevel')
            end
        end,
    },
    UNIT_TARGET = { bar = 'UpdateTargetOfTarget' },
    UNIT_HEAL_PREDICTION = { row = 'UpdateHealPrediction', bar = 'UpdateHealPrediction' },
    UNIT_ABSORB_AMOUNT_CHANGED = { row = 'UpdateHealPrediction', bar = 'UpdateHealPrediction' },
    UNIT_CONNECTION = { row = { 'UpdateState', 'UpdateStatusIcon' } },
    UNIT_FLAGS = {
        row = { 'UpdateFlags', 'UpdateState', 'UpdatePvP', 'UpdateStatusIcon' },
        bar = { 'UpdateIdentity', 'UpdateFlags', 'UpdateLevel' },
    },
    -- May name the unit by another token (party1, raid3), so every bar rechecks its flags.
    PLAYER_FLAGS_CHANGED = {
        row = { 'UpdateFlags', 'UpdateState', 'UpdatePvP', 'UpdateStatusIcon' },
        bar = 'UpdateIdentity',
        also = function()
            forEachBar('UpdateFlags')
        end,
    },
    -- Whether you can attack a unit also follows your own faction and PvP state.
    UNIT_FACTION = {
        row = 'UpdatePvP',
        bar = { 'UpdateIdentity', 'UpdateLevel' },
        also = function(unit)
            if unit == 'player' then
                forEachBar('UpdateLevel')
            end
        end,
    },
    UNIT_CLASSIFICATION_CHANGED = { bar = 'UpdateTier' },
    UNIT_THREAT_SITUATION_UPDATE = { row = 'UpdateThreat' },
    INCOMING_SUMMON_CHANGED = { row = 'UpdateStatusIcon' },
    INCOMING_RESURRECT_CHANGED = { row = 'UpdateStatusIcon' },
    UNIT_PHASE = { row = { 'UpdateStatusIcon', 'UpdateRange' } },
    -- unit is the owner, possibly by another token than its row's ('player' for a raidN row).
    UNIT_PET = {
        also = function()
            EUI.PartyList.ForEachVisiblePet(function(pet)
                pet:Refresh()
            end)
        end,
    },
    UNIT_PORTRAIT_UPDATE = { pet = 'UpdatePortrait', bar = 'UpdateIcon' },
    UNIT_HAPPINESS = { pet = 'UpdateHappiness' },
}

local function playerPowerChanged(unit)
    if unit == 'player' then
        EUI.TargetBar.target:UpdateCombo()
    end
end
UNIT_ROUTES.UNIT_POWER_UPDATE = { row = 'UpdatePower', pet = 'UpdatePower', smooth = true, also = playerPowerChanged }
UNIT_ROUTES.UNIT_MAXPOWER = { row = 'UpdatePower', pet = 'UpdatePower', smooth = false, also = playerPowerChanged }
UNIT_ROUTES.UNIT_DISPLAYPOWER = UNIT_ROUTES.UNIT_MAXPOWER

-- Interrupted and failed casts hold the bar with a label; other cast events update it.
local function castEvent(cast, event, failedCastBarID, interruptedCastBarID)
    if event == 'UNIT_SPELLCAST_INTERRUPTED' then
        cast:ShowFailure(INTERRUPTED or 'Interrupted', interruptedCastBarID)
    elseif event == 'UNIT_SPELLCAST_FAILED' then
        cast:ShowFailure(FAILED or 'Failed', failedCastBarID, true)
    else
        cast:Update()
    end
end

-- Payload after unit and castGUID: spellID, then FAILED's castBarID, or INTERRUPTED's
-- interruptedBy and castBarID.
local CAST_ROUTE = {
    row = function(row, event, spellID, failedCastBarID, interruptedCastBarID)
        if row.cast then
            castEvent(row.cast, event, failedCastBarID, interruptedCastBarID)
        end
        row:UpdateCostPreview(event, spellID)
    end,
    pet = function(pet, event, _, failedCastBarID, interruptedCastBarID)
        castEvent(pet.cast, event, failedCastBarID, interruptedCastBarID)
    end,
    bar = function(bar, event, _, failedCastBarID, interruptedCastBarID)
        castEvent(bar.cast, event, failedCastBarID, interruptedCastBarID)
    end,
    also = function(unit, event, _, failedCastBarID, interruptedCastBarID)
        if unit == 'player' then
            castEvent(EUI.playerCast, event, failedCastBarID, interruptedCastBarID)
        end
    end,
}
for _, name in ipairs({
    'UNIT_SPELLCAST_START', 'UNIT_SPELLCAST_STOP', 'UNIT_SPELLCAST_FAILED', 'UNIT_SPELLCAST_INTERRUPTED',
    'UNIT_SPELLCAST_DELAYED', 'UNIT_SPELLCAST_CHANNEL_START', 'UNIT_SPELLCAST_CHANNEL_STOP',
    'UNIT_SPELLCAST_CHANNEL_UPDATE', 'UNIT_SPELLCAST_SUCCEEDED', 'UNIT_SPELLCAST_INTERRUPTIBLE',
    'UNIT_SPELLCAST_NOT_INTERRUPTIBLE',
}) do
    UNIT_ROUTES[name] = CAST_ROUTE
end

local function runAction(frame, action, route, event, arg3, arg4, arg5)
    if not frame or not action then
        return
    end
    if type(action) == 'function' then
        action(frame, event, arg3, arg4, arg5)
        return
    end
    if type(action) == 'string' then
        frame[action](frame, route.smooth)
        return
    end
    for _, method in ipairs(action) do
        frame[method](frame, route.smooth)
    end
end

local function onUnitEvent(route, event, unit, arg3, arg4, arg5)
    runAction(route.row and EUI.PartyList.RowForUnit(unit), route.row, route, event, arg3, arg4, arg5)
    runAction(route.pet and EUI.PartyList.PetForUnit(unit), route.pet, route, event, arg3, arg4, arg5)
    runAction(route.bar and EUI.TargetBar.ForUnit(unit), route.bar, route, event, arg3, arg4, arg5)
    if route.also then
        route.also(unit, event, arg3, arg4, arg5)
    end
end

local function refreshRoster()
    EUI.PartyList.OnRosterChanged()
    EUI.PartyList.RefreshAll()
    EUI.PartyList.UpdateFormRows()
end

local function updateRowStates()
    forEachRow('UpdateState')
end

local function updateRoles()
    forEachRow('UpdateRole')
end

local function readyCheck(event)
    EUI.PartyList.OnReadyCheck(event)
end

-- Events with no unit, run once EUI.ready; fn(event).
local GLOBAL_ROUTES = {
    PLAYER_ENTERING_WORLD = function()
        applyScale()
        EUI.Blizzard.HideReplaced()
        refreshRoster()
        forEachBar('Refresh')
        EUI.playerCast:Update()
        seedLostUnits()
    end,
    PLAYER_TARGET_CHANGED = function()
        checkUnitLost('target')
        EUI.TargetBar.target:Refresh()
        forEachRow('UpdateCursor')
        EUI.PartyList.ForEachVisiblePet(function(pet)
            pet:UpdateCursor()
        end)
    end,
    COMBO_TARGET_CHANGED = function()
        EUI.TargetBar.target:UpdateCombo()
    end,
    PLAYER_FOCUS_CHANGED = function()
        checkUnitLost('focus')
        EUI.TargetBar.focus:Refresh()
    end,
    -- CompactPartyFrame is created when raid-style party frames are first needed.
    GROUP_ROSTER_UPDATE = function()
        EUI.Blizzard.HideReplaced()
        refreshRoster()
    end,
    PARTY_LEADER_CHANGED = function()
        EUI.PartyList.ForEachVisibleRow(function(row)
            row:UpdateLeader()
            row:UpdateGroupRoles()
        end)
    end,
    PARTY_LOOT_METHOD_CHANGED = function()
        forEachRow('UpdateGroupRoles')
    end,
    UPDATE_SHAPESHIFT_FORM = function()
        forEachRow('UpdatePower')
        EUI.TargetBar.target:UpdateCombo()
        EUI.PartyList.UpdateBackground()
    end,
    UI_SCALE_CHANGED = applyScale,
    DISPLAY_SIZE_CHANGED = applyScale,
    PLAYER_UPDATE_RESTING = function()
        forEachRow('UpdatePlayerState')
    end,
    PLAYER_DEAD = updateRowStates,
    PLAYER_ALIVE = updateRowStates,
    PLAYER_UNGHOST = updateRowStates,
    READY_CHECK = readyCheck,
    READY_CHECK_CONFIRM = readyCheck,
    READY_CHECK_FINISHED = readyCheck,
    RAID_TARGET_UPDATE = function()
        forEachRow('UpdateRaidMarker')
        forEachBar('UpdateRaidMarker')
    end,
    PLAYER_ROLES_ASSIGNED = updateRoles,
    ROLE_CHANGED_INFORM = updateRoles,
    PET_UI_UPDATE = function()
        EUI.PartyList.ForEachVisiblePet(function(pet)
            pet:UpdateHappiness()
        end)
    end,
}

-- Handled in OnEvent before EUI.ready.
local STARTUP_EVENTS = {
    'ADDON_LOADED', 'ADDON_ACTION_BLOCKED', 'ADDON_ACTION_FORBIDDEN', 'PLAYER_REGEN_ENABLED', 'PLAYER_REGEN_DISABLED',
}

local events = CreateFrame('Frame')
-- Registering an event the client does not know raises an error.
local function register(name)
    local ok, err = pcall(events.RegisterEvent, events, name)
    if not ok then
        EUI.LogOnce('event:' .. name, 'event %s not registered: %s', name, tostring(err))
    end
end
for _, name in ipairs(STARTUP_EVENTS) do
    register(name)
end
for _, routes in ipairs({ GLOBAL_ROUTES, UNIT_ROUTES }) do
    for name in pairs(routes) do
        register(name)
    end
end

events:SetScript('OnEvent', EUI.Guard('OnEvent', function(_, event, arg1, arg2, arg3, arg4, arg5)
    if event == 'ADDON_LOADED' then
        if arg1 == addonName then
            EUI.BindLog()
            Settings.Load()
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
    local global = GLOBAL_ROUTES[event]
    if global then
        global(event)
        return
    end
    local route = UNIT_ROUTES[event]
    if route then
        onUnitEvent(route, event, arg1, arg3, arg4, arg5)
    end
end))

SLASH_EORZEAUI1 = '/eui'
SlashCmdList.EORZEAUI = EUI.Guard('slash', function(msg)
    msg = (msg or ''):lower()
    if not EUI.ready and not msg:match('^log') then
        EUI.Print('not set up yet; /eui log shows why')
        return
    end
    if msg == 'unlock' then
        EUI.EditMode.SetUnlocked(true)
    elseif msg == 'lock' then
        EUI.EditMode.SetUnlocked(false)
    elseif msg:match('^scale') then
        local value = tonumber(msg:match('^scale%s+([%d%.]+)'))
        if value and value > 0.2 and value < 4 then
            Settings.Set('scale', value)
        end
        EUI.Print('scale %.2f', Settings.Get('scale'))
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
            Settings.Set('style', match)
            ReloadUI()
        else
            local names = {}
            for name in pairs(EUI.styles) do
                names[#names + 1] = name
            end
            table.sort(names)
            EUI.Print('style is %s; available: %s', Settings.Get('style'), table.concat(names, ', '))
        end
    elseif msg == 'reset' then
        EUI.RunOutOfCombat(function()
            Settings.Reset('positions')
            EUI.EditMode.RestorePosition('party', EUI.PartyList.anchor)
            EUI.EditMode.RestorePosition('target', EUI.TargetBar.target.anchor)
            EUI.EditMode.RestorePosition('focus', EUI.TargetBar.focus.anchor)
            EUI.EditMode.RestorePosition('cast', EUI.castAnchor)
        end)
    else
        EUI.Print('/eui demo | gallery [target] | style <name> | unlock | lock | scale <n> | reset | log [clear]  (Edit Mode also unlocks)')
    end
end)
