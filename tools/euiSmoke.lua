-- Loads EorzeaUI against permissive WoW stubs and fires its startup events.
local root = ADDON_ROOT

local methodOverrides = {
    GetHeight = 768, GetWidth = 1366, GetFrameLevel = 1, IsShown = true, IsVisible = true, IsProtected = false,
    GetName = 'mock', GetScale = 1,
}

local newFrame
local function methodResolver(t, k)
    local v = methodOverrides[k]
    if v ~= nil then
        if v == false then return function() return nil end end
        return function() return v end
    end
    if k == 'SetScript' or k == 'HookScript' then
        return function(self, name, fn) rawset(self, '_' .. name, fn) end
    end
    -- Attributes are stored and fire OnAttributeChanged, as unit assignment relies on it.
    if k == 'SetAttribute' then
        return function(self, name, value)
            local attrs = rawget(self, '_attrs') or {}
            rawset(self, '_attrs', attrs)
            attrs[name] = value
            local hook = rawget(self, '_OnAttributeChanged')
            if hook then hook(self, name, value) end
        end
    end
    if k == 'GetAttribute' then
        return function(self, name)
            local attrs = rawget(self, '_attrs')
            return attrs and attrs[name]
        end
    end
    if k == 'GetPoint' then
        return function() return 'TOPLEFT', nil, 'TOPLEFT', 0, 0 end
    end
    if k == 'CreateTexture' or k == 'CreateFontString' or k == 'CreateMaskTexture' or k == 'GetStatusBarTexture' or k == 'GetParent'
        or k == 'CreateAnimationGroup' or k == 'CreateAnimation' then
        return function() return newFrame() end
    end
    return function() return nil end
end

local frameMeta = { __index = methodResolver }
newFrame = function() return setmetatable({}, frameMeta) end

