-- Loads EorzeaUI against permissive WoW stubs and fires its startup events.
local root = ADDON_ROOT

-- WoW's xpcall forwards extra arguments to the function; stock Lua 5.1's does not.
do
    local stockXpcall = xpcall
    xpcall = function(fn, handler, ...)
        local args, count = { ... }, select('#', ...)
        return stockXpcall(function() return fn(unpack(args, 1, count)) end, handler)
    end
end

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
CreateFrame = function(kind, name, parent, template)
    local f = newFrame()
    if name then _G[name] = f end
    eventFrames[#eventFrames + 1] = f
    if template == 'SecureGroupHeaderTemplate' then
        -- As SecureGroupHeader_Update: a startingIndex below 1 builds 1 - startingIndex buttons.
        local setAttribute = f.SetAttribute
        rawset(f, 'SetAttribute', function(self, attr, value)
            setAttribute(self, attr, value)
            if attr == 'startingIndex' and value < 1 then
                for i = 1, 1 - value do
                    if not rawget(self, i) then
                        rawset(self, i, CreateFrame('Button', name .. 'UnitButton' .. i, self, self:GetAttribute('template')))
                    end
                end
            end
        end)
    end
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
STATE_DRIVERS = {}
RegisterStateDriver = function(frame, state, condition)
    STATE_DRIVERS[#STATE_DRIVERS + 1] = { frame = frame, state = state, condition = condition }
    if state == 'druidform' then STATE_DRIVER = condition end
end
UnitHealth = function() return 100 end
UnitHealthMax = function() return 200 end
UnitPower = function() return 50 end
GetComboPoints = function() return 3 end
UnitPowerMax = function() return 100 end
UnitGUID = function(u) return 'GUID-' .. tostring(u) end
UnitIsGroupLeader = function() return true end
CheckInteractDistance = function() return true end
UnitHealthPercent = function() return nil end
-- Idle cast info returns no values at all, as in the client.
UnitCastingInfo = function() end
UnitChannelInfo = function() end
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
-- Guarded errors are collected; the run fails at the end if any were reported.
ERRORS = {}
geterrorhandler = function() return function(err) ERRORS[#ERRORS + 1] = tostring(err) end end
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
SOUNDKIT = { INTERFACE_SOUND_LOST_TARGET_UNIT = 684 }
SOUNDS = {}
PlaySound = function(kit) SOUNDS[#SOUNDS + 1] = kit end
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
driverHandle.refs = { player = ownerHandle }
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
    rowCast = EUI.PartyList.RowForUnit('player').cast,
    party1Cast = EUI.PartyList.RowForUnit('party1').cast,
    petCast = EUI.PartyList.PetForUnit('pet').cast,
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

-- Losing the target or focus plays Blizzard's sound once; a soft target change does not.
SOUNDS = {}
local unitExists = UnitExists
onEvent(nil, 'PLAYER_TARGET_CHANGED')
UnitExists = function(unit) return unit ~= 'target' end
onEvent(nil, 'PLAYER_TARGET_CHANGED')
onEvent(nil, 'PLAYER_TARGET_CHANGED')
assert(#SOUNDS == 1 and SOUNDS[1] == 684, 'lost target sound: ' .. #SOUNDS)
UnitExists = unitExists
onEvent(nil, 'PLAYER_TARGET_CHANGED')
IsTargetLoose = function() return true end
UnitExists = function(unit) return unit ~= 'target' end
onEvent(nil, 'PLAYER_TARGET_CHANGED')
assert(#SOUNDS == 1, 'soft target change played the sound')
UnitExists, IsTargetLoose = unitExists, nil
onEvent(nil, 'PLAYER_FOCUS_CHANGED')
UnitExists = function(unit) return unit ~= 'focus' end
onEvent(nil, 'PLAYER_FOCUS_CHANGED')
assert(#SOUNDS == 2, 'lost focus sound: ' .. #SOUNDS)
UnitExists = unitExists

-- Cast bar: a cast starting during a failure hold keeps its own colours; a preview cancels the
-- hold; channels read castBarID from return 11.
do
    local cast = EUI.TargetBar.target.cast
    local status = cast.bar.status
    local lastColor
    rawset(status, 'SetStatusBarColor', function(_, r, g, b) lastColor = string.format('%.2f,%.2f,%.2f', r, g, b) end)
    local function hexColor(hex)
        local r, g, b = EUI.Style.Color(hex)
        return string.format('%.2f,%.2f,%.2f', r, g, b)
    end
    local timers = {}
    local after = C_Timer.After
    C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
    C_CurveUtil.EvaluateColorFromBoolean = function(flag, yes, no)
        local color = flag and yes or no
        return { GetRGBA = function() return color.r, color.g, color.b, color.a end }
    end
    UnitCastingDuration = function() return {} end
    UnitChannelDuration = function() return {} end
    local casting = true
    UnitCastingInfo = function(unit)
        if unit == 'target' and casting then
            return 'Fireball', 'Fireball', 1, 0, 1, false, 'guid', true, 133, 7
        end
    end
    local spec = cast.spec
    onEvent(nil, 'UNIT_SPELLCAST_START', 'target', 'guid', 133)
    assert(lastColor == hexColor(spec.uninterruptible.color), 'uninterruptible tint: ' .. tostring(lastColor))
    onEvent(nil, 'UNIT_SPELLCAST_INTERRUPTED', 'target', 'guid', 133, 'kicker', 7)
    assert(cast.failing and lastColor == hexColor(spec.failure.color), 'failure hold not shown')
    onEvent(nil, 'UNIT_SPELLCAST_START', 'target', 'guid', 133)
    assert(not cast.failing and lastColor == hexColor(spec.uninterruptible.color), 'new cast lost its tint: ' .. tostring(lastColor))
    for _, fn in ipairs(timers) do fn() end
    assert(lastColor == hexColor(spec.uninterruptible.color), 'stale hold timer reset the new cast')
    onEvent(nil, 'UNIT_SPELLCAST_INTERRUPTED', 'target', 'guid', 133, 'kicker', 99)
    assert(not cast.failing, 'another cast bar\'s interrupt was accepted')
    onEvent(nil, 'UNIT_SPELLCAST_INTERRUPTED', 'target', 'guid', 133, 'kicker', 7)
    assert(cast.failing, 'matching interrupt ignored')
    timers = {}
    cast:SetPreview('Preview', 0.5)
    assert(cast.preview and not cast.failing, 'preview did not cancel the hold')
    for _, fn in ipairs(timers) do fn() end
    cast:SetPreview(nil)
    casting = false
    UnitChannelInfo = function(unit)
        if unit == 'target' then
            return 'Drain', 'Drain', 1, 0, 1, false, false, 689, false, 0, 9
        end
    end
    onEvent(nil, 'UNIT_SPELLCAST_CHANNEL_START', 'target', 'guid', 689)
    assert(cast.castBarID == 9, 'channel castBarID: ' .. tostring(cast.castBarID))
    UnitCastingInfo = function() end
    UnitChannelInfo = function() end
    UnitCastingDuration, UnitChannelDuration, C_CurveUtil.EvaluateColorFromBoolean = nil, nil, nil
    C_Timer.After = after
    rawset(status, 'SetStatusBarColor', nil)
    onEvent(nil, 'UNIT_SPELLCAST_STOP', 'target', 'guid', 689)
end

-- Reaction keys: players follow UnitSelectionColor's branches, NPCs tapping then UnitReaction;
-- a dead NPC keeps its HP bar.
do
    local bar = EUI.TargetBar.target
    local saved = {
        UnitPlayerControlled = UnitPlayerControlled, UnitCanAttack = UnitCanAttack, UnitIsPVP = UnitIsPVP,
        UnitIsUnit = UnitIsUnit, UnitIsPlayer = UnitIsPlayer, UnitInParty = UnitInParty,
        UnitIsTapDenied = UnitIsTapDenied, UnitReaction = UnitReaction, UnitIsDead = UnitIsDead,
    }
    local REACTION_CASES = {
        { 'hostilePlayer', { controlled = true, attacksMe = true, iAttack = true } },
        { 'player', { controlled = true, attacksMe = true } },
        { 'neutral', { controlled = true, iAttack = true } },
        { 'friendly', { controlled = true, pvp = true } },
        { 'partyPvP', { controlled = true, pvp = true, isPlayer = true, grouped = true } },
        { 'party', { controlled = true, isPlayer = true, grouped = true } },
        { 'player', { controlled = true } },
        { 'tapped', { tapped = true, iAttack = true } },
        { 'hostile', { reaction = 2, iAttack = true } },
        { 'unfriendly', { reaction = 3, iAttack = true } },
        { 'neutral', { reaction = 4, iAttack = true } },
        { 'friendly', { reaction = 5 }, npc = true },
        { 'friendly', { reaction = 5, dead = true }, npc = false },
    }
    for _, case in ipairs(REACTION_CASES) do
        local c = case[2]
        UnitPlayerControlled = function() return c.controlled == true end
        UnitCanAttack = function(a) if a == 'player' then return c.iAttack == true end return c.attacksMe == true end
        UnitIsPVP = function() return c.pvp == true end
        UnitIsUnit = function() return false end
        UnitIsPlayer = function() return c.isPlayer == true end
        UnitInParty = function() return c.grouped == true end
        UnitIsTapDenied = function() return c.tapped == true end
        UnitReaction = function() return c.reaction end
        UnitIsDead = function() return c.dead == true end
        bar:Refresh()
        assert(bar.colorKey == case[1], string.format('reaction case %s got %s', case[1], tostring(bar.colorKey)))
        if case.npc ~= nil then
            assert(bar.npcMode == case.npc, 'npc mode for ' .. case[1])
        end
    end
    for name, fn in pairs(saved) do
        _G[name] = fn
    end
    bar:Refresh()
end

-- Log: a clear forgets LogOnce keys; plain nil reads are not secrets; Guard logs errors and
-- reports them to the error handler.
do
    EUI.LogOnce('smoke:once', 'smoke once')
    EUI.ClearLog()
    EUI.LogOnce('smoke:once', 'smoke once')
    assert(#EorzeaUILog.entries == 1, 'LogOnce suppressed after clear')
    EUI.Read('smokeNil', function() return nil end)
    for _, entry in ipairs(EorzeaUILog.entries) do
        assert(not entry.msg:find('smokeNil', 1, true), 'nil read logged as secret')
    end
    local errorCount = #ERRORS
    EUI.Guard('smoke guard', function() error('boom') end)()
    assert(#ERRORS == errorCount + 1, 'guarded error not reported')
    local logged = false
    for _, entry in ipairs(EorzeaUILog.entries) do
        if entry.msg:find('error in smoke guard', 1, true) then logged = true end
    end
    assert(logged, 'guarded error not logged')
    table.remove(ERRORS)
    EUI.ClearLog()
end

-- Party row states: offline greys both bars full; reconnecting restores them.
do
    local row = EUI.PartyList.RowForUnit('party1')
    local unitIsConnected = UnitIsConnected
    UnitIsConnected = function(unit) return unit ~= 'party1' end
    onEvent(nil, 'UNIT_CONNECTION', 'party1')
    assert(row.state == 'offline' and row.greyed and row.power.tintKey == 'offline', 'offline state not applied')
    UnitIsConnected = unitIsConnected
    onEvent(nil, 'UNIT_CONNECTION', 'party1')
    assert(row.state == nil and not row.greyed and row.power.tintKey ~= 'offline', 'online state not restored')
end

-- Phased members and their pets fade to notPresentAlpha.
do
    local row = EUI.PartyList.RowForUnit('party1')
    local alpha
    rawset(row.art, 'SetAlpha', function(_, value) alpha = value end)
    local unitPhaseReason = UnitPhaseReason
    UnitPhaseReason = function(unit) return unit == 'party1' and 1 or nil end
    onEvent(nil, 'UNIT_PHASE', 'party1')
    assert(row.notPresent and alpha == row.style.range.notPresentAlpha, 'phased member not faded: ' .. tostring(alpha))
    UnitPhaseReason = unitPhaseReason
    onEvent(nil, 'UNIT_PHASE', 'party1')
    assert(not row.notPresent and alpha ~= row.style.range.notPresentAlpha, 'unphased member still faded')
    rawset(row.art, 'SetAlpha', nil)
end

-- Ready check: a result stays with the member who gave it, not a renumbered token.
do
    local row = EUI.PartyList.RowForUnit('party1')
    local unitGUID = UnitGUID
    row:UpdateReadyCheck('active')
    UnitGUID = function(unit) return unit == 'party1' and 'GUID-someone-else' or unitGUID(unit) end
    row:UpdateReadyCheck('finished')
    assert(row.readyStatus == nil, 'ready check result kept for a renumbered member')
    UnitGUID = unitGUID
    row:UpdateReadyCheck('active')
    row:UpdateReadyCheck('finished')
    assert(row.readyStatus == 'notready', 'waiting member not marked not ready')
    row:UpdateReadyCheck(nil)
end

-- Settings: a saved value of the wrong type takes its default.
EorzeaUIDB.scale = 'big'
Settings.Load()
assert(Settings.Get('scale') == 1, 'mistyped setting not repaired')

-- Secrets: a value canaccessvalue rejects is logged by EUI.Read, never compared, and names
-- holding one pass through as-is.
do
    local SECRET = setmetatable({}, { __eq = function() error('compared a secret') end, __lt = function() error('compared a secret') end })
    canaccessvalue = function(value) return rawequal(value, SECRET) == false end
    assert(EUI.Read('smokeSecret', function() return SECRET end) == nil, 'secret returned by EUI.Read')
    local logged = false
    for _, entry in ipairs(EorzeaUILog.entries) do
        if entry.msg:find('smokeSecret returned a secret', 1, true) then logged = true end
    end
    assert(logged, 'secret read not logged')
    local unitName = UnitName
    UnitName = function() return SECRET, SECRET end
    assert(rawequal(EUI.UnitDisplayName('player'), SECRET), 'secret name not passed through')
    UnitName = unitName
    canaccessvalue = nil
end

-- The player cast bar holds an interrupt through the STOP that follows; the target shows Dead or
-- Unconscious in place of HP%.
do
    local cast = EUI.playerCast
    local after = C_Timer.After
    C_Timer.After = function() end
    onEvent(nil, 'UNIT_SPELLCAST_INTERRUPTED', 'player', 'guid', 133, 'kicker', nil)
    onEvent(nil, 'UNIT_SPELLCAST_STOP', 'player', 'guid', 133)
    assert(cast.failing, 'player cast bar did not hold the interrupt')
    cast:EndFailure()
    C_Timer.After = after

    local bar = EUI.TargetBar.target
    local hppText
    rawset(bar.hpp, 'SetText', function(_, text) hppText = text end)
    local unitIsDead, unitIsUnconscious = UnitIsDead, UnitIsUnconscious
    UnitIsDead = function(unit) return unit == 'target' end
    bar:UpdateHealth(false)
    assert(hppText == EUI.UnitInfo.STATE_LABELS.dead, 'dead text: ' .. tostring(hppText))
    UnitIsUnconscious = function(unit) return unit == 'target' end
    bar:UpdateHealth(false)
    assert(hppText == EUI.UnitInfo.STATE_LABELS.unconscious, 'unconscious text: ' .. tostring(hppText))
    UnitIsDead, UnitIsUnconscious = unitIsDead, unitIsUnconscious
    rawset(bar.hpp, 'SetText', nil)
    bar:UpdateHealth(false)
end

-- Palettes: every colour the layout reads is set in each style.
local REQUIRED = {
    'party.hp.bar.fill.color', 'party.hp.offlineColor', 'party.power.bar.fill.color', 'party.power.colors',
    'party.cast.bar.fill.color', 'party.txtName.color', 'party.txtName.stroke', 'party.indicators.healPrediction.color',
    'party.indicators.healPrediction.absorbColor', 'party.background.color', 'target.bar.fill.color',
    'target.reactionColors', 'target.txtHpp.color', 'target.txtHpp.stroke', 'target.cast.failure.color',
    'target.cast.uninterruptible.color', 'target.comboPoints.color', 'target.healPrediction.color',
    'target.auras.groups.HARMFUL.dispelColors', 'focus.header.txtLabel.color', 'castBar.bar.fill.color',
    'target.auras.groups.HELPFUL.dispelColors.Magic', 'target.cast.bar.fill.color', 'target.txtThreat.color',
    'target.tot.txtName.stroke', 'party.hp.thresholds',
}
local REACTIONS = { 'party', 'partyPvP', 'player', 'hostilePlayer', 'friendly', 'neutral', 'unfriendly', 'hostile', 'tapped' }
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

-- Raid: the party list keeps its tokens and hides rows 2-5 by state driver. Each group header
-- builds 5 cells that route events by their raidN unit; your cell takes 'player' events instead
-- of its own token's.
local function countDrivers(condition)
    local count = 0
    for _, entry in ipairs(STATE_DRIVERS) do
        if entry.state == 'visibility' and entry.condition == condition then count = count + 1 end
    end
    return count
end
assert(countDrivers('[group:raid] hide; show') == 1, 'party members visibility driver missing')
assert(countDrivers('[group:raid] show; hide') == 8, 'raid header drivers: ' .. countDrivers('[group:raid] show; hide'))
IsInRaid = function() return true end
GetNumGroupMembers = function() return 6 end
UnitInRaid = function(unit) return unit == 'player' and 3 or nil end
UnitGUID = function(u) return u == 'raid3' and 'GUID-player' or 'GUID-' .. tostring(u) end
onEvent(nil, 'GROUP_ROSTER_UPDATE')
assert(_G.EorzeaUIPartyButton2:GetAttribute('unit') == 'party1', 'party rows reassigned in a raid')
local you, member = _G.EorzeaUIRaidGroup1UnitButton1, _G.EorzeaUIRaidGroup1UnitButton2
assert(you and member and _G.EorzeaUIRaidGroup8UnitButton5, 'raid cells not built')
you:SetAttribute('unit', 'raid3')
member:SetAttribute('unit', 'raid4')
onEvent(nil, 'GROUP_ROSTER_UPDATE')
local RaidList = EUI.RaidList
assert(RaidList.CellForUnit('player') and RaidList.CellForUnit('player').button == you, 'player events miss your cell')
assert(RaidList.CellForUnit('raid3') == nil, 'your cell also takes its raid token')
assert(RaidList.CellForUnit('raid4') and RaidList.CellForUnit('raid4').button == member, 'raid4 not routed')
for _, event in ipairs({ 'UNIT_HEALTH', 'UNIT_POWER_UPDATE', 'UNIT_FLAGS', 'UNIT_SPELLCAST_START', 'UNIT_THREAT_SITUATION_UPDATE' }) do
    onEvent(nil, event, 'raid4')
    onEvent(nil, event, 'player')
end
onEvent(nil, 'READY_CHECK')
onEvent(nil, 'READY_CHECK_FINISHED')
onEvent(nil, 'PARTY_LEADER_CHANGED')
TICK()
assert(#ERRORS == 0, 'errors reported:\n' .. table.concat(ERRORS, '\n'))
print('SMOKE OK')
