local _, EUI = ...

-- Secure frames and AuraContainers cannot be created, moved or reconfigured in combat.
-- Work submitted during combat runs once PLAYER_REGEN_ENABLED fires, in submission order.
local pending = {}
local pendingKeys = {}

-- key (optional) collapses repeated submissions of the same job into one run.
function EUI.RunOutOfCombat(fn, key)
    if not InCombatLockdown() then
        fn()
        return
    end
    if key then
        if pendingKeys[key] then
            return
        end
        pendingKeys[key] = true
    end
    pending[#pending + 1] = fn
end

function EUI.FlushOutOfCombat()
    local jobs = pending
    pending = {}
    pendingKeys = {}
    for _, fn in ipairs(jobs) do
        local ok, err = pcall(fn)
        if not ok then
            EUI.Print('deferred job failed: %s', tostring(err))
        end
    end
end

function EUI.Print(fmt, ...)
    print(string.format('|cff7fd4ffEorzeaUI|r ' .. fmt, ...))
end
