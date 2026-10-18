-- Loads AzerothVista against permissive WoW stubs and fires its startup events.
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
InCombatLockdown = function() return false end
UnitExists = function() return true end
UnitName = function() return 'Zal', 'Brightforge' end
LOCALIZED_CLASS_NAMES_MALE = { PALADIN = 'Paladin' }
UnitLevel = function() return 11 end
UnitReaction = function() return 2 end
UnitClass = function() return 'Druid', 'DRUID' end
GetShapeshiftForm = function() return 3 end
RegisterStateDriver = function(frame, state, condition) STATE_DRIVER = condition end
UnitHealth = function() return 100 end
UnitHealthMax = function() return 200 end
UnitPower = function() return 50 end
UnitPowerMax = function() return 100 end
UnitGUID = function(u) return 'GUID-' .. tostring(u) end
UnitIsGroupLeader = function() return true end
CheckInteractDistance = function() return true end
UnitHealthPercent = function() return nil end
UnitCastingInfo = function() return nil end
UnitChannelInfo = function() return nil end
IsInRaid = function() return false end
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
AzerothVistaLog = nil
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
AzerothVistaDB = { style = STYLE }
print = function(...) io.write(table.concat({ ... }, ' '), '\n') end

-- Header buttons are created by the secure header in the real client.
for i = 1, 5 do
    _G['AzerothVistaPartyHeaderUnitButton' .. i] = newFrame()
end

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

local AV = {}
loadToc(root, 'AzerothVista', AV)

-- Load-on-demand addons load from the sibling folder on the first LoadAddOn.
local loadedAddOns = {}
C_AddOns.LoadAddOn = function(name)
    if name ~= 'AzerothVista_Gallery' then
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
onEvent(nil, 'ADDON_LOADED', 'AzerothVista')
assert(AV.ready, 'initialize did not complete')
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
assert(STATE_DRIVER == '[form:1/3] shifted; caster', 'druid state driver not registered')
onEvent(nil, 'UNIT_SPELLCAST_START', 'player', 'cast-guid', 1234)
onEvent(nil, 'UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast-guid', 1234)
onEvent(nil, 'UNIT_SPELLCAST_STOP', 'player', 'cast-guid', 1234)
onEvent(nil, 'READY_CHECK')
onEvent(nil, 'READY_CHECK_CONFIRM', 'player')
onEvent(nil, 'READY_CHECK_FINISHED')
onEvent(nil, 'PLAYER_DEAD')
onEvent(nil, 'ADDON_ACTION_BLOCKED', 'AzerothVista', 'TestFunction()')

