-- Loads AzerothVista against permissive WoW stubs and fires its startup events.
local root = ADDON_ROOT

local methodOverrides = {
    GetHeight = 768, GetWidth = 1366, GetFrameLevel = 1, IsShown = true, IsProtected = false,
    GetAttribute = false, GetName = 'mock',
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
    if k == 'GetPoint' then
        return function() return 'TOPLEFT', nil, 'TOPLEFT', 0, 0 end
    end
    if k == 'CreateTexture' or k == 'CreateFontString' or k == 'CreateMaskTexture' or k == 'GetStatusBarTexture' or k == 'GetParent' then
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
UnitClass = function() return 'Paladin', 'PALADIN' end
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
UnitIsDND = function() return false end
GetReadyCheckStatus = function() return 'waiting' end
GetRaidTargetIndex = function() return 8 end
UnitHasIncomingResurrection = function() return false end
UnitPhaseReason = function() return nil end
UnitInRange = function() return true, true end
UnitGroupRolesAssigned = function() return 'HEALER' end
UnitIsPVP = function() return true end
UnitIsPVPFreeForAll = function() return false end
UnitFactionGroup = function() return 'Horde', 'Horde' end
UnitIsAFK = function() return true end
C_IncomingSummon = { HasIncomingSummon = function() return true end, IncomingSummonStatus = function() return 1 end }
-- Heal prediction stays unstubbed so the missing-API path runs.
date = os.date
GetBuildInfo = function() return '1.60.1', '00000', 'Oct 1 2026', 16001 end
debugstack = function() return '' end
geterrorhandler = function() return function(err) error(err, 0) end end
AzerothVistaLog = nil
RAID_CLASS_COLORS = { PALADIN = { r = 0.96, g = 0.55, b = 0.73 } }
CLASS_ICON_TCOORDS = { PALADIN = { 0, 0.25, 0.5, 0.75 } }
C_Timer = { NewTicker = function(_, fn) TICK = fn end, After = function(_, fn) fn() end }
C_AddOns = { IsAddOnLoaded = function() return false end, LoadAddOn = function() return true end }
C_CurveUtil = { CreateColorCurve = function() return newFrame() end }
CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
Enum = { StatusBarInterpolation = { ExponentialEaseOut = 1, Immediate = 0 }, StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 } }
EventRegistry = { RegisterCallback = function() end }
GameTooltip = newFrame()
SlashCmdList = {}
ReloadUI = function() RELOADED = true end
AzerothVistaDB = { style = STYLE }
print = function(...) io.write(table.concat({ ... }, ' '), '\n') end

-- Header buttons are created by the secure header in the real client.
for i = 1, 5 do
    _G['AzerothVistaPartyHeaderUnitButton' .. i] = newFrame()
end

-- Load order comes from the .toc; XML files are skipped (templates only exist in the real client).
local AV = {}
local order = {}
for line in io.lines(root .. 'AzerothVista.toc') do
    local file = line:match('^%s*([^#%s].-%.lua)%s*$')
    if file then
        order[#order + 1] = file:gsub('\\', '/')
    end
end
assert(#order > 0, 'no lua files found in AzerothVista.toc')
for _, file in ipairs(order) do
    local fn = assert(loadfile(root .. file))
    fn('AzerothVista', AV)
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
onEvent(nil, 'INCOMING_SUMMON_CHANGED', 'player')
onEvent(nil, 'RAID_TARGET_UPDATE')
onEvent(nil, 'UNIT_FACTION', 'player')
onEvent(nil, 'PLAYER_ROLES_ASSIGNED')
onEvent(nil, 'READY_CHECK')
onEvent(nil, 'READY_CHECK_CONFIRM', 'player')
onEvent(nil, 'READY_CHECK_FINISHED')
onEvent(nil, 'PLAYER_DEAD')
onEvent(nil, 'ADDON_ACTION_BLOCKED', 'AzerothVista', 'TestFunction()')
TICK()
AV.EditMode.SetUnlocked(true)
AV.EditMode.SetUnlocked(false)
SlashCmdList.AZEROTHVISTA('demo')
assert(AV.Demo.active, 'demo not active')
SlashCmdList.AZEROTHVISTA('demo')
assert(not AV.Demo.active, 'demo still active')
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
