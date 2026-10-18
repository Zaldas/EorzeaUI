local addonName, EUI = ...

-- Diagnostic log kept in the EorzeaUILog SavedVariable. SavedVariables are written on
-- logout and /reload only, so entries from a session that ends in a client crash are lost.
-- Repeated messages bump a counter on the existing entry instead of adding a new one.

local MAX_ENTRIES = 300

local entries
local indexByMessage = {}
local onceKeys = {}

local function timestamp()
    return date and date('%m-%d %H:%M:%S') or '?'
end

local function store()
    if not entries then
        EorzeaUILog = type(EorzeaUILog) == 'table' and EorzeaUILog or {}
        EorzeaUILog.entries = EorzeaUILog.entries or {}
        entries = EorzeaUILog.entries
    end
    return entries
end

function EUI.Log(fmt, ...)
    local ok, message = pcall(string.format, fmt, ...)
    if not ok then
        message = tostring(fmt)
    end
    local list = store()
    local index = indexByMessage[message]
    if index and list[index] and list[index].msg == message then
        local entry = list[index]
        entry.count = (entry.count or 1) + 1
        entry.last = timestamp()
        return
    end
    list[#list + 1] = { time = timestamp(), msg = message, combat = InCombatLockdown() or nil }
    indexByMessage[message] = #list
    if #list > MAX_ENTRIES then
        table.remove(list, 1)
        indexByMessage = {}
    end
end

-- Logs only the first time `key` is seen this session.
function EUI.LogOnce(key, fmt, ...)
    if onceKeys[key] then
        return
    end
    onceKeys[key] = true
    EUI.Log(fmt, ...)
end

-- Reads a game value for a feature. Returns nil when the API is missing, errors, or returns a
-- secret, and logs each of those outcomes once per label (secrets once in and once out of combat).
function EUI.Read(label, fn, ...)
    if type(fn) ~= 'function' then
        EUI.LogOnce(label .. ':missing', '%s: API missing', label)
        return nil
    end
    local ok, value = pcall(fn, ...)
    if not ok then
        EUI.LogOnce(label .. ':error', '%s: %s', label, tostring(value))
        return nil
    end
    -- type() works on secrets; a plain nil is a normal 'none' result, not a secret.
    if type(value) == 'nil' then
        return nil
    end
    if not EUI.CanAccess(value) then
        local combat = InCombatLockdown()
        EUI.LogOnce(label .. ':secret:' .. tostring(combat), '%s returned a secret value (%s combat)', label, combat and 'in' or 'out of')
        return nil
    end
    return value
end

-- WoW's xpcall forwards extra arguments to the function; stock Lua 5.1's does not.
local XPCALL_ARGS = select(2, xpcall(function(value) return value end, function() end, true)) == true

-- Wraps fn so a Lua error is logged with its stack and handed to the normal error handler,
-- both from inside the handler while the failing stack is live.
function EUI.Guard(label, fn)
    local function report(err)
        local stack = debugstack and debugstack(2, 6, 0) or ''
        EUI.Log('error in %s: %s\n%s', label, tostring(err), stack)
        if geterrorhandler then
            geterrorhandler()(err)
        end
        return err
    end
    if XPCALL_ARGS then
        return function(...)
            xpcall(fn, report, ...)
        end
    end
    return function(...)
        local args, count = { ... }, select('#', ...)
        xpcall(function() return fn(unpack(args, 1, count)) end, report)
    end
end

function EUI.LogSession()
    local version, build, _, interface = '?', '?', nil, '?'
    if GetBuildInfo then
        version, build, _, interface = GetBuildInfo()
    end
    local addonVersion = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, 'Version')
    EUI.Log('session: client %s (%s) interface %s, EorzeaUI %s, style %s',
        tostring(version), tostring(build), tostring(interface), tostring(addonVersion), tostring(EUI.Settings.Get('style')))
end

-- Prints the newest `count` entries to chat.
function EUI.PrintLog(count)
    local list = store()
    if #list == 0 then
        EUI.Print('log is empty')
        return
    end
    local first = math.max(1, #list - (count or 15) + 1)
    for i = first, #list do
        local entry = list[i]
        local repeats = entry.count and string.format(' (x%d, last %s)', entry.count, entry.last or '?') or ''
        EUI.Print('%s%s %s', entry.time or '?', repeats, (entry.msg or ''):match('^[^\n]*'))
    end
    EUI.Print('%d entries; full text in WTF\\...\\SavedVariables\\EorzeaUI.lua after /reload', #list)
end

-- Called on ADDON_LOADED: SavedVariables replace EorzeaUILog, so entries logged before then
-- went to a table that is never saved. Moves them into the saved log.
function EUI.BindLog()
    local early = entries
    entries = nil
    indexByMessage = {}
    local list = store()
    if early and early ~= list then
        for _, entry in ipairs(early) do
            list[#list + 1] = entry
        end
        while #list > MAX_ENTRIES do
            table.remove(list, 1)
        end
    end
end

function EUI.ClearLog()
    local list = store()
    for i = #list, 1, -1 do
        list[i] = nil
    end
    indexByMessage = {}
    onceKeys = {}
    EUI.Print('log cleared')
end