local eventFrames = {}
CreateFrame = function(kind, name)
    local f = newFrame()
    if name then _G[name] = f end
    eventFrames[#eventFrames + 1] = f
    return f
end
UIParent = newFrame()
hooksecurefunc = function(t, name, hook)
    local original = t[name]
    rawset(t, name, function(...)
        local result = original(...)
        hook(...)
        return result
    end)
end
PlayerFrame = newFrame()
PlayerCastingBarFrame = newFrame()
InCombatLockdown = function() return false end
UnitExists = function() return true end
UnitName = function() return 'Zal', 'Brightforge' end
LOCALIZED_CLASS_NAMES_MALE = { PALADIN = 'Paladin' }
UnitLevel = function() return 11 end
UnitReaction = function() return 2 end
UnitClass = function() return 'Druid', 'DRUID' end
GetBonusBarOffset = function() return 1 end
RegisterStateDriver = function(frame, state, condition) STATE_DRIVER = condition end
UnitHealth = function() return 100 end
UnitHealthMax = function() return 200 end
UnitPower = function() return 50 end
GetComboPoints = function() return 3 end
UnitPowerMax = function() return 100 end
UnitGUID = function(u) return 'GUID-' .. tostring(u) end
UnitIsGroupLeader = function() return true end
CheckInteractDistance = function() return true end
UnitHealthPercent = function() return nil end
UnitCastingInfo = function() return nil end
UnitChannelInfo = function() return nil end
IsInRaid = function() return false end
IsInGroup = function() return true end
UnitAffectingCombat = function() return false end
IsResting = function() return true end
UnitIsConnected = function() return true end
UnitIsDead = function() return false end
UnitIsGhost = function() return false end
UnitIsDeadOrGhost = function() return false end
UnitPlayerControlled = function() return false end
UnitClassification = function() return 'elite' end
UnitIsDND = function() return false end
GetReadyCheckStatus = function() return 'waiting' end
GetRaidTargetIndex = function() return 8 end
UnitHasIncomingResurrection = function() return false end
UnitPhaseReason = function() return nil end
UnitInRange = function() return true, true end
UnitGroupRolesAssigned = function() return 'HEALER' end
UnitThreatSituation = function() return 2 end
UnitPowerType = function() return 3, 'ENERGY' end
UnitIsGroupAssistant = function() return true end
GetLootMethod = function() return 'master', 0, nil end
CreateUnitHealPredictionCalculator = function()
    return {
        SetDamageAbsorbClampMode = function() end,
        GetIncomingHeals = function() return 300 end,
        GetDamageAbsorbs = function() return 150, false end,
    }
end
UnitGetDetailedHealPrediction = function() end
C_Spell = { GetSpellPowerCost = function() return { { type = 3, cost = 35 } } end }
UnitIsPVP = function() return true end
UnitIsPVPFreeForAll = function() return false end
UnitFactionGroup = function() return 'Horde', 'Horde' end
UnitIsAFK = function() return true end
WATCHED = {}
RegisterUnitWatch = function(frame) WATCHED[#WATCHED + 1] = frame end
SetPortraitTexture = function(texture, unit) PORTRAIT_UNIT = unit end
HasPetUI = function() return true, true end
C_PetInfo = { GetPetHappiness = function() return 3, 125, 1 end }
C_IncomingSummon = { HasIncomingSummon = function() return true end, IncomingSummonStatus = function() return 1 end }
date = os.date
GetBuildInfo = function() return '1.60.1', '00000', 'Oct 1 2026', 16001 end
debugstack = function() return '' end
geterrorhandler = function() return function(err) error(err, 0) end end
EorzeaUILog = nil
RAID_CLASS_COLORS = { PALADIN = { r = 0.96, g = 0.55, b = 0.73 }, ROGUE = { r = 1, g = 0.96, b = 0.41 }, DRUID = { r = 1, g = 0.49, b = 0.04 } }
CLASS_ICON_TCOORDS = { PALADIN = { 0, 0.25, 0.5, 0.75 }, ROGUE = { 0.5, 0.75, 0, 0.25 }, DRUID = { 0.75, 1, 0, 0.25 } }
C_Timer = { NewTicker = function(_, fn) TICK = fn end, After = function(_, fn) fn() end }
C_AddOns = { IsAddOnLoaded = function() return false end, LoadAddOn = function() return true end }
C_CurveUtil = { CreateColorCurve = function() return newFrame() end }
CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
Enum = { StatusBarInterpolation = { ExponentialEaseOut = 1, Immediate = 0 }, StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 } }
EventRegistry = { RegisterCallback = function() end }
GameTooltip = newFrame()
CHAT = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) CHAT[#CHAT + 1] = msg end }
SlashCmdList = {}
ReloadUI = function() RELOADED = true end
EorzeaUIDB = {
    style = STYLE,
    colors = { [STYLE] = { hp = '#123456FF', reaction = { hostile = '#654321FF' } }, other = { hp = '#ABCDEFFF' } },
}
print = function(...) io.write(table.concat({ ... }, ' '), '\n') end

-- Load order comes from the .toc; XML files are skipped (templates only exist in the real client).
local function loadToc(dir, name, ns)
    local order = {}
    for line in io.lines(dir .. name .. '.toc') do
        local file = line:match('^%s*([^#%s].-%.lua)%s*$')
        if file then
            order[#order + 1] = file:gsub('\\', '/')
        end
    end
    assert(#order > 0, 'no lua files found in ' .. name .. '.toc')
    for _, file in ipairs(order) do
        local fn = assert(loadfile(dir .. file))
        fn(name, ns)
    end
end

local EUI = {}
loadToc(root, 'EorzeaUI', EUI)

-- Load-on-demand addons load from the sibling folder on the first LoadAddOn.
local loadedAddOns = {}
C_AddOns.LoadAddOn = function(name)
    if name ~= 'EorzeaUI_Gallery' then
        return false, 'MISSING'
    end
    if not loadedAddOns[name] then
        loadedAddOns[name] = true
        loadToc(root .. '../' .. name .. '/', name, {})
    end
    return true
end

local onEvent = eventFrames[#eventFrames]._OnEvent
assert(onEvent, 'no OnEvent captured')
onEvent(nil, 'ADDON_LOADED', 'EorzeaUI')
assert(EUI.ready, 'initialize did not complete')
-- Settings: missing keys take their defaults; saved ones are kept.
local Settings = EUI.Settings
assert(Settings.Get('style') == STYLE and Settings.Get('scale') == 1 and type(Settings.Get('positions')) == 'table',
    'settings defaults not applied')
-- The style's colour overrides reach the built frames and merge into nested palette tables by key;
-- another style's overrides are ignored.
local builtTarget = EUI.TargetBar.target.spec
assert(EUI.PartyList.style.hp.bar.fill.color == '#123456FF', 'hp colour override not applied')
assert(builtTarget.reactionColors.hostile == '#654321FF', 'nested colour override not applied')
assert(builtTarget.reactionColors.friendly == EUI.styles[STYLE].target.reactionColors.friendly, 'override dropped a sibling')
assert(EUI.styles[STYLE].party.hp.bar.fill.color ~= '#123456FF', 'override leaked into the registered style')
local heard
Settings.OnChange('positions.test', function(value) heard = value end)
Settings.Set('positions.test', 5)
assert(heard == 5 and Settings.Get('positions.test') == 5, 'settings set or listener failed')
assert(Settings.Get('missing.deep.path') == nil, 'missing path not nil')
Settings.Set('scale', 1.5)
assert(Settings.Get('scale') == 1.5, 'scale not set')
Settings.Reset('scale')
assert(Settings.Get('scale') == 1 and Settings.Default('positions') ~= Settings.Get('positions'), 'reset or default copy failed')
onEvent(nil, 'PLAYER_ENTERING_WORLD')
onEvent(nil, 'PLAYER_TARGET_CHANGED')
onEvent(nil, 'GROUP_ROSTER_UPDATE')
onEvent(nil, 'UNIT_HEALTH', 'player')
onEvent(nil, 'UNIT_POWER_UPDATE', 'player')
onEvent(nil, 'UNIT_SPELLCAST_START', 'player')
onEvent(nil, 'UNIT_TARGET', 'target')
onEvent(nil, 'PLAYER_UPDATE_RESTING')
onEvent(nil, 'PLAYER_REGEN_DISABLED')
onEvent(nil, 'PLAYER_REGEN_ENABLED')
onEvent(nil, 'UNIT_CONNECTION', 'player')
onEvent(nil, 'PLAYER_FLAGS_CHANGED', 'player')
onEvent(nil, 'UNIT_HEAL_PREDICTION', 'player')
onEvent(nil, 'UNIT_ABSORB_AMOUNT_CHANGED', 'player')
onEvent(nil, 'INCOMING_SUMMON_CHANGED', 'player')
onEvent(nil, 'RAID_TARGET_UPDATE')
onEvent(nil, 'UNIT_FACTION', 'player')
onEvent(nil, 'UNIT_THREAT_SITUATION_UPDATE', 'player')
onEvent(nil, 'PLAYER_ROLES_ASSIGNED')
onEvent(nil, 'PARTY_LOOT_METHOD_CHANGED')
onEvent(nil, 'UPDATE_SHAPESHIFT_FORM')
assert(STATE_DRIVER == '[bonusbar:1/2/3] shifted; caster', 'druid state driver not registered')
onEvent(nil, 'UNIT_SPELLCAST_START', 'player', 'cast-guid', 1234)
onEvent(nil, 'UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast-guid', 1234)
onEvent(nil, 'UNIT_SPELLCAST_STOP', 'player', 'cast-guid', 1234)
onEvent(nil, 'READY_CHECK')
onEvent(nil, 'READY_CHECK_CONFIRM', 'player')
onEvent(nil, 'READY_CHECK_FINISHED')
onEvent(nil, 'PLAYER_DEAD')
onEvent(nil, 'ADDON_ACTION_BLOCKED', 'EorzeaUI', 'TestFunction()')

-- Party rows and their pets are bound to fixed tokens.
local owner1 = _G.EorzeaUIPartyButton1
local owner2 = _G.EorzeaUIPartyButton2
local petButton1 = _G.EorzeaUIPartyPetButton1
local petButton2 = _G.EorzeaUIPartyPetButton2
assert(owner1 and owner2 and petButton1 and petButton2, 'party buttons not created')
-- 5 rows, 5 pet buttons, and the target, focus and their mini bars' click areas.
assert(#WATCHED == 14, 'party buttons not unit-watched: ' .. #WATCHED)
assert(owner1:GetAttribute('unit') == 'player', 'row 1 unit: ' .. tostring(owner1:GetAttribute('unit')))
assert(owner2:GetAttribute('unit') == 'party1', 'row 2 unit: ' .. tostring(owner2:GetAttribute('unit')))
assert(petButton1:GetAttribute('unit') == 'pet', 'player pet unit: ' .. tostring(petButton1:GetAttribute('unit')))
assert(petButton2:GetAttribute('unit') == 'partypet1', 'party pet unit: ' .. tostring(petButton2:GetAttribute('unit')))
assert(EUI.PartyList.PetForUnit('pet') and EUI.PartyList.PetForUnit('partypet1'), 'pet lookup missing')
assert(PORTRAIT_UNIT ~= nil, 'portrait never set')
onEvent(nil, 'UNIT_PET', 'player')
onEvent(nil, 'UNIT_HEALTH', 'pet')
onEvent(nil, 'UNIT_POWER_UPDATE', 'partypet1')
onEvent(nil, 'UNIT_DISPLAYPOWER', 'pet')
onEvent(nil, 'UNIT_PORTRAIT_UPDATE', 'pet')
onEvent(nil, 'UNIT_PORTRAIT_UPDATE', 'target')
onEvent(nil, 'UNIT_HAPPINESS', 'pet')
onEvent(nil, 'UNIT_NAME_UPDATE', 'pet')
onEvent(nil, 'PET_UI_UPDATE')
onEvent(nil, 'UNIT_SPELLCAST_START', 'pet')
onEvent(nil, 'UNIT_SPELLCAST_STOP', 'pet')
petButton1._OnShow()
petButton1._OnHide()

-- Secure snippets run against stand-in frame handles: row height = base + form + pet.
local function handle(frame)
    local h = { heights = {} }
    function h:GetAttribute(name) return frame:GetAttribute(name) end
    function h:SetAttribute(name, value) frame:SetAttribute(name, value) end
    function h:SetHeight(value) self.height = value end
    function h:GetFrameRef(label) return self.refs and self.refs[label] end
    return h
end
local function runSnippet(body, selfHandle, ...)
    local fn = assert(loadstring('local self, stateid, newstate = ...\n' .. body))
    fn(selfHandle, ...)
end
local ownerHandle = handle(owner1)
local petHandle = handle(petButton1)
petHandle.refs = { owner = ownerHandle }
owner1:SetAttribute('eui-form', false)
runSnippet(petButton1:GetAttribute('_onshow'), petHandle)
assert(ownerHandle.height == 46 + 29, 'pet show height: ' .. tostring(ownerHandle.height))
local driver
for _, frame in ipairs(eventFrames) do
    if frame:GetAttribute('_onstate-druidform') then driver = frame end
end
assert(driver, 'druid driver missing')
local driverHandle = handle(driver)
local owner2Handle = handle(owner2)
driverHandle.refs = { row1 = ownerHandle, row2 = owner2Handle }
owner1:SetAttribute('eui-player', true)
owner2:SetAttribute('eui-player', false)
driver:SetAttribute('rowCount', 2)
runSnippet(driver:GetAttribute('_onstate-druidform'), driverHandle, 'druidform', 'shifted')
assert(ownerHandle.height == 46 + 22 + 29, 'shifted with pet height: ' .. tostring(ownerHandle.height))
assert(owner2Handle.height == nil, 'druid snippet resized a party member row')
runSnippet(petButton1:GetAttribute('_onhide'), petHandle)
assert(ownerHandle.height == 46 + 22, 'pet hide height: ' .. tostring(ownerHandle.height))
runSnippet(driver:GetAttribute('_onstate-druidform'), driverHandle, 'druidform', 'caster')
assert(ownerHandle.height == 46, 'caster height: ' .. tostring(ownerHandle.height))
TICK()
EUI.EditMode.SetUnlocked(true)
EUI.EditMode.SetUnlocked(false)
SlashCmdList.EORZEAUI('demo')
assert(EUI.Demo.active, 'demo not active')
assert(EUI.PartyList.demoHeight == 5 * 46 + 22 + 2 * 29 + 4 * 13, 'demo height: ' .. tostring(EUI.PartyList.demoHeight))
SlashCmdList.EORZEAUI('demo')
assert(not EUI.Demo.active, 'demo still active')

-- Gallery: loads on the first toggle, builds each window once, and every state key has a sample.
SlashCmdList.EORZEAUI('gallery')
local Gallery = EorzeaUIGallery
assert(Gallery and Gallery.Window('party'), 'gallery not built')
local window = Gallery.Window('party')
SlashCmdList.EORZEAUI('gallery')
SlashCmdList.EORZEAUI('gallery')
assert(Gallery.Window('party') == window, 'gallery rebuilt')
SlashCmdList.EORZEAUI('gallery target')
assert(Gallery.Window('target'), 'target gallery not built')
for _, kind in ipairs({ 'party', 'target' }) do
    local _, missing = Gallery.Coverage(kind)
    assert(#missing == 0, kind .. ' gallery states without a sample: ' .. table.concat(missing, ', '))
end

-- Target bars: the live bars route events by unit; demo bars stay out of routing.
assert(EUI.TargetBar.ForUnit('target') == EUI.TargetBar.target, 'live target bar not routed')
assert(EUI.TargetBar.ForUnit('focus') == EUI.TargetBar.focus, 'live focus bar not routed')
local liveBars = 0
EUI.TargetBar.ForEach(function() liveBars = liveBars + 1 end)
assert(liveBars == 2, 'demo target bars registered as live: ' .. liveBars)
for _, unit in ipairs({ 'target', 'focus' }) do
    onEvent(nil, 'UNIT_HEALTH', unit)
    onEvent(nil, 'UNIT_SPELLCAST_INTERRUPTED', unit)
    onEvent(nil, 'UNIT_FLAGS', unit)
end
onEvent(nil, 'PLAYER_FLAGS_CHANGED', 'party1')
onEvent(nil, 'PLAYER_FOCUS_CHANGED')
onEvent(nil, 'RAID_TARGET_UPDATE')
TICK()
assert(#CHAT == 0, 'gallery printed: ' .. tostring(CHAT[1]))

-- Shared stacking: row heights follow sub-rows, and a full column wraps.
local stackRows = {}
local stackMembers = {
    { name = 'a', hp = 1, hpMax = 1, power = 1, powerMax = 1 },
    { name = 'b', hp = 1, hpMax = 1, power = 1, powerMax = 1, form = { powerType = 3, power = 1, powerMax = 1 } },
    { name = 'c', hp = 1, hpMax = 1, power = 1, powerMax = 1, pet = Gallery.party.Members()[3].pet },
}
for i in ipairs(stackMembers) do
    stackRows[i] = EorzeaUI.CreateDemoRow(UIParent, i)
end
assert(stackRows[2]:DemoHeight(stackMembers[2]) == 46 + 22, 'form row height')
assert(stackRows[3]:DemoHeight(stackMembers[3]) == 46 + 29, 'pet row height')
local columns, stackWidth, stackHeight = EorzeaUI.StackDemoRows(stackRows, stackMembers, UIParent)
assert(#columns == 1 and stackHeight == 46 + 68 + 75 + 2 * 13, 'one column height: ' .. stackHeight)
columns, stackWidth, stackHeight = EorzeaUI.StackDemoRows(stackRows, stackMembers, UIParent, 130)
assert(#columns == 2 and columns[2].x == 487 and stackWidth == 487 + 410, 'wrap columns: ' .. #columns)
assert(columns[1].height == 46 + 68 + 13 and columns[2].height == 75, 'wrap heights')
assert(Settings.Get('style') == STYLE, 'style not applied: ' .. tostring(Settings.Get('style')))
SlashCmdList.EORZEAUI('style azeroth')
assert(RELOADED and Settings.Get('style') == 'azeroth', 'style switch failed')
SlashCmdList.EORZEAUI('scale 1.2')
SlashCmdList.EORZEAUI('reset')
SlashCmdList.EORZEAUI('log')
assert(EorzeaUILog and #EorzeaUILog.entries > 0, 'log empty')
local blocked = false
for _, entry in ipairs(EorzeaUILog.entries) do
    if entry.msg:find('ADDON_ACTION_BLOCKED', 1, true) then blocked = true end
end
assert(blocked, 'blocked action not logged')
SlashCmdList.EORZEAUI('log clear')

-- Event routing: each event's outermost method calls on the spied frames, against ROUTES.
local spied = {
    row = EUI.PartyList.RowForUnit('player'),
    party1 = EUI.PartyList.RowForUnit('party1'),
    pet = EUI.PartyList.PetForUnit('pet'),
    target = EUI.TargetBar.target,
    focus = EUI.TargetBar.focus,
    targetCast = EUI.TargetBar.target.cast,
    focusCast = EUI.TargetBar.focus.cast,
    playerCast = EUI.playerCast,
}
local calls, depth = {}, 0
for label, object in pairs(spied) do
    assert(object, 'routing spy target missing: ' .. label)
    for name, fn in pairs(getmetatable(object).__index) do
        if type(fn) == 'function' then
            object[name] = function(...)
                if depth == 0 then calls[#calls + 1] = label .. ':' .. name end
                depth = depth + 1
                local results = { pcall(fn, ...) }
                depth = depth - 1
                assert(results[1], results[2])
                return unpack(results, 2)
            end
        end
    end
end
local function route(event, unit)
    calls = {}
    onEvent(nil, event, unit)
    table.sort(calls)
    return table.concat(calls, ' ')
end
local ROUTE_UNITS = { 'player', 'party1', 'pet', 'target', 'focus' }
local UNIT_ROUTE_EVENTS = {
    'UNIT_HEALTH', 'UNIT_MAXHEALTH', 'UNIT_POWER_UPDATE', 'UNIT_MAXPOWER', 'UNIT_DISPLAYPOWER',
    'UNIT_NAME_UPDATE', 'UNIT_LEVEL', 'UNIT_TARGET', 'UNIT_SPELLCAST_START', 'UNIT_SPELLCAST_STOP',
    'UNIT_SPELLCAST_FAILED', 'UNIT_SPELLCAST_INTERRUPTED', 'UNIT_SPELLCAST_CHANNEL_START',
    'UNIT_SPELLCAST_SUCCEEDED', 'UNIT_HEAL_PREDICTION', 'UNIT_ABSORB_AMOUNT_CHANGED', 'UNIT_CONNECTION',
    'UNIT_FLAGS', 'PLAYER_FLAGS_CHANGED', 'INCOMING_SUMMON_CHANGED', 'INCOMING_RESURRECT_CHANGED',
    'UNIT_PHASE', 'UNIT_FACTION', 'UNIT_THREAT_SITUATION_UPDATE', 'UNIT_PET', 'UNIT_PORTRAIT_UPDATE',
    'UNIT_HAPPINESS', 'UNIT_CLASSIFICATION_CHANGED',
}
local GLOBAL_ROUTE_EVENTS = {
    'PLAYER_ENTERING_WORLD', 'PLAYER_REGEN_DISABLED', 'PLAYER_REGEN_ENABLED', 'PLAYER_TARGET_CHANGED',
    'GROUP_ROSTER_UPDATE', 'PARTY_LEADER_CHANGED', 'UI_SCALE_CHANGED', 'DISPLAY_SIZE_CHANGED',
    'PLAYER_UPDATE_RESTING', 'PLAYER_DEAD', 'PLAYER_ALIVE', 'PLAYER_UNGHOST', 'READY_CHECK',
    'READY_CHECK_FINISHED', 'RAID_TARGET_UPDATE', 'PLAYER_ROLES_ASSIGNED', 'ROLE_CHANGED_INFORM',
    'PARTY_LOOT_METHOD_CHANGED', 'UPDATE_SHAPESHIFT_FORM', 'PET_UI_UPDATE', 'PLAYER_FOCUS_CHANGED',
    'COMBO_TARGET_CHANGED',
}
local cases = {}
for _, event in ipairs(UNIT_ROUTE_EVENTS) do
    for _, unit in ipairs(ROUTE_UNITS) do
        cases[#cases + 1] = { event, unit }
    end
end
for _, event in ipairs(GLOBAL_ROUTE_EVENTS) do
    cases[#cases + 1] = { event }
end
local routesFile = root .. 'tools/smokeRoutes.lua'
if os.getenv('EUI_RECORD_ROUTES') then
    local out = { '-- Expected event routing for euiSmoke.lua; regenerate with EUI_RECORD_ROUTES=1.', 'return {' }
    for _, case in ipairs(cases) do
        local key = case[1] .. ' ' .. (case[2] or '')
        out[#out + 1] = string.format('    [%q] = %q,', key, route(case[1], case[2]))
    end
    out[#out + 1] = '}'
    local file = assert(io.open(routesFile, 'w'))
    file:write(table.concat(out, '\n'), '\n')
    file:close()
end
local ROUTES = dofile(routesFile)
local mismatches = {}
for _, case in ipairs(cases) do
    local key = case[1] .. ' ' .. (case[2] or '')
    local got = route(case[1], case[2])
    if got ~= ROUTES[key] then
        mismatches[#mismatches + 1] = string.format('%s\n  want: %s\n  got:  %s', key, tostring(ROUTES[key]), got)
    end
end
assert(#mismatches == 0, 'event routing changed:\n' .. table.concat(mismatches, '\n'))
for _, object in pairs(spied) do
    for name in pairs(getmetatable(object).__index) do
        rawset(object, name, nil)
    end
end

-- Palettes: every colour the layout reads is set in each style.
local REQUIRED = {
    'party.hp.bar.fill.color', 'party.hp.offlineColor', 'party.power.bar.fill.color', 'party.power.colors',
    'party.cast.bar.fill.color', 'party.txtName.color', 'party.txtName.stroke', 'party.indicators.healPrediction.color',
    'party.indicators.healPrediction.absorbColor', 'party.background.color', 'target.bar.fill.color',
    'target.reactionColors', 'target.txtHpp.color', 'target.txtHpp.stroke', 'target.cast.failure.color',
    'target.cast.uninterruptible.color', 'target.comboPoints.color', 'target.healPrediction.color',
    'target.auras.groups.HARMFUL.dispelColors', 'focus.header.txtLabel.color', 'castBar.bar.fill.color',
}
local REACTIONS = { 'party', 'player', 'hostilePlayer', 'friendly', 'neutral', 'unfriendly', 'hostile', 'tapped' }
for _, name in ipairs({ 'vanadiel', 'azeroth' }) do
    local style = assert(EUI.styles[name], 'style missing: ' .. name)
    for _, path in ipairs(REQUIRED) do
        local value = style
        for key in path:gmatch('[^.]+') do
            value = type(value) == 'table' and value[key] or nil
        end
        assert(value ~= nil, name .. ' missing ' .. path)
    end
    for _, key in ipairs(REACTIONS) do
        assert(style.target.reactionColors[key], name .. ' missing reaction colour ' .. key)
    end
end

-- Raid: the player first, then the rest of subgroup 2 in raid order; the remaining rows are cleared.
IsInRaid = function() return true end
GetNumGroupMembers = function() return 6 end
local RAID_GROUPS = { 1, 2, 2, 1, 2, 2 }
GetRaidRosterInfo = function(i) return 'm' .. i, 0, RAID_GROUPS[i] end
UnitInRaid = function(unit) return unit == 'player' and 3 or nil end
UnitGUID = function(u) return u == 'raid3' and 'GUID-player' or 'GUID-' .. tostring(u) end
onEvent(nil, 'GROUP_ROSTER_UPDATE')
local raidUnits = {}
for i = 1, 5 do
    raidUnits[i] = tostring(_G['EorzeaUIPartyButton' .. i]:GetAttribute('unit'))
end
assert(table.concat(raidUnits, ',') == 'player,raid2,raid5,raid6,nil', 'raid rows: ' .. table.concat(raidUnits, ','))
assert(_G.EorzeaUIPartyPetButton2:GetAttribute('unit') == 'raidpet2', 'raid pet unit')
print('SMOKE OK')
