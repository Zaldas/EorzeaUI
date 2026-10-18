local _, AV = ...

-- Party list: five secure unit buttons stacked under one another, each with a pet button, as
-- Blizzard's PartyFrame. In a party their units never change: player, party1-4 and pet,
-- partypet1-4. The client renumbers the party tokens as members leave and the unit watch hides
-- rows whose unit is gone, so roster changes need no secure work in combat. In a raid the rows
-- show the player's subgroup, assigned out of combat as Blizzard's raid groups are.

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
    local header = PartyList.groupHeader
    if subgroup then
        header.label:SetFormattedText(GROUP_NUMBER or 'Group %d', subgroup)
    end
    header:SetShown(subgroup ~= nil)
end

-- A row is its base height plus a sub-row per flag: 'av-form' (player only, druid in bear/cat
-- form) and 'av-pet' (its pet exists). Secure snippets set the flags and resize the row in
-- combat, where Lua may not resize the protected buttons; rows below follow because each button
-- is anchored under the previous one. Restricted code; `row` is a frame handle.
local SET_ROW_HEIGHT = [[
    row:SetHeight(row:GetAttribute('av-base')
        + (row:GetAttribute('av-form') and row:GetAttribute('av-formHeight') or 0)
        + (row:GetAttribute('av-pet') and row:GetAttribute('av-petHeight') or 0))
]]

-- The first row, always the player, carries 'av-player'.
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

local PARTY_UNITS = { 'player', 'party1', 'party2', 'party3', 'party4' }
local PARTY_PETS = { 'pet', 'partypet1', 'partypet2', 'partypet3', 'partypet4' }

-- The units each row shows: the party tokens, or in a raid the player then the rest of the
-- player's subgroup in raid order (raidN, raidpetN).
local function rowUnits(subgroup)
    if not subgroup then
        return PARTY_UNITS, PARTY_PETS
    end
    local units, pets = { 'player' }, { 'pet' }
    local playerGuid = AV.SafeValue(UnitGUID, 'player')
    for i = 1, GetNumGroupMembers() do
        local unit = 'raid' .. i
        if #units < MAX_ROWS and select(3, GetRaidRosterInfo(i)) == subgroup
            and AV.SafeValue(UnitGUID, unit) ~= playerGuid then
            units[#units + 1] = unit
            pets[#pets + 1] = 'raidpet' .. i
        end
    end
    return units, pets
end

-- Out of combat: point each row and its pet button at its unit. In a party this sets the same
-- tokens every time, which the rows ignore.
local function assignUnits()
    AV.RunOutOfCombat(function()
        local subgroup = playerSubgroup()
        PartyList.subgroup = subgroup
        if not PartyList.demoCount then
            setGroupNumber(subgroup)
        end
        local units, pets = rowUnits(subgroup)
        for i, row in ipairs(rows) do
            row.button:SetAttribute('unit', units[i])
            row.pet.button:SetAttribute('unit', pets[i])
        end
        PartyList.UpdateBackground()
    end, 'assignUnits')
end

-- Out of combat: match each row's form flag and height to the druid's current form.
function PartyList.UpdateFormRows()
    AV.RunOutOfCombat(function()
        local shifted = AV.Druid.IsShifted()
        for _, row in ipairs(rows) do
            row.button:SetAttribute('av-form', shifted and row.button:GetAttribute('av-player') == true)
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
    PartyList.groupHeader = AV.Style.Header(bg, partyStyle.groupNumber, fonts)

    -- Plain parent of the secure buttons, so the demo can hide them all out of combat.
    local rowsFrame = CreateFrame('Frame', nil, anchor)
    rowsFrame:SetAllPoints(anchor)
    rowsFrame:SetFrameLevel(anchor:GetFrameLevel() + 2)
    PartyList.rowsFrame = rowsFrame

    local previous
    for i = 1, MAX_ROWS do
        local button = CreateFrame('Button', 'AzerothVistaPartyButton' .. i, rowsFrame, 'AzerothVistaPartyButtonTemplate')
        if previous then
            button:SetPoint('TOPLEFT', previous, 'BOTTOMLEFT', 0, -partyStyle.rowSpacing)
        else
            button:SetPoint('TOPLEFT', rowsFrame, 'TOPLEFT', 0, 0)
        end
        previous = button
        button:RegisterForClicks('AnyUp')
        button:SetAttribute('av-player', i == 1)
        button:SetAttribute('unit', PARTY_UNITS[i])
        local row = AV.PartyRow.Attach(button, partyStyle, fonts)
        local petButton = createPetButton(button, i, partyStyle)
        petButton:SetAttribute('unit', PARTY_PETS[i])
        row.pet = AV.PetRow.Attach(petButton, row, partyStyle, fonts)
        rows[i] = row
        button:HookScript('OnShow', PartyList.UpdateBackground)
        button:HookScript('OnHide', PartyList.UpdateBackground)
        if RegisterUnitWatch then
            RegisterUnitWatch(button)
        end
        -- Click-casting addons (Clique and others) bind every frame in this table.
        ClickCastFrames = ClickCastFrames or {}
        ClickCastFrames[button] = true
    end

    createFormDriver()
    assignUnits()
    PartyList.UpdateFormRows()
end

-- members: list of demo rows to show in place of the live rows, or nil to restore them.
-- The rows are protected, so this runs out of combat only.
function PartyList.SetDemo(members)
    if not PartyList.demoFrame then
        local frame = CreateFrame('Frame', nil, PartyList.anchor)
        frame:SetAllPoints(PartyList.anchor)
        frame:SetFrameLevel(PartyList.rowsFrame:GetFrameLevel() + 5)
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
    PartyList.rowsFrame:SetShown(members == nil)
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

-- Roster changes: in a raid, the rows follow the player's subgroup.
function PartyList.OnRosterChanged()
    assignUnits()
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
