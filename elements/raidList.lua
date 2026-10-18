local _, EUI = ...

-- Raid list: one SecureGroupHeader per subgroup, each a block of up to 5 cells, shown in a raid
-- as Blizzard's raid frames with separate groups. The headers assign the raidN units and lay out
-- the cells, in combat too. Each group keeps the slot its number gives it; an empty group hides
-- its background and label.

EUI.RaidList = {}
local RaidList = EUI.RaidList

local NUM_GROUPS = 8
local GROUP_SIZE = 5
local VISIBILITY = '[group:raid] show; hide'

local groups = {}
local cells = {}
local cellsByUnit = {}

local function cellsHeight(style, count)
    return count * style.rowHeight + (count - 1) * style.rowSpacing
end

-- Group slots step by the background's width plus the target cursor's overhang left of the
-- cells, and by the label above the cells plus the background's bottom padding.
local function slotSteps(style)
    local bg = style.background
    local columnStep = bg.pos[1] + bg.width - style.cursor.pos[1] + style.groupSpacing[1]
    local rowStep = -style.groupNumber.pos[2] + cellsHeight(style, GROUP_SIZE) + bg.bottom.height + style.groupSpacing[2]
    return columnStep, rowStep
end

-- Group g's first cell, from the anchor's top-left.
local function slotOffset(style, g)
    local columnStep, rowStep = slotSteps(style)
    local column = (g - 1) % style.groupsPerRow
    local row = math.floor((g - 1) / style.groupsPerRow)
    return -style.cursor.pos[1] + column * columnStep, -style.groupNumber.pos[2] + row * rowStep
end

local function gridSize(style)
    local columnStep, rowStep = slotSteps(style)
    local rows = math.ceil(NUM_GROUPS / style.groupsPerRow)
    local bg = style.background
    return -style.cursor.pos[1] + (style.groupsPerRow - 1) * columnStep + bg.pos[1] + bg.width,
        rows * rowStep - style.groupSpacing[2]
end

