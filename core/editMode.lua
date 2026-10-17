local _, AV = ...

-- Blizzard has no public API for registering addon frames as Edit Mode systems. Opening Edit
-- Mode instead unlocks our own drag handles and preview data; closing it saves positions.

AV.EditMode = {}
local EditMode = AV.EditMode

local movers = {}

local DEFAULT_POSITIONS = {
    party = { 'TOPLEFT', 'TOPLEFT', 60, -260 },
    target = { 'TOP', 'TOP', 0, -140 },
    cast = { 'CENTER', 'CENTER', 0, -148 },
}

function EditMode.RestorePosition(key, frame)
    local saved = AV.db.positions[key] or DEFAULT_POSITIONS[key]
    frame:ClearAllPoints()
    frame:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
end

local function savePosition(key, frame)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if point then
        AV.db.positions[key] = { point, relativePoint, x, y }
    end
end

-- frame: the root to move. label: text on the handle.
function EditMode.Register(key, frame, label)
    local mover = CreateFrame('Frame', nil, frame)
    mover:SetAllPoints(frame)
    mover:SetFrameStrata('DIALOG')
    mover:EnableMouse(true)
    mover:RegisterForDrag('LeftButton')
    mover:Hide()

    local bg = mover:CreateTexture(nil, 'BACKGROUND')
    bg:SetAllPoints()
    bg:SetColorTexture(0.2, 0.6, 1, 0.25)
    local text = mover:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    text:SetPoint('CENTER')
    text:SetText(label)

    mover:SetScript('OnDragStart', function()
        if not InCombatLockdown() then
            frame:StartMoving()
        end
    end)
    mover:SetScript('OnDragStop', function()
        frame:StopMovingOrSizing()
        savePosition(key, frame)
    end)

    movers[key] = mover
    EditMode.RestorePosition(key, frame)
end

function EditMode.SetUnlocked(unlocked)
    if InCombatLockdown() then
        AV.Print('cannot unlock frames in combat')
        return
    end
    EditMode.unlocked = unlocked
    for _, mover in pairs(movers) do
        mover:SetShown(unlocked)
    end
    AV.Demo.Refresh()
end

function EditMode.Initialize()
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback('EditMode.Enter', function() EditMode.SetUnlocked(true) end, EditMode)
        EventRegistry:RegisterCallback('EditMode.Exit', function() EditMode.SetUnlocked(false) end, EditMode)
    elseif EditModeManagerFrame then
        EditModeManagerFrame:HookScript('OnShow', function() EditMode.SetUnlocked(true) end)
        EditModeManagerFrame:HookScript('OnHide', function() EditMode.SetUnlocked(false) end)
    end
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        EditMode.SetUnlocked(true)
    end
end
