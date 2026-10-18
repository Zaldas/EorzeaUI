local _, EUI = ...

-- Hides the Blizzard frames this addon replaces by reparenting them to a hidden frame.
-- Edit Mode and the managed frame containers reparent some of them back (the cast bar, PetFrame),
-- so each is re-hidden whenever its parent changes. Protected ones wait until combat ends.

EUI.Blizzard = {}

local REPLACED = {
    'PlayerFrame',
    'PetFrame',
    'TargetFrame',
    'TargetFrameToT',
    'FocusFrame',
    'FocusFrameToT',
    'PartyFrame',
    'CompactPartyFrame',
    'PlayerCastingBarFrame',
}

local hooked = {}

local function hide(frame, hider)
    if frame:GetParent() == hider then
        return
    end
    if frame:IsProtected() and InCombatLockdown() then
        EUI.RunOutOfCombat(function()
            hide(frame, hider)
        end, 'hideBlizzard:' .. tostring(frame:GetName()))
        return
    end
    local ok, err = pcall(frame.SetParent, frame, hider)
    if not ok then
        EUI.LogOnce('hide:' .. tostring(frame:GetName()), 'hiding %s failed: %s', tostring(frame:GetName()), tostring(err))
    end
end

function EUI.Blizzard.HideReplaced()
    local hider = EUI.Blizzard.hider
    if not hider then
        hider = CreateFrame('Frame', 'EorzeaUIBlizzardHider', UIParent)
        hider:Hide()
        EUI.Blizzard.hider = hider
    end
    for _, name in ipairs(REPLACED) do
        local frame = _G[name]
        if frame then
            hide(frame, hider)
            if not hooked[frame] then
                hooked[frame] = true
                hooksecurefunc(frame, 'SetParent', EUI.Guard('rehide ' .. name, function(self, parent)
                    if parent ~= hider then
                        hide(self, hider)
                    end
                end))
            end
        end
    end
    -- Stops its cast event handling, which would otherwise keep showing it.
    if PlayerCastingBarFrame and PlayerCastingBarFrame.SetUnit then
        pcall(PlayerCastingBarFrame.SetUnit, PlayerCastingBarFrame, nil)
    end
end
