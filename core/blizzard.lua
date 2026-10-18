local _, AV = ...

-- Hides the Blizzard frames this addon replaces by reparenting them to a hidden frame.
-- Several are protected, so this only runs out of combat.

AV.Blizzard = {}

local REPLACED = {
    'PlayerFrame',
    'TargetFrame',
    'TargetFrameToT',
    'FocusFrame',
    'FocusFrameToT',
    'PartyFrame',
    'CompactPartyFrame',
    'PlayerCastingBarFrame',
    'CastingBarFrame',
}

function AV.Blizzard.HideReplaced()
    AV.RunOutOfCombat(function()
        local hider = AV.Blizzard.hider
        if not hider then
            hider = CreateFrame('Frame', 'AzerothVistaBlizzardHider', UIParent)
            hider:Hide()
            AV.Blizzard.hider = hider
        end
        for _, name in ipairs(REPLACED) do
            local frame = _G[name]
            if frame and frame:GetParent() ~= hider then
                pcall(frame.SetParent, frame, hider)
            end
        end
    end, 'hideBlizzard')
end
