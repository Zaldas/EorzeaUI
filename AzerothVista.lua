local addonName, AV = ...

local DEFAULTS = {
    style = 'xiv',
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
        AV.TargetBar.anchor:SetScale(scale)
        AV.castAnchor:SetScale(scale)
    end, 'scale')
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

local function initialize()
    if not AV.styles[AV.db.style] then
        AV.db.style = DEFAULTS.style
    end
    local style = AV.styles[AV.db.style]
    local fonts = style.fonts

    local suf = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded('SleekUnitFrames')
    if suf then
        AV.Print('Sleek Unit Frames is also loaded; both hide the same Blizzard frames. Disable one.')
    end

    AV.PartyList.Create(style, fonts)
    AV.TargetBar.Create(style, fonts)
    createPlayerCastBar(style, fonts)

    AV.EditMode.Register('party', AV.PartyList.anchor, 'Party')
    AV.EditMode.Register('target', AV.TargetBar.anchor, 'Target')
    AV.EditMode.Register('cast', AV.castAnchor, 'Cast bar')
    AV.EditMode.Initialize()

    AV.Blizzard.HideReplaced()
    applyScale()

    C_Timer.NewTicker(RANGE_TICK, function()
        AV.PartyList.ForEachVisibleRow(function(row)
            row:UpdateRange()
        end)
        AV.TargetBar.UpdateTargetOfTarget()
    end)

    AV.ready = true
    AV.PartyList.RefreshAll()
    AV.TargetBar.Refresh()
end

-- Unit events route to the party row showing that unit and/or the target bar.
local function onUnitEvent(event, unit)
    local row = AV.PartyList.RowForUnit(unit)
    if event == 'UNIT_HEALTH' or event == 'UNIT_MAXHEALTH' then
        if row then row:UpdateHealth(event == 'UNIT_HEALTH') end
        if unit == 'target' then AV.TargetBar.UpdateHealth(event == 'UNIT_HEALTH') end
    elseif event == 'UNIT_POWER_UPDATE' or event == 'UNIT_MAXPOWER' or event == 'UNIT_DISPLAYPOWER' then
        if row then row:UpdatePower(event == 'UNIT_POWER_UPDATE') end
    elseif event == 'UNIT_NAME_UPDATE' or event == 'UNIT_LEVEL' then
        if row then row:UpdateName() end
        if unit == 'target' then AV.TargetBar.Refresh() end
    elseif event == 'UNIT_TARGET' then
        if unit == 'target' then AV.TargetBar.UpdateTargetOfTarget() end
    elseif event:find('^UNIT_SPELLCAST_') then
        if unit == 'player' then AV.playerCast:Update() end
        if unit == 'target' then AV.TargetBar.cast:Update() end
    end
end

local UNIT_EVENTS = {
    'UNIT_HEALTH', 'UNIT_MAXHEALTH', 'UNIT_POWER_UPDATE', 'UNIT_MAXPOWER', 'UNIT_DISPLAYPOWER',
    'UNIT_NAME_UPDATE', 'UNIT_LEVEL', 'UNIT_TARGET',
    'UNIT_SPELLCAST_START', 'UNIT_SPELLCAST_STOP', 'UNIT_SPELLCAST_FAILED', 'UNIT_SPELLCAST_INTERRUPTED',
    'UNIT_SPELLCAST_DELAYED', 'UNIT_SPELLCAST_CHANNEL_START', 'UNIT_SPELLCAST_CHANNEL_STOP',
    'UNIT_SPELLCAST_CHANNEL_UPDATE',
}

local events = CreateFrame('Frame')
events:RegisterEvent('ADDON_LOADED')
events:RegisterEvent('PLAYER_ENTERING_WORLD')
events:RegisterEvent('PLAYER_REGEN_ENABLED')
events:RegisterEvent('PLAYER_TARGET_CHANGED')
events:RegisterEvent('GROUP_ROSTER_UPDATE')
events:RegisterEvent('PARTY_LEADER_CHANGED')
events:RegisterEvent('UI_SCALE_CHANGED')
events:RegisterEvent('DISPLAY_SIZE_CHANGED')
for _, name in ipairs(UNIT_EVENTS) do
    events:RegisterEvent(name)
end

events:SetScript('OnEvent', function(_, event, arg1)
    if event == 'ADDON_LOADED' then
        if arg1 == addonName then
            loadSettings()
            -- Secure frames cannot be created in combat (e.g. a /reload mid-fight).
            AV.RunOutOfCombat(initialize)
            events:UnregisterEvent('ADDON_LOADED')
        end
        return
    end
    if event == 'PLAYER_REGEN_ENABLED' then
        AV.FlushOutOfCombat()
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
        AV.TargetBar.Refresh()
        AV.playerCast:Update()
    elseif event == 'PLAYER_TARGET_CHANGED' then
        AV.TargetBar.Refresh()
        AV.PartyList.ForEachVisibleRow(function(row)
            row:UpdateCursor()
        end)
    elseif event == 'GROUP_ROSTER_UPDATE' then
        AV.PartyList.UpdateGroupFilter()
        AV.PartyList.RefreshAll()
    elseif event == 'PARTY_LEADER_CHANGED' then
        AV.PartyList.ForEachVisibleRow(function(row)
            row:UpdateLeader()
        end)
    elseif event == 'UI_SCALE_CHANGED' or event == 'DISPLAY_SIZE_CHANGED' then
        applyScale()
    else
        onUnitEvent(event, arg1)
    end
end)

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
            AV.EditMode.RestorePosition('target', AV.TargetBar.anchor)
            AV.EditMode.RestorePosition('cast', AV.castAnchor)
        end)
    else
        AV.Print('/av demo | style <name> | unlock | lock | scale <n> | reset  (Edit Mode also unlocks)')
    end
end