-- The group's background and "Group N" label, on parent's top-left (the first cell's).
local function createChrome(parent, g, style, fonts)
    local bg = EUI.PartyList.CreateBackground(parent, style.background)
    local label = EUI.Style.Header(bg, style.groupNumber, fonts)
    label.label:SetFormattedText(GROUP_NUMBER or 'Group %d', g)
    return bg
end

local function sizeChrome(bg, count, style)
    bg:SetShown(count > 0)
    if count > 0 then
        bg.mid:SetHeight(cellsHeight(style, count))
    end
end

local function updateGroup(group)
    local count = 0
    for _, cell in ipairs(group.cells) do
        if cell.button:IsShown() then
            count = count + 1
        end
    end
    sizeChrome(group.bg, count, RaidList.style)
end

local CELL_HOOKS = {
    unitChanged = function(cell, previous, unit)
        if previous and cellsByUnit[previous] == cell then
            cellsByUnit[previous] = nil
        end
        if unit then
            cellsByUnit[unit] = cell
        end
    end,
    readyCheckPhase = function()
        return EUI.PartyList.ReadyCheckPhase()
    end,
}

-- Click-casting addons (Clique and others) bind every frame in ClickCastFrames.
local function attachCell(group, button)
    local style = RaidList.style
    button:SetSize(style.width, style.rowHeight)
    button:RegisterForClicks('AnyUp')
    ClickCastFrames = ClickCastFrames or {}
    ClickCastFrames[button] = true
    local cell = EUI.PartyRow.Attach(button, style, RaidList.fonts, CELL_HOOKS)
    group.cells[#group.cells + 1] = cell
    cells[#cells + 1] = cell
    button:HookScript('OnShow', function()
        updateGroup(group)
    end)
    button:HookScript('OnHide', function()
        updateGroup(group)
    end)
end

local function createGroup(g, parent, style, fonts)
    local header = CreateFrame('Frame', 'EorzeaUIRaidGroup' .. g, parent, 'SecureGroupHeaderTemplate')
    -- Hidden while configured, so each attribute does not relayout the header.
    header:Hide()
    local x, y = slotOffset(style, g)
    header:SetPoint('TOPLEFT', RaidList.anchor, 'TOPLEFT', x, -y)
    header:SetAttribute('template', 'EorzeaUIRaidButtonTemplate')
    header:SetAttribute('templateType', 'Button')
    header:SetAttribute('showRaid', true)
    header:SetAttribute('groupFilter', tostring(g))
    header:SetAttribute('sortMethod', 'INDEX')
    header:SetAttribute('point', 'TOP')
    header:SetAttribute('yOffset', -style.rowSpacing)
    header:SetAttribute('unitsPerColumn', GROUP_SIZE)
    header:SetAttribute('maxColumns', 1)

    local group = { header = header, cells = {} }
    group.bg = createChrome(header, g, style, fonts)

    -- A negative startingIndex makes the header build every button now, out of combat; the
    -- header keeps them as header[1..n].
    header:Show()
    header:SetAttribute('startingIndex', 1 - GROUP_SIZE)
    header:SetAttribute('startingIndex', 1)
    for i = 1, GROUP_SIZE do
        local button = header[i]
        if button then
            attachCell(group, button)
        else
            EUI.LogOnce('raid:button', 'raid group header built %d of %d buttons', i - 1, GROUP_SIZE)
            break
        end
    end
    if RegisterStateDriver then
        RegisterStateDriver(header, 'visibility', VISIBILITY)
    end
    updateGroup(group)
    return group
end

function RaidList.Create(style, fonts)
    local raidStyle = style.raid
    RaidList.style = raidStyle
    RaidList.fonts = fonts

    local anchor = CreateFrame('Frame', 'EorzeaUIRaidAnchor', UIParent)
    anchor:SetSize(gridSize(raidStyle))
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    RaidList.anchor = anchor

    -- Plain parent of the headers, so the demo can hide them all out of combat.
    local groupsFrame = CreateFrame('Frame', nil, anchor)
    groupsFrame:SetAllPoints(anchor)
    groupsFrame:SetFrameLevel(anchor:GetFrameLevel() + 2)
    RaidList.groupsFrame = groupsFrame

    for g = 1, NUM_GROUPS do
        groups[g] = createGroup(g, groupsFrame, raidStyle, fonts)
    end
end

-- Events for you arrive as 'player' and go to your cell; events by its raidN token are dropped,
-- so it updates once.
function RaidList.CellForUnit(unit)
    if unit == 'player' then
        for _, cell in ipairs(cells) do
            if cell.isSelf and cell.button:IsVisible() then
                return cell
            end
        end
        return nil
    end
    local cell = cellsByUnit[unit]
    if not cell or not cell.button:IsVisible() then
        return nil
    end
    if cell.isSelf then
        EUI.LogOnce('raid:selfToken', 'raid: events for you also arrive as %s', tostring(unit))
        return nil
    end
    return cell
end

function RaidList.ForEachVisibleCell(fn)
    for _, cell in ipairs(cells) do
        if cell.button:IsVisible() and cell.unit then
            fn(cell)
        end
    end
end

function RaidList.RefreshAll()
    RaidList.ForEachVisibleCell(function(cell)
        cell:Refresh()
    end)
    for _, group in ipairs(groups) do
        updateGroup(group)
    end
end

-- A roster change can put someone else behind a cell's token without changing it.
function RaidList.OnRosterChanged()
    RaidList.RefreshAll()
end

-- members: one list of demo member tables per group (PartyRow ShowDemo), or nil to restore the
-- live groups. The headers are protected, so this runs out of combat only.
function RaidList.SetDemo(members)
    local style = RaidList.style
    if not RaidList.demoFrame then
        local frame = CreateFrame('Frame', nil, RaidList.anchor)
        frame:SetAllPoints(RaidList.anchor)
        frame:SetFrameLevel(RaidList.groupsFrame:GetFrameLevel() + 5)
        RaidList.demoFrame = frame
        RaidList.demoGroups = {}
        for g = 1, NUM_GROUPS do
            local slot = CreateFrame('Frame', nil, frame)
            slot:SetSize(style.width, style.rowHeight)
            local x, y = slotOffset(style, g)
            slot:SetPoint('TOPLEFT', RaidList.anchor, 'TOPLEFT', x, -y)
            local rows = {}
            for i = 1, GROUP_SIZE do
                local row = EUI.PartyRow.CreateDemo(slot, style, RaidList.fonts)
                row.host:SetPoint('TOPLEFT', slot, 'TOPLEFT', 0, -(i - 1) * (style.rowHeight + style.rowSpacing))
                rows[i] = row
            end
            RaidList.demoGroups[g] = { bg = createChrome(slot, g, style, RaidList.fonts), rows = rows }
        end
    end
    if members then
        for g, group in ipairs(RaidList.demoGroups) do
            local list = members[g] or {}
            for i, row in ipairs(group.rows) do
                row:ShowDemo(list[i])
            end
            sizeChrome(group.bg, #list, style)
        end
    end
    RaidList.demoFrame:SetShown(members ~= nil)
    RaidList.groupsFrame:SetShown(members == nil)
end
