local _, EUI = ...

-- Party list: five secure unit buttons stacked under one another, each with a pet button, as
-- Blizzard's PartyFrame. Their units never change: player, party1-4 and pet, partypet1-4. The
-- client renumbers the party tokens as members leave and the unit watch hides rows whose unit
-- is gone, so roster changes need no secure work in combat. In a raid a state driver hides rows
-- 2-5, leaving the player's row as the player frame; the raid list shows the groups.
-- With style.standalone the player's row has its own anchor (the player frame) and the party
-- anchor holds rows 2-5, its background hidden while none shows, as Blizzard's PartyFrame. With
-- style.growUp the party anchor's rows stack up from its bottom edge (PartyList.ApplyLayout).

EUI.PartyList = {}
local PartyList = EUI.PartyList

local MAX_ROWS = 5
local rows = {}
-- Each anchor's list: { anchor, bg, rowsFrame, rows, first (index of its first row), size,
-- growUp, hideEmpty, demo fields }.
local lists = {}
local rowsByUnit = {}
local petsByUnit = {}

-- A row is its base height plus a sub-row per flag: 'eui-form' (player only, druid in bear/cat
-- form) and 'eui-pet' (its pet exists). Secure snippets set the flags and resize the row in
-- combat, where Lua may not resize the protected buttons; rows below follow because each button
-- is anchored under the previous one. Restricted code; `row` is a frame handle.
local SET_ROW_HEIGHT = [[
    row:SetHeight(row:GetAttribute('eui-base')
        + (row:GetAttribute('eui-form') and row:GetAttribute('eui-formHeight') or 0)
        + (row:GetAttribute('eui-pet') and row:GetAttribute('eui-petHeight') or 0))
]]

-- Resizes the player's row, always the first.
local FORM_SNIPPET = [[
    local row = self:GetFrameRef('player')
    row:SetAttribute('eui-form', newstate == 'shifted')
]] .. SET_ROW_HEIGHT

-- Run by the pet button as the unit watch shows or hides it.
local PET_SHOW_SNIPPET = [[
    local row = self:GetFrameRef('owner')
    row:SetAttribute('eui-pet', true)
]] .. SET_ROW_HEIGHT
local PET_HIDE_SNIPPET = [[
    local row = self:GetFrameRef('owner')
    row:SetAttribute('eui-pet', false)
]] .. SET_ROW_HEIGHT

local function rowHeight(button)
    local style = PartyList.style
    local height = style.rowHeight
    if button:GetAttribute('eui-form') then
        height = height + style.formRowHeight
    end
    if button:GetAttribute('eui-pet') then
        height = height + style.pet.rowHeight
    end
    return height
end

local function createFormDriver()
    if not (RegisterStateDriver and EUI.Druid.IsDruid()) then
        return
    end
    local driver = CreateFrame('Frame', nil, UIParent, 'SecureHandlerStateTemplate')
    driver:SetFrameRef('player', rows[1].button)
    driver:SetAttribute('_onstate-druidform', FORM_SNIPPET)
    RegisterStateDriver(driver, 'druidform', EUI.Druid.CONDITION)
end

-- The pet sub-row: a secure unit button at the bottom of the owner's button. It starts hidden
-- so the unit watch's first Show runs the snippet that grows the row.
-- The unit watch shows the button while its unit exists. Click-casting addons (Clique and
-- others) bind every frame in ClickCastFrames.
local function watchButton(button)
    if RegisterUnitWatch then
        RegisterUnitWatch(button)
    end
    ClickCastFrames = ClickCastFrames or {}
    ClickCastFrames[button] = true
end

