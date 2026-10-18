local _, AV = ...

-- Party list: a SecureGroupHeader (player first, then party members; in raids, the player's
-- subgroup). Buttons are pre-created out of combat so mid-combat joins already have visuals.

AV.PartyList = {}
local PartyList = AV.PartyList

local MAX_ROWS = 5
local rows = {}
local rowsByUnit = {}
local petsByUnit = {}

local function playerSubgroup()
    if not IsInRaid() then
        return nil
    end
    local raidIndex = UnitInRaid('player')
    return raidIndex and select(3, GetRaidRosterInfo(raidIndex))
end

local function setGroupNumber(subgroup)
    local text = PartyList.groupText
    if subgroup then
        text:SetFormattedText(GROUP_NUMBER or 'Group %d', subgroup)
    else
        text:SetText('')
    end
end

-- A row is its base height plus a sub-row per flag: 'av-form' (player only, druid in bear/cat
-- form) and 'av-pet' (its pet exists). Secure snippets set the flags and resize the row in
-- combat, where Lua may not resize the protected buttons; rows below follow because the header
-- chains each button under the previous one. Restricted code; `row` is a frame handle.
local SET_ROW_HEIGHT = [[
    row:SetHeight(row:GetAttribute('av-base')
        + (row:GetAttribute('av-form') and row:GetAttribute('av-formHeight') or 0)
        + (row:GetAttribute('av-pet') and row:GetAttribute('av-petHeight') or 0))
]]

-- Lua marks the player's button with 'av-player'.
local FORM_SNIPPET = [[
    local shifted = newstate == 'shifted'
    for i = 1, self:GetAttribute('rowCount') do
        local row = self:GetFrameRef('row' .. i)
        if row and row:GetAttribute('av-player') then
            row:SetAttribute('av-form', shifted)
]] .. SET_ROW_HEIGHT .. [[
        end
    end
]]

-- Run by the pet button as the unit watch shows or hides it.
local PET_SHOW_SNIPPET = [[
    local row = self:GetFrameRef('owner')
    row:SetAttribute('av-pet', true)
]] .. SET_ROW_HEIGHT
local PET_HIDE_SNIPPET = [[
    local row = self:GetFrameRef('owner')
    row:SetAttribute('av-pet', false)
]] .. SET_ROW_HEIGHT

local function rowHeight(button)
    local style = PartyList.style
    local height = style.rowHeight
    if button:GetAttribute('av-form') then
        height = height + style.formRowHeight
    end
    if button:GetAttribute('av-pet') then
        height = height + style.pet.rowHeight
    end
    return height
end

