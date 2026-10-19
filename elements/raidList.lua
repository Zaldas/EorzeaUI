local _, EUI = ...

-- Raid list: one SecureGroupHeader per subgroup, each a block of up to 5 cells, shown in a raid
-- as Blizzard's raid frames with separate groups. The headers assign the raidN units and lay out
-- the cells, in combat too. Out of combat, occupied groups take the first slots in group order
-- and empty ones the rest, so a group filled in combat appears in a free slot. A separate Assists
-- block lists the main tanks and assists, each followed by their target and that unit's target;
-- they also stay in their own group.

EUI.RaidList = {}
local RaidList = EUI.RaidList

local Style = EUI.Style

local NUM_GROUPS = 8
local GROUP_SIZE = 5
local VISIBILITY = '[group:raid] show; hide'

local groups = {}
local cells = {}
-- unit -> set of cells showing it; a main tank shows in its group and in Assists.
local cellsByUnit = {}
local targetCells = {}

-- rowHeight (optional) overrides style.rowHeight, for the pet rows.
local function cellsHeight(style, count, rowHeight)
    return count * (rowHeight or style.rowHeight) + (count - 1) * style.rowSpacing
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

-- The anchor's size for count groups (default all), groupsPerRow to a row.
local function gridSize(style, count)
    count = count or NUM_GROUPS
    local columnStep, rowStep = slotSteps(style)
    local columns = math.min(style.groupsPerRow, count)
    local rows = math.ceil(count / style.groupsPerRow)
    local bg = style.background
    return -style.cursor.pos[1] + (columns - 1) * columnStep + bg.pos[1] + bg.width,
        rows * rowStep - style.groupSpacing[2]
end

-- A block's first cell from its anchor's top-left, and the anchor's size for rows cells.
local function blockOffset(style, labelSpec)
    return -style.cursor.pos[1], -labelSpec.pos[2]
end

local function blockSize(style, bgSpec, labelSpec, rows)
    return -style.cursor.pos[1] + bgSpec.pos[1] + bgSpec.width,
        -labelSpec.pos[2] + cellsHeight(style, rows) + bgSpec.bottom.height
end

