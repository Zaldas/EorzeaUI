local _, AV = ...

-- Blizzard has no public API for registering addon frames as Edit Mode systems. Opening Edit
-- Mode instead unlocks our own drag handles and preview data; closing it saves positions.

AV.EditMode = {}
local EditMode = AV.EditMode

local movers = {}

local DEFAULT_POSITIONS = {
    party = { 'TOPLEFT', 'TOPLEFT', 60, -260 },
    target = { 'TOP', 'TOP', 0, -140 },
    focus = { 'TOP', 'TOP', 0, -340 },
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

-- Blizzard's Edit Mode selection box (EditModeSystemSelectionLayout, local to its file), recoloured
-- so our frames read apart from Blizzard's. Vertex colour only darkens the blue art, so the
-- pieces are desaturated first.
local SELECTION_KIT = 'editmode-actionbar-highlight'
local SELECTION_TINT = '#9C94E8FF'
local SELECTION_LAYOUT = {
    TopRightCorner = { atlas = '%s-NineSlice-Corner', mirrorLayout = true, x = 8, y = 8 },
    TopLeftCorner = { atlas = '%s-NineSlice-Corner', mirrorLayout = true, x = -8, y = 8 },
    BottomLeftCorner = { atlas = '%s-NineSlice-Corner', mirrorLayout = true, x = -8, y = -8 },
    BottomRightCorner = { atlas = '%s-NineSlice-Corner', mirrorLayout = true, x = 8, y = -8 },
    TopEdge = { atlas = '_%s-NineSlice-EdgeTop' },
    BottomEdge = { atlas = '_%s-NineSlice-EdgeBottom' },
    LeftEdge = { atlas = '!%s-NineSlice-EdgeLeft' },
    RightEdge = { atlas = '!%s-NineSlice-EdgeRight' },
    Center = { atlas = '%s-NineSlice-Center', x = -8, y = 8, x1 = 8, y1 = -8 },
}

-- Applies the selection art to frame. Returns false when the client lacks it.
local function applySelectionArt(frame, blendMode)
    if not (NineSliceUtil and AV.Style.HasAtlas(SELECTION_KIT .. '-NineSlice-Center')) then
        return false
    end
    if not pcall(NineSliceUtil.ApplyLayout, frame, SELECTION_LAYOUT, SELECTION_KIT) then
        return false
    end
    local r, g, b, a = AV.Style.Color(SELECTION_TINT)
    for pieceName in pairs(SELECTION_LAYOUT) do
        local piece = frame[pieceName]
        if piece then
            piece:SetDesaturated(true)
            piece:SetVertexColor(r, g, b, a)
            if blendMode then
                piece:SetBlendMode(blendMode)
            end
        end
    end
    return true
end

-- frame: the root to move. label: text on the handle. bounds: optional { topLeft, bottomRight }
-- regions whose corners the handle spans, for content that outgrows frame.
function EditMode.Register(key, frame, label, bounds)
    local mover = CreateFrame('Frame', nil, frame)
    if bounds then
        mover:SetPoint('TOPLEFT', bounds[1], 'TOPLEFT')
        mover:SetPoint('BOTTOMRIGHT', bounds[2], 'BOTTOMRIGHT')
    else
        mover:SetAllPoints(frame)
    end
    mover:SetFrameStrata('DIALOG')
    mover:EnableMouse(true)
    mover:RegisterForDrag('LeftButton')
    mover:Hide()

    if applySelectionArt(mover) then
        -- As Blizzard's: the same art added over itself at 40% while hovered.
        local hover = CreateFrame('Frame', nil, mover)
        hover:SetAllPoints()
        hover:SetAlpha(0.4)
        hover:Hide()
        applySelectionArt(hover, 'ADD')
        mover:SetScript('OnEnter', function() hover:Show() end)
        mover:SetScript('OnLeave', function() hover:Hide() end)
    else
        local bg = mover:CreateTexture(nil, 'BACKGROUND')
        bg:SetAllPoints()
        bg:SetColorTexture(0.2, 0.6, 1, 0.25)
    end
    local text = mover:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightLarge')
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

-- Locking in combat hides the movers at once; the demo, which hides the secure party
-- header, ends when combat does.
function EditMode.SetUnlocked(unlocked)
    if unlocked and InCombatLockdown() then
        AV.Print('cannot unlock frames in combat')
        return
    end
    EditMode.unlocked = unlocked
    for _, mover in pairs(movers) do
        mover:SetShown(unlocked)
    end
    AV.RunOutOfCombat(AV.Demo.Refresh, 'demoRefresh')
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
