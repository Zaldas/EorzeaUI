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
    'BossTargetFrameContainer',
    'PartyFrame',
    'CompactPartyFrame',
    'CompactRaidFrameContainer',
    'PlayerCastingBarFrame',
    'PetCastingBarFrame',
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
        local ok, err = pcall(PlayerCastingBarFrame.SetUnit, PlayerCastingBarFrame, nil)
        if not ok then
            EUI.LogOnce('hide:castbar', 'PlayerCastingBarFrame:SetUnit failed: %s', tostring(err))
        end
    end
end

-- Never write fields into Blizzard's frames or tables, nor drive their layout code: Blizzard code
-- reading an addon-written value runs tainted, and its protected calls are then refused, even
-- unrelated ones such as the gamepad bar's SetPreferredGamepadInteractTarget. Only move,
-- reparent or hide their frames, from hooksecurefunc post-hooks.

local function placeTotems(totems, anchor)
    totems:SetParent(UIParent)
    totems:ClearAllPoints()
    totems:SetPoint('TOP', anchor, 'BOTTOM', 0, 0)
end

-- Blizzard's totem timers are a child of PlayerFrame, so hiding it hides them. They move under
-- anchor instead, and back there each time the player frame's managed layout reparents them.
function EUI.Blizzard.KeepTotems(anchor)
    local totems = TotemFrame
    if not totems then
        return
    end
    hooksecurefunc(totems, 'SetParent', EUI.Guard('keep totems', function(self, parent)
        if parent ~= UIParent then
            placeTotems(self, anchor)
        end
    end))
    placeTotems(totems, anchor)
end

-- The raid manager's Edit button moves Blizzard's raid frames, which are hidden. It hides after
-- each layout of its options; its space stays. None of its buttons are secure, so this is safe
-- in combat.
local MANAGER_HIDDEN = { 'editMode' }

local function hideManagerButtons()
    local display = CompactRaidFrameManager and CompactRaidFrameManager.displayFrame
    if not display then
        return
    end
    for _, key in ipairs(MANAGER_HIDDEN) do
        local object = display[key]
        if object then
            object:Hide()
        end
    end
end

function EUI.Blizzard.TrimRaidManager()
    if not CompactRaidFrameManager_UpdateOptionsFlowContainer then
        EUI.LogOnce('raidManager:api', 'raid manager options layout missing; its filter buttons stay')
        return
    end
    hooksecurefunc('CompactRaidFrameManager_UpdateOptionsFlowContainer', EUI.Guard('trim raid manager', hideManagerButtons))
    hideManagerButtons()
end

-- fn() after the raid manager's filters or settings (its Hide button) change: post-hooks on
-- its setters, so our frames follow without touching Blizzard's.
function EUI.Blizzard.FollowRaidManager(fn)
    local guarded = EUI.Guard('raid manager filters', fn)
    for _, name in ipairs({ 'CompactRaidFrameManager_SetFilterOptions', 'CompactRaidFrameManager_SetSetting' }) do
        if _G[name] then
            hooksecurefunc(name, guarded)
        else
            EUI.LogOnce('raidManager:' .. name, '%s missing; our raid frames ignore it', name)
        end
    end
end