-- A block's background and label, on parent's top-left (the first cell's). Returns both.
local function createChrome(parent, label, bgSpec, labelSpec, fonts)
    local bg = EUI.PartyList.CreateBackground(parent, bgSpec)
    local header = Style.Header(bg, labelSpec, fonts)
    header.label:SetText(label)
    header:SetShown(not labelSpec.hidden)
    return bg, header
end

local function sizeChrome(bg, count, style, rowHeight)
    bg:SetShown(count > 0)
    if count > 0 then
        bg.mid:SetHeight(cellsHeight(style, count, rowHeight))
    end
end

-- Shared with the pets block (elements/raidPets.lua).
RaidList.CreateChrome = createChrome
RaidList.SizeChrome = sizeChrome
-- Distance between group columns.
function RaidList.ColumnStep(style)
    return (slotSteps(style))
end

local slotOrder

-- Moves the group headers into slots by occupancy; waits for combat to end.
local function layoutGroups()
    EUI.RunOutOfCombat(function()
        local order = {}
        -- A group the raid manager filters out counts as empty.
        local function occupied(group)
            return group.count > 0 and not group.filtered
        end
        for g, group in ipairs(groups) do
            if occupied(group) then
                order[#order + 1] = g
            end
        end
        for g, group in ipairs(groups) do
            if not occupied(group) then
                order[#order + 1] = g
            end
        end
        local key = table.concat(order, ',')
        if key == slotOrder then
            return
        end
        slotOrder = key
        EUI.LogOnce('raid:layout', 'raid: groups laid out in order %s', key)
        for slot, g in ipairs(order) do
            local x, y = slotOffset(RaidList.style, slot)
            local header = groups[g].header
            header:ClearAllPoints()
            header:SetPoint('TOPLEFT', RaidList.anchor, 'TOPLEFT', x, -y)
        end
    end, 'raidLayout')
end

local function updateGroup(group)
    local count = 0
    for _, cell in ipairs(group.cells) do
        if cell.button:IsShown() then
            count = count + 1
        end
    end
    group.count = count
    sizeChrome(group.bg, count, RaidList.style)
    if group.slotted and #groups == NUM_GROUPS then
        layoutGroups()
    end
end

local CELL_HOOKS = {
    unitChanged = function(cell, previous, unit)
        if previous and cellsByUnit[previous] then
            cellsByUnit[previous][cell] = nil
        end
        if unit then
            cellsByUnit[unit] = cellsByUnit[unit] or {}
            cellsByUnit[unit][cell] = true
        end
    end,
    readyCheckPhase = function()
        return EUI.PartyList.ReadyCheckPhase()
    end,
}

-- Click-casting addons (Clique and others) bind every frame in ClickCastFrames.
local function registerClickCast(button)
    ClickCastFrames = ClickCastFrames or {}
    ClickCastFrames[button] = true
end

-- A flagged member's target or that unit's target: a name line and HP bar, with no HP value;
-- the value slot shows only Dead. A hand cursor replaces the attention arrow while the unit is
-- your target. These units fire no events; the main ticker refreshes them through UpdateTargets.
local TargetCell = {}
TargetCell.__index = TargetCell

local function buildTargetArt(self, host, spec, fonts)
    -- Art lives on a child frame so a secure host keeps all mouse input.
    local art = CreateFrame('Frame', nil, host)
    art:SetAllPoints(host)
    art:EnableMouse(false)
    self.art = art
    self.hover = Style.Image(art, 'BACKGROUND', spec.hover, 1)
    self.hover:Hide()
    self.attention = Style.Image(art, 'ARTWORK', spec.attention)
    self.hp = EUI.Bar.Create(art, spec.hp.bar, spec.hp.pos)
    self.hpText = Style.Text(self.hp.overlay, spec.hp.txtValue, fonts)
    local top = CreateFrame('Frame', nil, art)
    top:SetAllPoints(art)
    top:SetFrameLevel(self.hp.overlay:GetFrameLevel() + 1)
    self.top = top
    self.name = Style.Text(top, spec.txtName, fonts)
    self.name:SetWordWrap(false)
    self.marker = top:CreateTexture(nil, 'OVERLAY')
    self.marker:SetSize(spec.raidMarker.size[1], spec.raidMarker.size[2])
    Style.Place(self.marker, top, spec.raidMarker.pos)
    self.marker:Hide()
    self.cursor = Style.Image(top, 'OVERLAY', spec.cursor)
    self.cursor:Hide()
end

local function setTargeted(self, targeted)
    self.cursor:SetShown(targeted)
    self.attention:SetShown(not targeted)
end

-- name: plain or secret. colorKey: a reaction key. marker: a raid marker index or nil.
function TargetCell:SetIdentity(name, colorKey, marker)
    local spec = self.spec
    pcall(self.name.SetText, self.name, name)
    self.name:SetTextColor(Style.Color(spec.nameColor or spec.reactionColors[colorKey] or spec.txtName.color))
    EUI.Indicators.SetRaidMarkerIcon(self.marker, marker)
    local shift = EUI.UnitVisual.NameLineShift(self.top, self.marker, spec.raidMarker)
    self.name:ClearAllPoints()
    self.name:SetPoint('TOPLEFT', self.top, 'TOPLEFT', spec.txtName.pos[1] + shift, -spec.txtName.pos[2])
    self.name:SetWidth(spec.txtName.width - shift)
end

-- state: a UnitInfo.STATE_LABELS key, or nil to clear.
function TargetCell:SetStateText(state)
    self.hpText:SetText(state and EUI.UnitInfo.STATE_LABELS[state] or '')
end

function TargetCell:Unit()
    local unit = self.owner.unit
    return unit and unit .. self.suffix
end

function TargetCell:Refresh()
    local unit = self:Unit()
    if not unit or not UnitExists(unit) then
        return
    end
    EUI.LogOnce('raid:assistTarget', 'raid: Assists target cell showing %s', unit)
    self:SetIdentity(EUI.UnitDisplayName(unit), (EUI.UnitInfo.ReactionKey(unit)), EUI.Indicators.ReadRaidMarker(unit))
    -- Eases only while the same unit stays behind the token.
    local guid = EUI.SafeValue(UnitGUID, unit)
    self.hp:SetRange(UnitHealthMax(unit))
    self.hp:SetValue(UnitHealth(unit), guid ~= nil and guid == self.guid)
    self.guid = guid
    self:SetStateText(EUI.UnitInfo.DeadState(unit))
    setTargeted(self, EUI.UnitVisual.IsTarget(unit))
    EUI.UnitVisual.ShowRange(self.art, unit, RaidList.style.range.farAlpha, true)
end

-- data = { name, colorKey, hpPercent, raidMarker, state, targeted, far }
function TargetCell:ShowDemo(data)
    self.host:SetShown(data ~= nil)
    if not data then
        return
    end
    self:SetIdentity(data.name, data.colorKey, data.raidMarker)
    setTargeted(self, data.targeted == true)
    self.art:SetAlpha(data.far and RaidList.style.range.farAlpha or 1)
    self.hp:SetRange(100)
    self.hp:SetValue(data.state and 0 or data.hpPercent)
    self:SetStateText(data.state)
end

-- The n-th target cell's left edge, from its owner cell's.
local function targetX(n)
    return RaidList.style.assists.target.x[n]
end

-- Secure button on the owner's button: useparent-unit plus unitsuffix make it click, and its
-- unit watch show it, for the owner's current unit + suffix, in combat too.
local function createTargetCell(owner, n, suffix)
    local style = RaidList.style
    local spec = style.assists.target
    local button = CreateFrame('Button', nil, owner.button, 'SecureUnitButtonTemplate')
    button:SetSize(spec.width, style.rowHeight)
    button:SetPoint('TOPLEFT', owner.button, 'TOPLEFT', targetX(n), 0)
    button:SetAttribute('useparent-unit', true)
    button:SetAttribute('unitsuffix', suffix)
    button:SetAttribute('type1', 'target')
    button:SetAttribute('type2', 'togglemenu')
    button:RegisterForClicks('AnyUp')
    registerClickCast(button)
    if RegisterUnitWatch then
        RegisterUnitWatch(button)
    end
    local self = setmetatable({ button = button, owner = owner, suffix = suffix, spec = spec }, TargetCell)
    buildTargetArt(self, button, spec, RaidList.fonts)
    button:HookScript('OnEnter', function()
        self.hover:Show()
    end)
    button:HookScript('OnLeave', function()
        self.hover:Hide()
    end)
    EUI.AttachUnitTooltip(button, function() return self:Unit() end)
    button:HookScript('OnShow', function()
        self:Refresh()
    end)
    targetCells[#targetCells + 1] = self
    return self
end

local function createDemoTargetCell(owner, n)
    local spec = RaidList.style.assists.target
    local host = CreateFrame('Frame', nil, owner.host)
    host:SetSize(spec.width, RaidList.style.rowHeight)
    host:SetPoint('TOPLEFT', owner.host, 'TOPLEFT', targetX(n), 0)
    local self = setmetatable({ host = host, spec = spec }, TargetCell)
    buildTargetArt(self, host, spec, RaidList.fonts)
    return self
end

local function attachCell(group, button, withTargets)
    local style = RaidList.style
    button:SetSize(style.width, style.rowHeight)
    button:RegisterForClicks('AnyUp')
    registerClickCast(button)
    local cell = EUI.PartyRow.Attach(button, style, RaidList.fonts, CELL_HOOKS)
    if withTargets then
        createTargetCell(cell, 1, 'target')
        createTargetCell(cell, 2, 'targettarget')
    end
    group.cells[#group.cells + 1] = cell
    cells[#cells + 1] = cell
    button:HookScript('OnShow', function()
        updateGroup(group)
    end)
    button:HookScript('OnHide', function()
        updateGroup(group)
    end)
end

-- def = { name, parent, anchor, x, y, attributes, size, label, background, labelSpec, targets }
local function createBlock(def)
    local style = RaidList.style
    local header = CreateFrame('Frame', def.name, def.parent, 'SecureGroupHeaderTemplate')
    -- Hidden while configured, so each attribute does not relayout the header.
    header:Hide()
    header:SetPoint('TOPLEFT', def.anchor, 'TOPLEFT', def.x, -def.y)
    header:SetAttribute('template', 'EorzeaUIRaidButtonTemplate')
    header:SetAttribute('templateType', 'Button')
    header:SetAttribute('showRaid', true)
    header:SetAttribute('sortMethod', 'INDEX')
    header:SetAttribute('point', 'TOP')
    header:SetAttribute('yOffset', -style.rowSpacing)
    header:SetAttribute('unitsPerColumn', def.size)
    header:SetAttribute('maxColumns', 1)
    for name, value in pairs(def.attributes) do
        header:SetAttribute(name, value)
    end

    local group = { header = header, cells = {} }
    group.bg = createChrome(header, def.label, def.background, def.labelSpec, RaidList.fonts)

    -- A negative startingIndex makes the header build every button now, out of combat; the
    -- header keeps them as header[1..n].
    header:Show()
    header:SetAttribute('startingIndex', 1 - def.size)
    header:SetAttribute('startingIndex', 1)
    for i = 1, def.size do
        local button = header[i]
        if button then
            attachCell(group, button, def.targets)
        else
            EUI.LogOnce('raid:button:' .. def.name, '%s built %d of %d buttons', def.name, i - 1, def.size)
            break
        end
    end
    if RegisterStateDriver then
        RegisterStateDriver(header, 'visibility', VISIBILITY)
    end
    updateGroup(group)
    return group
end

local function createAssists()
    local style = RaidList.style
    local spec = style.assists
    local anchor = CreateFrame('Frame', 'EorzeaUIAssistsAnchor', UIParent)
    anchor:SetSize(blockSize(style, spec.background, spec.groupNumber, spec.max))
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    RaidList.assistsAnchor = anchor
    local headersFrame = CreateFrame('Frame', nil, anchor)
    headersFrame:SetAllPoints(anchor)
    headersFrame:SetFrameLevel(anchor:GetFrameLevel() + 2)
    RaidList.assistsFrame = headersFrame
    local x, y = blockOffset(style, spec.groupNumber)
    RaidList.assistsBlock = createBlock({
        name = 'EorzeaUIRaidAssists', parent = headersFrame, anchor = anchor, x = x, y = y,
        size = spec.max, label = spec.label, background = spec.background, labelSpec = spec.groupNumber,
        targets = true,
        attributes = {
            roleFilter = 'MAINTANK,MAINASSIST',
            groupBy = 'ROLE',
            groupingOrder = 'MAINTANK,MAINASSIST',
        },
    })
end

-- Edit Mode handle (EditMode.Register's box) for the groups and Assists anchors: their left edge
-- moves in from the cursor's overhang to the role badge or class icon, whichever is further left.
function RaidList.EditBox()
    local style = RaidList.style
    local left = math.min(style.classIcon.pos[1], style.indicators.role.pos[1])
    return { left = -(-style.cursor.pos[1] + left) }
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
        local x, y = slotOffset(raidStyle, g)
        groups[g] = createBlock({
            name = 'EorzeaUIRaidGroup' .. g, parent = groupsFrame, anchor = anchor, x = x, y = y,
            size = GROUP_SIZE, label = string.format(GROUP_NUMBER or 'Group %d', g),
            background = raidStyle.background, labelSpec = raidStyle.groupNumber,
            attributes = { groupFilter = tostring(g) },
        })
        groups[g].slotted = true
    end
    layoutGroups()
    createAssists()
    EUI.Log('raid: built %d cells, %d Assists target cells', #cells, #targetCells)
end

-- Raid sizes with their own layout (settings raid.layouts.<size>), Blizzard's Edit Mode raid
-- preview sizes (2, 5 and 8 groups). A raid uses the smallest that holds its members; the demo
-- shows raid.previewSize.
RaidList.SIZES = { 10, 25, 40 }

function RaidList.LayoutSize()
    if EUI.Demo.IsShowing('raid') then
        return EUI.Settings.Get('raid.previewSize')
    end
    local members = EUI.Read('GetNumGroupMembers', GetNumGroupMembers) or 0
    for _, size in ipairs(RaidList.SIZES) do
        if members <= size then
            return size
        end
    end
    return RaidList.SIZES[#RaidList.SIZES]
end

-- Groups a raid of size holds (2, 5 or 8); size defaults to the raid size in use.
function RaidList.GroupCount(size)
    return (size or RaidList.LayoutSize()) / GROUP_SIZE
end

local function layoutSetting(key)
    return EUI.Settings.Get(string.format('raid.layouts.%d.%s', RaidList.LayoutSize(), key))
end

-- The current size's scale, times the raid frame's own.
function RaidList.SizeScale()
    return layoutSetting('scale') or 1
end

local appliedGroupCount

-- Lays the groups out for the current raid size and sizes the anchor (and so its Edit Mode box)
-- to the groups that size holds; waits for combat to end.
function RaidList.ApplyLayoutSize()
    EUI.RunOutOfCombat(function()
        local style = RaidList.style
        local count = RaidList.GroupCount()
        local perRow = math.min(layoutSetting('groupsPerRow') or style.groupsPerRow, count)
        if perRow ~= style.groupsPerRow or count ~= appliedGroupCount then
            style.groupsPerRow = perRow
            appliedGroupCount = count
            EUI.EditMode.ResizeKeepingTopLeft('raid', RaidList.anchor, gridSize(style, count))
            slotOrder = nil
            layoutGroups()
            for g, block in ipairs(RaidList.demoGroups or {}) do
                local x, y = slotOffset(style, g)
                block.slot:ClearAllPoints()
                block.slot:SetPoint('TOPLEFT', RaidList.anchor, 'TOPLEFT', x, -y)
            end
        end
        EUI.RaidPets.ApplyLayoutSize()
        -- During setup the scale is applied once every frame exists.
        if EUI.ready then
            EUI.ApplyScale()
        end
    end, 'raidLayoutSize')
end

local ROLES = { 'TANK', 'HEALER', 'DAMAGER', 'NONE' }
local appliedFilters

-- Follows Blizzard's raid manager: its group and role filters and its Hide button. Reads its
-- state through CRF_GetFilterGroup / CRF_GetFilterRole / CompactRaidFrameManager_GetSetting and
-- sets our own headers only. Headers are protected, so this runs out of combat.
function RaidList.ApplyManagerFilters()
    if not (CRF_GetFilterGroup and CRF_GetFilterRole and CompactRaidFrameManager_GetSetting) then
        EUI.LogOnce('raid:managerFilters', 'raid manager filters unavailable')
        return
    end
    EUI.RunOutOfCombat(function()
        local isShown = EUI.SafeValue(CompactRaidFrameManager_GetSetting, 'IsShown')
        local shown = isShown ~= false and isShown ~= '0'
        local roles = {}
        for _, role in ipairs(ROLES) do
            if EUI.SafeValue(CRF_GetFilterRole, role) ~= false then
                roles[#roles + 1] = role
            end
        end
        local groupShown = {}
        for g = 1, NUM_GROUPS do
            groupShown[g] = shown and EUI.SafeValue(CRF_GetFilterGroup, g) ~= false
        end
        -- assists.show / pets.show (settings): true or false override the manager's Hide button.
        local assistsShown, petsShown = shown, shown
        if RaidList.style.assists.show ~= nil then
            assistsShown = RaidList.style.assists.show
        end
        if RaidList.style.pets.show ~= nil then
            petsShown = RaidList.style.pets.show
        end
        local key = string.format('%s|%s|%s|%s|', tostring(shown), tostring(assistsShown), tostring(petsShown),
            table.concat(roles, ','))
        for g = 1, NUM_GROUPS do
            key = key .. (groupShown[g] and '1' or '0')
        end
        if key == appliedFilters then
            return
        end
        appliedFilters = key
        -- With some roles filtered, strict filtering needs the group, any class and an allowed role.
        local allRoles = #roles == #ROLES
        if not allRoles and not CLASS_SORT_ORDER then
            EUI.LogOnce('raid:classOrder', 'CLASS_SORT_ORDER missing; raid role filters ignored')
            allRoles = true
        end
        local classes = table.concat(CLASS_SORT_ORDER or {}, ',')
        for g, group in ipairs(groups) do
            local header = group.header
            group.filtered = not groupShown[g]
            if allRoles then
                header:SetAttribute('strictFiltering', nil)
                header:SetAttribute('roleFilter', nil)
                header:SetAttribute('groupFilter', tostring(g))
            else
                header:SetAttribute('strictFiltering', true)
                header:SetAttribute('roleFilter', table.concat(roles, ','))
                header:SetAttribute('groupFilter', tostring(g) .. ',' .. classes)
            end
            if RegisterStateDriver then
                RegisterStateDriver(header, 'visibility', groupShown[g] and VISIBILITY or 'hide')
            end
        end
        if RegisterStateDriver then
            RegisterStateDriver(RaidList.assistsBlock.header, 'visibility', assistsShown and VISIBILITY or 'hide')
        end
        EUI.RaidPets.SetHidden(not petsShown)
        slotOrder = nil
        layoutGroups()
        EUI.LogOnce('raid:managerFiltersApplied', 'raid: following the raid manager (%s)', key)
    end, 'raidManagerFilters')
end

-- Calls fn on each shown cell for unit. Events for you arrive as 'player' and go to your cells;
-- events by their raidN token are dropped, so they update once.
function RaidList.ForEachCellForUnit(unit, fn)
    if unit == 'player' then
        for _, cell in ipairs(cells) do
            if cell.isSelf and cell.button:IsVisible() then
                fn(cell)
            end
        end
        return
    end
    local set = cellsByUnit[unit]
    if not set then
        return
    end
    for cell in pairs(set) do
        if cell.button:IsVisible() then
            if cell.isSelf then
                EUI.LogOnce('raid:selfToken', 'raid: events for you also arrive as %s', tostring(unit))
            else
                fn(cell)
            end
        end
    end
end

function RaidList.ForEachVisibleCell(fn)
    for _, cell in ipairs(cells) do
        if cell.button:IsVisible() and cell.unit then
            fn(cell)
        end
    end
end

-- Main tanks' and assists' targets and their targets.
function RaidList.UpdateTargets()
    for _, target in ipairs(targetCells) do
        if target.button:IsVisible() then
            target:Refresh()
        end
    end
end

function RaidList.RefreshAll()
    RaidList.ForEachVisibleCell(function(cell)
        cell:Refresh()
    end)
    RaidList.UpdateTargets()
    for _, group in ipairs(groups) do
        updateGroup(group)
    end
    updateGroup(RaidList.assistsBlock)
end

-- A roster change can put someone else behind a cell's token without changing it.
function RaidList.OnRosterChanged()
    if InCombatLockdown() and IsInRaid() then
        EUI.LogOnce('raid:combatRoster', 'raid: roster changed in combat')
    end
    RaidList.RefreshAll()
end

local function createDemoRows(slot, count, withTargets)
    local style = RaidList.style
    local rows = {}
    for i = 1, count do
        local row = EUI.PartyRow.CreateDemo(slot, style, RaidList.fonts)
        row.host:SetPoint('TOPLEFT', slot, 'TOPLEFT', 0, -(i - 1) * (style.rowHeight + style.rowSpacing))
        if withTargets then
            row.targets = { createDemoTargetCell(row, 1), createDemoTargetCell(row, 2) }
        end
        rows[i] = row
    end
    return rows
end

-- A demo block's slot frame on anchor at (x, y), its rows and chrome.
local function createDemoBlock(parent, anchor, x, y, count, label, bgSpec, labelSpec, withTargets)
    local slot = CreateFrame('Frame', nil, parent)
    slot:SetSize(RaidList.style.width, RaidList.style.rowHeight)
    slot:SetPoint('TOPLEFT', anchor, 'TOPLEFT', x, -y)
    return {
        slot = slot,
        rows = createDemoRows(slot, count, withTargets),
        bg = createChrome(slot, label, bgSpec, labelSpec, RaidList.fonts),
    }
end

local function showDemoBlock(block, list)
    list = list or {}
    for i, row in ipairs(block.rows) do
        local entry = list[i]
        row:ShowDemo(entry and (entry.member or entry))
        if row.targets then
            row.targets[1]:ShowDemo(entry and entry.target)
            row.targets[2]:ShowDemo(entry and entry.tot)
        end
    end
    sizeChrome(block.bg, math.min(#list, #block.rows), RaidList.style)
end

-- groups: one list of demo member tables per group (PartyRow ShowDemo); assists: a list of
-- { member, target, tot } (TargetCell ShowDemo for the last two). nil restores the live blocks.
-- The headers are protected, so this runs out of combat only.
function RaidList.SetDemo(groupMembers, assists)
    local style = RaidList.style
    if not RaidList.demoFrame then
        local frame = CreateFrame('Frame', nil, RaidList.anchor)
        frame:SetAllPoints(RaidList.anchor)
        frame:SetFrameLevel(RaidList.groupsFrame:GetFrameLevel() + 5)
        RaidList.demoFrame = frame
        RaidList.demoGroups = {}
        for g = 1, NUM_GROUPS do
            local x, y = slotOffset(style, g)
            RaidList.demoGroups[g] = createDemoBlock(frame, RaidList.anchor, x, y, GROUP_SIZE,
                string.format(GROUP_NUMBER or 'Group %d', g), style.background, style.groupNumber)
        end
        local spec = style.assists
        local assistsFrame = CreateFrame('Frame', nil, RaidList.assistsAnchor)
        assistsFrame:SetAllPoints(RaidList.assistsAnchor)
        assistsFrame:SetFrameLevel(RaidList.assistsFrame:GetFrameLevel() + 5)
        RaidList.demoAssistsFrame = assistsFrame
        local x, y = blockOffset(style, spec.groupNumber)
        RaidList.demoAssists = createDemoBlock(assistsFrame, RaidList.assistsAnchor, x, y, spec.max,
            spec.label, spec.background, spec.groupNumber, true)
    end
    local active = groupMembers ~= nil
    if active then
        for g, block in ipairs(RaidList.demoGroups) do
            showDemoBlock(block, groupMembers[g])
        end
        showDemoBlock(RaidList.demoAssists, assists)
    end
    RaidList.demoFrame:SetShown(active)
    RaidList.groupsFrame:SetShown(not active)
    RaidList.demoAssistsFrame:SetShown(active)
    RaidList.assistsFrame:SetShown(not active)
end
