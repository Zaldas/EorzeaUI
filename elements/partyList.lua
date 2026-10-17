local _, AV = ...

-- Party list: a SecureGroupHeader (player first, then party members; in raids, the player's
-- subgroup). Buttons are pre-created out of combat so mid-combat joins already have visuals.

AV.PartyList = {}
local PartyList = AV.PartyList

local MAX_ROWS = 5
local rows = {}
local rowsByUnit = {}

function PartyList.Create(style, fonts)
    local partyStyle = style.party

    local anchor = CreateFrame('Frame', 'AzerothVistaPartyAnchor', UIParent)
    anchor:SetSize(partyStyle.width, partyStyle.rowHeight * MAX_ROWS + partyStyle.rowSpacing * (MAX_ROWS - 1))
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    PartyList.anchor = anchor

    local bgSpec = partyStyle.background
    local bg = CreateFrame('Frame', nil, anchor)
    bg:SetFrameLevel(anchor:GetFrameLevel())
    local r, g, b, a = AV.Style.Color(bgSpec.color)
    local function bgPiece(path, height)
        local texture = bg:CreateTexture(nil, 'BACKGROUND')
        texture:SetTexture(AV.Style.AssetPath(path))
        texture:SetVertexColor(r, g, b, a)
        texture:SetWidth(bgSpec.width)
        if height then
            texture:SetHeight(height)
        end
        return texture
    end
    local top = bgPiece(bgSpec.top.path, bgSpec.top.height)
    local mid = bgPiece(bgSpec.mid.path)
    local bottom = bgPiece(bgSpec.bottom.path, bgSpec.bottom.height)
    AV.Style.Place(top, anchor, bgSpec.pos)
    mid:SetPoint('TOPLEFT', top, 'BOTTOMLEFT', 0, 0)
    bottom:SetPoint('TOPLEFT', mid, 'BOTTOMLEFT', 0, 0)
    PartyList.bgMid = mid

    local header = CreateFrame('Frame', 'AzerothVistaPartyHeader', anchor, 'SecureGroupHeaderTemplate')
    header:SetPoint('TOPLEFT', anchor, 'TOPLEFT', 0, 0)
    header:SetFrameLevel(anchor:GetFrameLevel() + 2)
    header:SetAttribute('template', 'AzerothVistaPartyButtonTemplate')
    header:SetAttribute('showPlayer', true)
    header:SetAttribute('showSolo', true)
    header:SetAttribute('showParty', true)
    header:SetAttribute('showRaid', true)
    header:SetAttribute('point', 'TOP')
    header:SetAttribute('yOffset', -partyStyle.rowSpacing)
    header:SetAttribute('sortMethod', 'INDEX')
    header:SetAttribute('unitsPerColumn', MAX_ROWS)
    header:SetAttribute('maxColumns', 1)
    PartyList.header = header
    PartyList.UpdateGroupFilter()

    -- Showing with a negative startingIndex forces the header to build every button now.
    header:SetAttribute('startingIndex', 1 - MAX_ROWS)
    header:Show()
    header:SetAttribute('startingIndex', 1)

    for i = 1, MAX_ROWS do
        local button = _G['AzerothVistaPartyHeaderUnitButton' .. i]
        if button then
            button:RegisterForClicks('AnyUp')
            rows[i] = AV.PartyRow.Attach(button, partyStyle, fonts)
            -- Click-casting addons (Clique and others) bind every frame in this table.
            ClickCastFrames = ClickCastFrames or {}
            ClickCastFrames[button] = true
        end
    end
    if #rows < MAX_ROWS then
        AV.Print('party header built %d of %d buttons', #rows, MAX_ROWS)
    end

    PartyList.style = partyStyle
    PartyList.fonts = fonts
    PartyList.UpdateBackground()
end

-- members: list of demo rows to show in place of the live header, or nil to restore it.
-- The header is protected, so this runs out of combat only.
function PartyList.SetDemo(members)
    if not PartyList.demoFrame then
        local frame = CreateFrame('Frame', nil, PartyList.anchor)
        frame:SetAllPoints(PartyList.anchor)
        frame:SetFrameLevel(PartyList.header:GetFrameLevel() + 5)
        PartyList.demoFrame = frame
        PartyList.demoRows = {}
        for i = 1, MAX_ROWS do
            PartyList.demoRows[i] = AV.PartyRow.CreateDemo(frame, PartyList.style, PartyList.fonts, i)
        end
    end
    PartyList.demoCount = members and #members or nil
    for i, row in ipairs(PartyList.demoRows) do
        row:ShowDemo(members and members[i])
    end
    PartyList.demoFrame:SetShown(members ~= nil)
    PartyList.header:SetShown(members == nil)
    PartyList.UpdateBackground()
end

function PartyList.OnRowUnitChanged(row, previous, unit)
    if previous and rowsByUnit[previous] == row then
        rowsByUnit[previous] = nil
    end
    if unit then
        rowsByUnit[unit] = row
    end
end

function PartyList.RowForUnit(unit)
    return rowsByUnit[unit]
end

function PartyList.ForEachVisibleRow(fn)
    for _, row in ipairs(rows) do
        if row.button:IsShown() and row.unit then
            fn(row)
        end
    end
end

-- In a raid, show only the player's subgroup.
function PartyList.UpdateGroupFilter()
    AV.RunOutOfCombat(function()
        local header = PartyList.header
        local filter = nil
        if IsInRaid() then
            local raidIndex = UnitInRaid('player')
            local subgroup = raidIndex and select(3, GetRaidRosterInfo(raidIndex))
            filter = subgroup and tostring(subgroup) or nil
        end
        header:SetAttribute('groupFilter', filter)
    end, 'groupFilter')
end

function PartyList.UpdateBackground()
    local shown = PartyList.demoCount or 0
    if not PartyList.demoCount then
        for _, row in ipairs(rows) do
            if row.button:IsShown() then
                shown = shown + 1
            end
        end
    end
    local style = PartyList.style
    shown = math.max(1, shown)
    local height = shown * style.rowHeight + (shown - 1) * style.rowSpacing
    PartyList.bgMid:SetHeight(height)
end

-- Results stay on screen this long after the check ends, as on Blizzard's frames.
local READY_CHECK_LINGER = 10
local readyPhase
local readyGeneration = 0

function PartyList.ReadyCheckPhase()
    return readyPhase
end

function PartyList.OnReadyCheck(event)
    if event == 'READY_CHECK' then
        readyPhase = 'active'
        readyGeneration = readyGeneration + 1
    elseif event == 'READY_CHECK_FINISHED' then
        readyPhase = 'finished'
        readyGeneration = readyGeneration + 1
        local generation = readyGeneration
        C_Timer.After(READY_CHECK_LINGER, function()
            if generation == readyGeneration then
                readyPhase = nil
                PartyList.ForEachVisibleRow(function(row)
                    row:UpdateReadyCheck(nil)
                end)
            end
        end)
    end
    PartyList.ForEachVisibleRow(function(row)
        row:UpdateReadyCheck(readyPhase)
    end)
end

function PartyList.UpdateStatusIcons()
    PartyList.ForEachVisibleRow(function(row)
        row:UpdateStatusIcon()
    end)
end

function PartyList.RefreshAll()
    PartyList.ForEachVisibleRow(function(row)
        row:Refresh()
    end)
    PartyList.UpdateBackground()
end
