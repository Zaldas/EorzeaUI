local addonName, AV = ...

-- Diagnostic log kept in the AzerothVistaLog SavedVariable. SavedVariables are written on
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
        AzerothVistaLog = type(AzerothVistaLog) == 'table' and AzerothVistaLog or {}
        AzerothVistaLog.entries = AzerothVistaLog.entries or {}
        entries = AzerothVistaLog.entries
    end
    return entries
end

function AV.Log(fmt, ...)
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
function AV.LogOnce(key, fmt, ...)
    if onceKeys[key] then
        return
    end
    onceKeys[key] = true
    AV.Log(fmt, ...)
end

-- Reads a game value for a feature. Returns nil when the API is missing, errors, or returns a
-- secret, and logs each of those outcomes once per label (secrets once in and once out of combat).
function AV.Read(label, fn, ...)
    if type(fn) ~= 'function' then
        AV.LogOnce(label .. ':missing', '%s: API missing', label)
        return nil
    end
    local ok, value = pcall(fn, ...)
    if not ok then
        AV.LogOnce(label .. ':error', '%s: %s', label, tostring(value))
        return nil
    end
    if not AV.CanAccess(value) then
        local combat = InCombatLockdown()
        AV.LogOnce(label .. ':secret:' .. tostring(combat), '%s returned a secret value (%s combat)', label, combat and 'in' or 'out of')
        return nil
    end
    return value
end

-- Wraps fn so a Lua error is logged with its stack, then handed to the normal error handler.
function AV.Guard(label, fn)
    local function report(err)
        local stack = debugstack and debugstack(2, 6, 0) or ''
        AV.Log('error in %s: %s\n%s', label, tostring(err), stack)
        return err
    end
    return function(...)
        local args, count = { ... }, select('#', ...)
        local ok, err = xpcall(function() return fn(unpack(args, 1, count)) end, report)
        if not ok and geterrorhandler then
            geterrorhandler()(err)
        end
    end
end

function AV.LogSession()
    local version, build, _, interface = '?', '?', nil, '?'
    if GetBuildInfo then
        version, build, _, interface = GetBuildInfo()
    end
    local addonVersion = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, 'Version')
    AV.Log('session: client %s (%s) interface %s, AzerothVista %s, style %s',
        tostring(version), tostring(build), tostring(interface), tostring(addonVersion), tostring(AV.db and AV.db.style))
end

-- Prints the newest `count` entries to chat.
function AV.PrintLog(count)
    local list = store()
    if #list == 0 then
        AV.Print('log is empty')
        return
    end
    local first = math.max(1, #list - (count or 15) + 1)
    for i = first, #list do
        local entry = list[i]
        local repeats = entry.count and string.format(' (x%d, last %s)', entry.count, entry.last or '?') or ''
        AV.Print('%s%s %s', entry.time or '?', repeats, (entry.msg or ''):match('^[^\n]*'))
    end
    AV.Print('%d entries; full text in WTF\\...\\SavedVariables\\AzerothVista.lua after /reload', #list)
end

-- Called on ADDON_LOADED: SavedVariables replace AzerothVistaLog, so entries logged before then
-- went to a table that is never saved. Moves them into the saved log.
function AV.BindLog()
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

function AV.ClearLog()
    local list = store()
    for i = #list, 1, -1 do
        list[i] = nil
    end
    indexByMessage = {}
    AV.Print('log cleared')
end
