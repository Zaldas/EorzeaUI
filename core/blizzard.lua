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

-- Blizzard's totem timers are a child of PlayerFrame, so hiding it hides them. They move under
-- anchor instead; ignoreFramePositionManager keeps the player frame's managed layout from
-- reparenting them back when they show.
function EUI.Blizzard.KeepTotems(anchor)
    local totems = TotemFrame
    if not totems then
        return
    end
    totems.ignoreFramePositionManager = true
    totems:SetParent(UIParent)
    totems:ClearAllPoints()
    totems:SetPoint('TOP', anchor, 'BOTTOM', 0, 0)
end

-- The raid manager's group/role filters, Edit and Hide buttons act on Blizzard's raid frames,
-- which are hidden; they come out of its options flow each time it lays them out. None of its
-- buttons are secure, so this is safe in combat.
local MANAGER_HIDDEN = { 'filterOptions', 'editMode', 'hiddenModeToggle' }

local function trimRaidManager(manager)
    local display = manager.displayFrame
    local container = display and display.optionsFlowContainer
    if not container then
        return
    end
    FlowContainer_PauseUpdates(container)
    for _, key in ipairs(MANAGER_HIDDEN) do
        local object = display[key]
        if object then
            FlowContainer_RemoveObject(container, object)
            object:Hide()
        end
    end
    FlowContainer_ResumeUpdates(container)
    local _, usedY = FlowContainer_GetUsedBounds(container)
    manager:SetHeight(usedY + 40)
end

function EUI.Blizzard.TrimRaidManager()
    if not (CompactRaidFrameManager_UpdateOptionsFlowContainer and FlowContainer_RemoveObject) then
        EUI.LogOnce('raidManager:api', 'raid manager options flow missing; its filter buttons stay')
        return
    end
    hooksecurefunc('CompactRaidFrameManager_UpdateOptionsFlowContainer', EUI.Guard('trim raid manager', trimRaidManager))
    if CompactRaidFrameManager then
        EUI.Guard('trim raid manager', trimRaidManager)(CompactRaidFrameManager)
    end
end