-- The header assigns units in the real client; pet buttons follow their owners.
local owner1 = _G.AzerothVistaPartyHeaderUnitButton1
local owner2 = _G.AzerothVistaPartyHeaderUnitButton2
local petButton1 = _G.AzerothVistaPartyPetButton1
local petButton2 = _G.AzerothVistaPartyPetButton2
assert(petButton1 and petButton2, 'pet buttons not created')
-- 5 pet buttons plus the target and target-of-target click areas.
assert(#WATCHED == 7, 'pet buttons not unit-watched: ' .. #WATCHED)
owner1:SetAttribute('unit', 'player')
owner2:SetAttribute('unit', 'party1')
assert(petButton1:GetAttribute('unit') == 'pet', 'player pet unit: ' .. tostring(petButton1:GetAttribute('unit')))
assert(petButton2:GetAttribute('unit') == 'partypet1', 'party pet unit: ' .. tostring(petButton2:GetAttribute('unit')))
assert(AV.PartyList.PetForUnit('pet') and AV.PartyList.PetForUnit('partypet1'), 'pet lookup missing')
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
owner1:SetAttribute('av-form', false)
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
owner1:SetAttribute('av-player', true)
owner2:SetAttribute('av-player', false)
driver:SetAttribute('rowCount', 2)
runSnippet(driver:GetAttribute('_onstate-druidform'), driverHandle, 'druidform', 'shifted')
assert(ownerHandle.height == 46 + 22 + 29, 'shifted with pet height: ' .. tostring(ownerHandle.height))
assert(owner2Handle.height == nil, 'druid snippet resized a party member row')
runSnippet(petButton1:GetAttribute('_onhide'), petHandle)
assert(ownerHandle.height == 46 + 22, 'pet hide height: ' .. tostring(ownerHandle.height))
runSnippet(driver:GetAttribute('_onstate-druidform'), driverHandle, 'druidform', 'caster')
assert(ownerHandle.height == 46, 'caster height: ' .. tostring(ownerHandle.height))
TICK()
AV.EditMode.SetUnlocked(true)
AV.EditMode.SetUnlocked(false)
SlashCmdList.AZEROTHVISTA('demo')
assert(AV.Demo.active, 'demo not active')
assert(AV.PartyList.demoHeight == 5 * 46 + 22 + 2 * 29 + 4 * 13, 'demo height: ' .. tostring(AV.PartyList.demoHeight))
SlashCmdList.AZEROTHVISTA('demo')
assert(not AV.Demo.active, 'demo still active')

-- Gallery: loads on the first toggle, builds each window once, and every state key has a sample.
SlashCmdList.AZEROTHVISTA('gallery')
local Gallery = AzerothVistaGallery
assert(Gallery and Gallery.Window('party'), 'gallery not built')
local window = Gallery.Window('party')
SlashCmdList.AZEROTHVISTA('gallery')
SlashCmdList.AZEROTHVISTA('gallery')
assert(Gallery.Window('party') == window, 'gallery rebuilt')
SlashCmdList.AZEROTHVISTA('gallery target')
assert(Gallery.Window('target'), 'target gallery not built')
for _, kind in ipairs({ 'party', 'target' }) do
    local _, missing = Gallery.Coverage(kind)
    assert(#missing == 0, kind .. ' gallery states without a sample: ' .. table.concat(missing, ', '))
end

-- Target bars: the live bar routes events by unit; demo bars stay out of routing.
assert(AV.TargetBar.ForUnit('target') == AV.TargetBar.target, 'live target bar not routed')
local liveBars = 0
AV.TargetBar.ForEach(function() liveBars = liveBars + 1 end)
assert(liveBars == 1, 'demo target bars registered as live: ' .. liveBars)
onEvent(nil, 'UNIT_HEALTH', 'target')
onEvent(nil, 'UNIT_SPELLCAST_INTERRUPTED', 'target')
onEvent(nil, 'UNIT_FLAGS', 'target')
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
    stackRows[i] = AzerothVista.CreateDemoRow(UIParent, i)
end
assert(stackRows[2]:DemoHeight(stackMembers[2]) == 46 + 22, 'form row height')
assert(stackRows[3]:DemoHeight(stackMembers[3]) == 46 + 29, 'pet row height')
local columns, stackWidth, stackHeight = AzerothVista.StackDemoRows(stackRows, stackMembers, UIParent)
assert(#columns == 1 and stackHeight == 46 + 68 + 75 + 2 * 13, 'one column height: ' .. stackHeight)
columns, stackWidth, stackHeight = AzerothVista.StackDemoRows(stackRows, stackMembers, UIParent, 130)
assert(#columns == 2 and columns[2].x == 487 and stackWidth == 487 + 410, 'wrap columns: ' .. #columns)
assert(columns[1].height == 46 + 68 + 13 and columns[2].height == 75, 'wrap heights')
assert(AV.db.style == STYLE, 'style not applied: ' .. tostring(AV.db.style))
SlashCmdList.AZEROTHVISTA('style ffxiexpanded')
assert(RELOADED and AV.db.style == 'ffxiExpanded', 'style switch failed')
SlashCmdList.AZEROTHVISTA('scale 1.2')
SlashCmdList.AZEROTHVISTA('reset')
SlashCmdList.AZEROTHVISTA('log')
assert(AzerothVistaLog and #AzerothVistaLog.entries > 0, 'log empty')
local blocked = false
for _, entry in ipairs(AzerothVistaLog.entries) do
    if entry.msg:find('ADDON_ACTION_BLOCKED', 1, true) then blocked = true end
end
assert(blocked, 'blocked action not logged')
SlashCmdList.AZEROTHVISTA('log clear')
print('SMOKE OK')