local function createFormDriver()
    if not (RegisterStateDriver and AV.Druid.IsDruid()) then
        return
    end
    local driver = CreateFrame('Frame', nil, UIParent, 'SecureHandlerStateTemplate')
    for i, row in ipairs(rows) do
        driver:SetFrameRef('row' .. i, row.button)
    end
    driver:SetAttribute('rowCount', #rows)
    driver:SetAttribute('_onstate-druidform', FORM_SNIPPET)
    RegisterStateDriver(driver, 'druidform', AV.Druid.CONDITION)
    PartyList.formDriver = driver
end

-- The pet sub-row: a secure unit button at the bottom of the owner's button. It starts hidden
-- so the unit watch's first Show runs the snippet that grows the row.
local function createPetButton(owner, index, style)
    local button = CreateFrame('Button', 'AzerothVistaPartyPetButton' .. index, owner,
        'SecureUnitButtonTemplate, SecureHandlerShowHideTemplate')
    button:Hide()
    button:SetSize(style.width, style.pet.rowHeight)
    button:SetPoint('BOTTOMLEFT', owner, 'BOTTOMLEFT', 0, 0)
    button:RegisterForClicks('AnyUp')
    button:SetAttribute('type1', 'target')
    button:SetAttribute('type2', 'togglemenu')
    button:SetFrameRef('owner', owner)
    button:SetAttribute('_onshow', PET_SHOW_SNIPPET)
    button:SetAttribute('_onhide', PET_HIDE_SNIPPET)
    owner:SetAttribute('av-base', style.rowHeight)
    owner:SetAttribute('av-formHeight', style.formRowHeight)
    owner:SetAttribute('av-petHeight', style.pet.rowHeight)
    if RegisterUnitWatch then
        RegisterUnitWatch(button)
    end
    ClickCastFrames = ClickCastFrames or {}
    ClickCastFrames[button] = true
    return button
end

-- The owner's pet token. The player's pet is 'pet' even in a raid, where its row is raidN.
local function petUnitFor(row)
    local unit = row.unit
    if not unit then
        return nil
    end
    if unit == 'player' or row:IsPlayer() then
        return 'pet'
    end
    local kind, index = unit:match('^(%a+)(%d+)$')
    if kind == 'party' or kind == 'raid' then
        return kind .. 'pet' .. index
    end
    return nil
end

-- Out of combat: re-mark the player's button, point each pet button at its owner's pet and
-- match the heights. Runs after roster and unit changes.
function PartyList.UpdateFormRows()
    AV.RunOutOfCombat(function()
        local shifted = AV.Druid.IsShifted()
        for _, row in ipairs(rows) do
            local isPlayer = row:IsPlayer()
            row.button:SetAttribute('av-player', isPlayer)
            row.button:SetAttribute('av-form', shifted and isPlayer)
            row.pet.button:SetAttribute('unit', petUnitFor(row))
            row.button:SetHeight(rowHeight(row.button))
        end
        PartyList.UpdateBackground()
    end, 'formRows')
end

-- The list's background behind rows stacked from anchor's top-left. Size it with bg.mid:SetHeight
-- (the rows' total height); bg.top and bg.bottom are its first and last pieces.
function PartyList.CreateBackground(anchor)
    local bgSpec = PartyList.style.background
    local bg = CreateFrame('Frame', nil, anchor)
    bg:SetAllPoints(anchor)
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
    bg.top, bg.mid, bg.bottom = top, mid, bottom
    return bg
end

function PartyList.Create(style, fonts)
    local partyStyle = style.party
    PartyList.style = partyStyle
    PartyList.fonts = fonts

    local anchor = CreateFrame('Frame', 'AzerothVistaPartyAnchor', UIParent)
    anchor:SetSize(partyStyle.width, partyStyle.rowHeight * MAX_ROWS + partyStyle.rowSpacing * (MAX_ROWS - 1))
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    PartyList.anchor = anchor

    local bg = PartyList.CreateBackground(anchor)
    PartyList.background = bg
    PartyList.bgMid = bg.mid
    PartyList.groupText = AV.Style.Text(bg, partyStyle.groupNumber, fonts)

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
            local row = AV.PartyRow.Attach(button, partyStyle, fonts)
            row.pet = AV.PetRow.Attach(createPetButton(button, i, partyStyle), row, partyStyle, fonts)
            rows[i] = row
            -- Click-casting addons (Clique and others) bind every frame in this table.
            ClickCastFrames = ClickCastFrames or {}
            ClickCastFrames[button] = true
        end
    end
    if #rows < MAX_ROWS then
        AV.Print('party header built %d of %d buttons', #rows, MAX_ROWS)
    end

    createFormDriver()
    PartyList.UpdateFormRows()
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
    setGroupNumber(members and 1 or PartyList.subgroup)
    local _, _, height = PartyList.StackDemoRows(PartyList.demoRows, members, PartyList.demoFrame)
    PartyList.demoHeight = height
    PartyList.demoFrame:SetShown(members ~= nil)
    PartyList.header:SetShown(members == nil)
    PartyList.UpdateBackground()
end

-- Shows members[i] on demo row demoRows[i] (nil hides it) and stacks the shown rows down from
-- parent's top-left, each as tall as its sub-rows need. A row that would end below maxHeight
-- starts a new column (nil: one column). Columns step by the background's width plus the target
-- cursor's overhang left of the row, so neither overlaps the column before.
-- Returns the columns ({ x, height } each) and the stack's total width and height.
function PartyList.StackDemoRows(demoRows, members, parent, maxHeight)
    local style = PartyList.style
    local bgSpec = style.background
    local columnStep = bgSpec.pos[1] + bgSpec.width - style.cursor.pos[1] + style.rowSpacing
    local columns = {}
    local column
    local y, height = 0, 0
    for i, row in ipairs(demoRows) do
        local member = members and members[i]
        row:ShowDemo(member)
        if member then
            local needed = row:DemoHeight(member)
            if column and maxHeight and y + needed > maxHeight then
                column = nil
            end
            if not column then
                column = { x = #columns * columnStep, height = 0 }
                columns[#columns + 1] = column
                y = 0
            end
            row.host:ClearAllPoints()
            row.host:SetPoint('TOPLEFT', parent, 'TOPLEFT', column.x, -y)
            column.height = y + needed
            height = math.max(height, column.height)
            y = column.height + style.rowSpacing
        end
    end
    local width = column and column.x + style.width or 0
    return columns, width, height
end

function PartyList.OnRowUnitChanged(row, previous, unit)
    if previous and rowsByUnit[previous] == row then
        rowsByUnit[previous] = nil
    end
    if unit then
        rowsByUnit[unit] = row
    end
    if row.pet then
        PartyList.UpdateFormRows()
    end
end

function PartyList.OnPetUnitChanged(pet, previous, unit)
    if previous and petsByUnit[previous] == pet then
        petsByUnit[previous] = nil
    end
    if unit then
        petsByUnit[unit] = pet
    end
end

function PartyList.RowForUnit(unit)
    return rowsByUnit[unit]
end

function PartyList.PetForUnit(unit)
    return petsByUnit[unit]
end

function PartyList.ForEachVisibleRow(fn)
    for _, row in ipairs(rows) do
        if row.button:IsShown() and row.unit then
            fn(row)
        end
    end
end

-- Pets whose sub-row is showing.
function PartyList.ForEachVisiblePet(fn)
    for _, row in ipairs(rows) do
        local pet = row.pet
        if pet and pet.button:IsVisible() and pet.unit then
            fn(pet)
        end
    end
end

-- In a raid, show only the player's subgroup, labelled with its number.
function PartyList.UpdateGroupFilter()
    PartyList.subgroup = playerSubgroup()
    if not PartyList.demoCount then
        setGroupNumber(PartyList.subgroup)
    end
    AV.RunOutOfCombat(function()
        local subgroup = playerSubgroup()
        PartyList.header:SetAttribute('groupFilter', subgroup and tostring(subgroup) or nil)
    end, 'groupFilter')
end

function PartyList.UpdateBackground()
    local style = PartyList.style
    if PartyList.demoCount then
        PartyList.bgMid:SetHeight(math.max(style.rowHeight, PartyList.demoHeight or 0))
        return
    end
    local shown = 0
    local extra = AV.Druid.IsShifted() and style.formRowHeight or 0
    for _, row in ipairs(rows) do
        if row.button:IsShown() then
            shown = shown + 1
            if row.pet and row.pet.button:IsShown() then
                extra = extra + style.pet.rowHeight
            end
        end
    end
    shown = math.max(1, shown)
    local height = shown * style.rowHeight + (shown - 1) * style.rowSpacing + extra
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
    PartyList.ForEachVisiblePet(function(pet)
        pet:Refresh()
    end)
    PartyList.UpdateBackground()
end