local function createPetButton(owner, index, style)
    local button = CreateFrame('Button', 'EorzeaUIPartyPetButton' .. index, owner,
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
    owner:SetAttribute('eui-base', style.rowHeight)
    owner:SetAttribute('eui-formHeight', style.formRowHeight)
    owner:SetAttribute('eui-petHeight', style.pet.rowHeight)
    watchButton(button)
    return button
end

local PARTY_UNITS = { 'player', 'party1', 'party2', 'party3', 'party4' }
local PARTY_PETS = { 'pet', 'partypet1', 'partypet2', 'partypet3', 'partypet4' }

-- Hides rows 2-5 in a raid, in combat too.
local MEMBERS_VISIBILITY = '[group:raid] hide; show'

-- Out of combat: match each row's form flag and height to the druid's current form.
function PartyList.UpdateFormRows()
    EUI.RunOutOfCombat(function()
        local shifted = EUI.Druid.IsShifted()
        for _, row in ipairs(rows) do
            row.button:SetAttribute('eui-form', shifted and row.button:GetAttribute('eui-player') == true)
            row.button:SetHeight(rowHeight(row.button))
        end
        PartyList.UpdateBackground()
    end, 'formRows')
end

-- Anchors a background's pieces (CreateBackground) from anchor's top, or its bottom.
function PartyList.PlaceBackground(bg, anchor, bgSpec, fromBottom)
    local top, mid, bottom = bg.top, bg.mid, bg.bottom
    top:ClearAllPoints()
    mid:ClearAllPoints()
    bottom:ClearAllPoints()
    if fromBottom then
        -- The same padding around the rows as from the top.
        local below = bgSpec.pos[2] + bgSpec.top.height + bgSpec.bottom.height
        bottom:SetPoint('BOTTOMLEFT', anchor, 'BOTTOMLEFT', bgSpec.pos[1], -below)
        mid:SetPoint('BOTTOMLEFT', bottom, 'TOPLEFT', 0, 0)
        top:SetPoint('BOTTOMLEFT', mid, 'TOPLEFT', 0, 0)
    else
        EUI.Style.Place(top, anchor, bgSpec.pos)
        mid:SetPoint('TOPLEFT', top, 'BOTTOMLEFT', 0, 0)
        bottom:SetPoint('TOPLEFT', mid, 'BOTTOMLEFT', 0, 0)
    end
end

-- The list's background behind rows stacked from anchor's top-left, or up from its bottom-left
-- with fromBottom. Size it with bg.mid:SetHeight (the rows' total height); bg.top and bg.bottom
-- pad it above and below. One fade spans all three.
-- bgSpec: a style's background, default the party list's.
function PartyList.CreateBackground(anchor, bgSpec, fromBottom)
    bgSpec = bgSpec or PartyList.style.background
    local bg = CreateFrame('Frame', nil, anchor)
    bg:SetAllPoints(anchor)
    bg:SetFrameLevel(anchor:GetFrameLevel())
    local function bgPiece(height)
        local texture = bg:CreateTexture(nil, 'BACKGROUND')
        texture:SetColorTexture(0, 0, 0, 0)
        texture:SetWidth(bgSpec.width)
        if height then
            texture:SetHeight(height)
        end
        return texture
    end
    local top = bgPiece(bgSpec.top.height)
    local mid = bgPiece()
    local bottom = bgPiece(bgSpec.bottom.height)
    bg.top, bg.mid, bg.bottom = top, mid, bottom
    PartyList.PlaceBackground(bg, anchor, bgSpec, fromBottom)
    local fade = EUI.Style.Fade(bg, { width = bgSpec.width }, 'BACKGROUND')
    fade:SetPoint('TOPLEFT', top, 'TOPLEFT', 0, 0)
    fade:SetPoint('BOTTOMRIGHT', bottom, 'BOTTOMRIGHT', 0, 0)
    EUI.Style.ColorFade(fade, bgSpec.color, bgSpec)
    fade:Show()
    return bg
end

-- Moves object's entry in map from previous to unit, unless another object took previous.
local function trackUnit(map, object, previous, unit)
    if previous and map[previous] == object then
        map[previous] = nil
    end
    if unit then
        map[unit] = object
    end
end

-- Callbacks the rows and pet sub-rows report through (PartyRow.Attach, PetRow.Attach).
local ROW_HOOKS = {
    unitChanged = function(row, previous, unit)
        trackUnit(rowsByUnit, row, previous, unit)
    end,
    readyCheckPhase = function()
        return PartyList.ReadyCheckPhase()
    end,
}
local PET_HOOKS = {
    unitChanged = function(pet, previous, unit)
        trackUnit(petsByUnit, pet, previous, unit)
    end,
    heightChanged = function()
        PartyList.UpdateBackground()
    end,
}

-- Edit Mode handle (EditMode.Register's box) for anchor (the party or player anchor): its
-- background, widened left over the class icon and the badges straddling it.
function PartyList.EditBox(anchor)
    local style = PartyList.style
    local bg
    for _, list in ipairs(lists) do
        if list.anchor == anchor then
            bg = list.bg
        end
    end
    local indicators = style.indicators
    local left = math.min(style.classIcon.pos[1], indicators.role.pos[1], indicators.pvp.pos[1])
    return { topRegion = bg.top, bottomRegion = bg.bottom, left = style.background.pos[1] - left }
end

-- An anchor holding size rows from row first, with its background and rows frame.
local function anchorHeight(size)
    local style = PartyList.style
    return style.rowHeight * size + style.rowSpacing * (size - 1)
end

-- key: the anchor's Edit Mode key. followsGrowUp: the list takes style.growUp.
local function createList(name, key, first, size, followsGrowUp)
    local style = PartyList.style
    local growUp = followsGrowUp and style.growUp or false
    local anchor = CreateFrame('Frame', name, UIParent)
    anchor:SetSize(style.width, anchorHeight(size))
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    -- Plain parent of the secure buttons, so the demo can hide them all out of combat.
    local rowsFrame = CreateFrame('Frame', nil, anchor)
    rowsFrame:SetAllPoints(anchor)
    rowsFrame:SetFrameLevel(anchor:GetFrameLevel() + 2)
    local list = {
        anchor = anchor, key = key, rowsFrame = rowsFrame, rows = {}, first = first, size = size,
        growUp = growUp, followsGrowUp = followsGrowUp,
        bg = PartyList.CreateBackground(anchor, nil, growUp),
    }
    lists[#lists + 1] = list
    return list
end

-- Stacks button after the list's last row, down or (growUp) up.
local function placeRow(list, button)
    local previous = list.rows[#list.rows]
    local spacing = PartyList.style.rowSpacing
    if list.growUp then
        if previous then
            button:SetPoint('BOTTOMLEFT', previous.button, 'TOPLEFT', 0, spacing)
        else
            button:SetPoint('BOTTOMLEFT', list.rowsFrame, 'BOTTOMLEFT', 0, 0)
        end
    elseif previous then
        button:SetPoint('TOPLEFT', previous.button, 'BOTTOMLEFT', 0, -spacing)
    else
        button:SetPoint('TOPLEFT', list.rowsFrame, 'TOPLEFT', 0, 0)
    end
end

function PartyList.Create(style, fonts)
    local partyStyle = style.party
    PartyList.style = partyStyle
    PartyList.fonts = fonts

    local playerList, partyList
    if partyStyle.standalone then
        playerList = createList('EorzeaUIPlayerAnchor', 'player', 1, 1, false)
        partyList = createList('EorzeaUIPartyAnchor', 'party', 2, MAX_ROWS - 1, true)
        partyList.hideEmpty = true
        PartyList.playerAnchor = playerList.anchor
    else
        partyList = createList('EorzeaUIPartyAnchor', 'party', 1, MAX_ROWS, true)
        playerList = partyList
    end
    PartyList.anchor = partyList.anchor
    PartyList.partyList = partyList

    -- Parent of rows 2-5.
    local members = CreateFrame('Frame', nil, partyList.rowsFrame, 'SecureHandlerStateTemplate')
    members:SetAllPoints(partyList.rowsFrame)
    members:SetFrameLevel(partyList.rowsFrame:GetFrameLevel())
    members:HookScript('OnShow', PartyList.UpdateBackground)
    members:HookScript('OnHide', PartyList.UpdateBackground)

    for i = 1, MAX_ROWS do
        local list = i == 1 and playerList or partyList
        local button = CreateFrame('Button', 'EorzeaUIPartyButton' .. i, i == 1 and playerList.rowsFrame or members, 'EorzeaUIPartyButtonTemplate')
        button:SetWidth(partyStyle.width)
        placeRow(list, button)
        button:RegisterForClicks('AnyUp')
        button:SetAttribute('eui-player', i == 1)
        button:SetAttribute('unit', PARTY_UNITS[i])
        local row = EUI.PartyRow.Attach(button, partyStyle, fonts, ROW_HOOKS)
        local petButton = createPetButton(button, i, partyStyle)
        petButton:SetAttribute('unit', PARTY_PETS[i])
        if i == 1 then
            PartyList.ownPetButton = petButton
        end
        row.pet = EUI.PetRow.Attach(petButton, row, partyStyle, fonts, PET_HOOKS)
        rows[i] = row
        list.rows[#list.rows + 1] = row
        button:HookScript('OnShow', PartyList.UpdateBackground)
        button:HookScript('OnHide', PartyList.UpdateBackground)
        watchButton(button)
    end

    if RegisterStateDriver then
        RegisterStateDriver(members, 'visibility', MEMBERS_VISIBILITY)
    end
    createFormDriver()
    PartyList.UpdateFormRows()
end

-- A growUp list's demo frame is as tall as its rows (setListDemo), on the anchor's bottom.
local function placeDemoFrame(list)
    local frame = list.demoFrame
    frame:ClearAllPoints()
    if list.growUp then
        frame:SetPoint('BOTTOMLEFT', list.anchor, 'BOTTOMLEFT', 0, 0)
        frame:SetPoint('BOTTOMRIGHT', list.anchor, 'BOTTOMRIGHT', 0, 0)
    else
        frame:SetAllPoints(list.anchor)
    end
end

-- Re-stacks the rows and background for style.rowSpacing and style.growUp. The buttons are
-- protected, so this waits for combat to end.
function PartyList.ApplyLayout()
    EUI.RunOutOfCombat(function()
        local style = PartyList.style
        for _, list in ipairs(lists) do
            list.growUp = list.followsGrowUp and style.growUp or false
            local placed = list.rows
            list.rows = {}
            for _, row in ipairs(placed) do
                row.button:ClearAllPoints()
                placeRow(list, row.button)
                list.rows[#list.rows + 1] = row
            end
            PartyList.PlaceBackground(list.bg, list.anchor, style.background, list.growUp)
            if list.demoFrame then
                placeDemoFrame(list)
            end
            EUI.EditMode.ResizeKeepingTopLeft(list.key, list.anchor, style.width, anchorHeight(list.size))
        end
        PartyList.UpdateBackground()
    end, 'partyLayout')
end

-- Shows members (the whole party's, or nil) on list's demo rows: the entries for its rows, in
-- stacking order.
local function setListDemo(list, members)
    if not list.demoFrame then
        local frame = CreateFrame('Frame', nil, list.anchor)
        frame:SetFrameLevel(list.rowsFrame:GetFrameLevel() + 5)
        list.demoFrame = frame
        placeDemoFrame(list)
        list.demoRows = {}
        for i = 1, list.size do
            list.demoRows[i] = EUI.PartyRow.CreateDemo(frame, PartyList.style, PartyList.fonts)
        end
    end
    local own
    if members then
        own = {}
        for i = list.first, math.min(#members, list.first + list.size - 1) do
            table.insert(own, list.growUp and 1 or #own + 1, members[i])
        end
    end
    list.demoCount = own and #own or nil
    local _, _, height = PartyList.StackDemoRows(list.demoRows, own, list.demoFrame)
    list.demoHeight = height
    if list.growUp then
        list.demoFrame:SetHeight(math.max(1, height))
    end
    list.demoFrame:SetShown(members ~= nil)
    list.rowsFrame:SetShown(members == nil)
end

-- members: list of demo member tables to show in place of the live rows, or nil to restore them.
-- The rows are protected, so this runs out of combat only.
function PartyList.SetDemo(members)
    for _, list in ipairs(lists) do
        setListDemo(list, members)
    end
    PartyList.demoHeight = PartyList.partyList.demoHeight
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

function PartyList.RowForUnit(unit)
    return rowsByUnit[unit]
end

-- Your pet's sub-row shows only while PetUsesPetFrame(), as Blizzard's pet frame. The unit watch
-- can't test that, so it is switched on and off out of combat.
function PartyList.UpdateOwnPet()
    local button = PartyList.ownPetButton
    if not (button and PetUsesPetFrame and RegisterUnitWatch and UnregisterUnitWatch) then
        return
    end
    EUI.RunOutOfCombat(function()
        if EUI.SafeValue(PetUsesPetFrame) == false then
            UnregisterUnitWatch(button)
            button:Hide()
        else
            RegisterUnitWatch(button)
        end
    end, 'ownPetFrame')
end

function PartyList.PetForUnit(unit)
    return petsByUnit[unit]
end

function PartyList.ForEachVisibleRow(fn)
    for _, row in ipairs(rows) do
        if row.button:IsVisible() and row.unit then
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

function PartyList.OnRosterChanged()
    PartyList.UpdateBackground()
end

local function updateListBackground(list)
    local style = PartyList.style
    if list.demoCount then
        list.bg:SetShown(not (list.hideEmpty and list.demoCount == 0))
        list.bg.mid:SetHeight(math.max(style.rowHeight, list.demoHeight or 0))
        return
    end
    local shown = 0
    local extra = 0
    for _, row in ipairs(list.rows) do
        if row.button:IsVisible() then
            shown = shown + 1
            if row == rows[1] and EUI.Druid.IsShifted() then
                extra = extra + style.formRowHeight
            end
            if row.pet and row.pet.button:IsVisible() then
                extra = extra + style.pet.rowHeight
            end
        end
    end
    list.bg:SetShown(not (list.hideEmpty and shown == 0))
    shown = math.max(1, shown)
    list.bg.mid:SetHeight(shown * style.rowHeight + (shown - 1) * style.rowSpacing + extra)
end

function PartyList.UpdateBackground()
    for _, list in ipairs(lists) do
        updateListBackground(list)
    end
end

-- Seconds results stay on screen after the check ends: Blizzard's party frames keep them 10, its
-- raid frames 11.
local READY_CHECK_LINGER = { party = 10, raid = 11 }
local readyPhase
local readyGeneration = 0

function PartyList.ReadyCheckPhase()
    return readyPhase
end

-- forEach(fn): calls fn on every shown row taking ready checks; default the party rows.
function PartyList.OnReadyCheck(event, forEach)
    forEach = forEach or PartyList.ForEachVisibleRow
    if event == 'READY_CHECK' then
        readyPhase = 'active'
        readyGeneration = readyGeneration + 1
    elseif event == 'READY_CHECK_FINISHED' then
        readyPhase = 'finished'
        readyGeneration = readyGeneration + 1
        local generation = readyGeneration
        C_Timer.After(IsInRaid() and READY_CHECK_LINGER.raid or READY_CHECK_LINGER.party, function()
            if generation == readyGeneration then
                readyPhase = nil
                forEach(function(row)
                    row:UpdateReadyCheck(nil)
                end)
            end
        end)
    end
    forEach(function(row)
        row:UpdateReadyCheck(readyPhase)
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
