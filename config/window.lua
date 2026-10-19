local _, EUI = ...

-- The settings window (/ffui config): pages from EUI.Config.PAGES (config/options.lua) in a
-- list on the left, the chosen page's controls in a scrolling column on the right. Options
-- marked reload are read when the frames are built; changing one shows the reload bar.

local Config = EUI.Config
local Widgets = EUI.Widgets
local Style = EUI.Style
local Settings = EUI.Settings
local C = Widgets.COLORS

local WIDTH, HEIGHT = 780, 580
local NAV_WIDTH = 168
local CONTENT_WIDTH = WIDTH - NAV_WIDTH - 52
local FONTS = { name = 'Fonts\\FRIZQT__.TTF', header = 'Fonts\\FRIZQT__.TTF' }

local window
local pages = {}
local navButtons = {}
local currentPage

-- Values of reload options when the frames were built, by path.
local builtValues = {}

local function same(a, b)
    if type(a) ~= 'table' or type(b) ~= 'table' then
        return a == b
    end
    for key, value in pairs(a) do
        if not same(value, b[key]) then
            return false
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end
    return true
end

-- Called once the frames are built, so later changes to reload options count as pending.
function Config.SnapshotBuilt()
    for _, path in ipairs(Config.ReloadPaths()) do
        builtValues[path] = Settings.Copy(Settings.Get(path))
    end
end

-- Labels of reload options changed since the frames were built.
local function pendingLabels()
    local labels = {}
    for _, path in ipairs(Config.ReloadPaths()) do
        if not same(builtValues[path], Settings.Get(path)) then
            labels[#labels + 1] = Config.ReloadLabel(path)
        end
    end
    return labels
end

local MAX_NAMED = 3

-- 'Reload to apply: Palette, Fonts', or the first MAX_NAMED and a count of the rest.
local function summarize(prefix, labels)
    if #labels <= MAX_NAMED then
        return prefix .. table.concat(labels, ', ')
    end
    local named = {}
    for i = 1, MAX_NAMED do
        named[i] = labels[i]
    end
    return string.format('%s%s and %d more', prefix, table.concat(named, ', '), #labels - MAX_NAMED)
end

-- Labels of options changed in combat that wait for it to end, in change order.
local combatLabels = {}

-- The footer: reload options changed since the frames were built (gold, with the Reload
-- button) over options waiting for combat to end (red).
local function updateReloadBar()
    if not window then
        return
    end
    local labels = pendingLabels()
    window.reloadLabels = labels
    window.combatLabels = combatLabels
    local reload, combat = #labels > 0, #combatLabels > 0
    window.reloadText:SetText(reload and summarize('Reload to apply: ', labels) or '')
    window.combatText:SetText(combat and summarize('Applies after combat: ', combatLabels) or '')
    window.reloadButton:SetShown(reload)
    window.reloadText:SetPoint('RIGHT', window.reloadBar, 'RIGHT', -110, combat and 7 or 0)
    window.combatText:SetPoint('RIGHT', window.reloadBar, 'RIGHT', reload and -110 or 0, reload and -7 or 0)
    window.reloadBar:SetShown(reload or combat)
    -- Every change passes here; the section resets follow it.
    local built = currentPage and pages[currentPage]
    for _, control in ipairs(built and built.controls or {}) do
        if control.isSectionHeader then
            control:Refresh()
        end
    end
end
Config.UpdateReloadBar = updateReloadBar

-- A combat option changed in combat (config/options.lua); listed until combat ends.
function Config.NoteCombatChange(label)
    for _, existing in ipairs(combatLabels) do
        if existing == label then
            return
        end
    end
    combatLabels[#combatLabels + 1] = label
    updateReloadBar()
end

-- After the jobs waiting for combat have run.
function Config.OnCombatEnded()
    if #combatLabels > 0 then
        combatLabels = {}
        updateReloadBar()
    end
end

-- Controls for one registry item; item fields as documented in config/options.lua.
local function bind(item)
    local spec = {
        label = item.label,
        tip = item.tip,
        choices = item.choices,
        stacked = item.stacked,
        preview = item.preview,
        min = item.min, max = item.max, step = item.step, format = item.format, lead = item.lead, range = item.range,
        alpha = item.alpha,
    }
    if item.path then
        spec.get = function()
            local value = Settings.Get(item.path)
            if item.invert then
                return not value
            end
            return value
        end
        spec.set = function(value)
            if item.invert then
                value = not value
            end
            Settings.Set(item.path, value)
            updateReloadBar()
        end
    end
    if item.get then
        spec.get = item.get
    end
    if item.set then
        spec.set = function(value)
            item.set(value)
            updateReloadBar()
        end
    end
    spec.isDefault, spec.reset = item.isDefault, item.reset
    if spec.reset then
        local reset = spec.reset
        spec.reset = function()
            reset()
            updateReloadBar()
        end
    end
    return spec
end

-- The saved path an item edits: item.path, or item.pathFn() for items bound through get/set.
-- nil for items a section reset skips (noReset, or no saved value).
local function itemPath(item)
    if item.noReset then
        return nil
    end
    return item.path or (item.pathFn and item.pathFn())
end

local function itemIsDefault(item)
    if item.isDefault then
        return item.isDefault()
    end
    local path = itemPath(item)
    return not path or same(Settings.Get(path), Settings.Default(path))
end

-- A section's reset for the header: the items up to the next header.
local function sectionReset(items)
    local resettable = {}
    for _, item in ipairs(items) do
        if (item.isDefault and item.reset) or itemPath(item) then
            resettable[#resettable + 1] = item
        end
    end
    if #resettable == 0 then
        return nil
    end
    return {
        isDefault = function()
            for _, item in ipairs(resettable) do
                if not itemIsDefault(item) then
                    return false
                end
            end
            return true
        end,
        reset = function()
            for _, item in ipairs(resettable) do
                if not itemIsDefault(item) then
                    if item.reset then
                        item.reset()
                    else
                        Settings.Reset(itemPath(item))
                    end
                end
            end
            Config.Refresh()
        end,
    }
end

local BUILDERS = {
    header = function(parent, item, section)
        return Widgets.Header(parent, CONTENT_WIDTH, item.label, FONTS, sectionReset(section or {}))
    end,
    note = function(parent, item) return Widgets.Note(parent, CONTENT_WIDTH, item.text, item.color, item.shown) end,
    toggle = function(parent, item) return Widgets.Toggle(parent, CONTENT_WIDTH, bind(item)) end,
    choice = function(parent, item) return Widgets.Choice(parent, CONTENT_WIDTH, bind(item)) end,
    slider = function(parent, item) return Widgets.Slider(parent, CONTENT_WIDTH, bind(item)) end,
    color = function(parent, item) return Widgets.Color(parent, CONTENT_WIDTH, bind(item)) end,
    buttons = function(parent, item)
        local holder = CreateFrame('Frame', nil, parent)
        holder:SetSize(CONTENT_WIDTH, Widgets.ROW_HEIGHT + 4)
        local x = 4
        for _, def in ipairs(item.buttons) do
            local button = Widgets.Button(holder, def.label, function(self)
                def.run(self)
                updateReloadBar()
            end)
            button:SetPoint('LEFT', x, 0)
            if def.tip then
                Widgets.SetTooltip(button, def.label, def.tip)
            end
            if def.labelFn then
                button.labelFn = def.labelFn
            end
            x = x + button:GetWidth() + 8
        end
        function holder:Refresh()
            for _, child in ipairs({ self:GetChildren() }) do
                if child.labelFn then
                    child:SetLabel(child.labelFn())
                end
            end
        end
        holder:Refresh()
        return holder
    end,
}

local function buildPage(page)
    local child = CreateFrame('Frame', nil, window.scroll)
    child:SetWidth(CONTENT_WIDTH)
    local controls = {}
    local y = 0
    local items = page.items
    if type(items) == 'function' then
        items = items()
    end
    for i, item in ipairs(items) do
        local build = BUILDERS[item.kind]
        local section
        if item.kind == 'header' then
            section = {}
            for j = i + 1, #items do
                if items[j].kind == 'header' then
                    break
                end
                section[#section + 1] = items[j]
            end
        end
        if build then
            local control = build(child, item, section)
            control.isSectionHeader = item.kind == 'header'
            if item.kind == 'header' and y > 0 then
                y = y + 8
            end
            control:SetPoint('TOPLEFT', 0, -y)
            y = y + control:GetHeight()
            controls[#controls + 1] = control
        else
            EUI.LogOnce('config:kind:' .. tostring(item.kind), 'config: unknown item kind %s', tostring(item.kind))
        end
    end
    child:SetHeight(y + 12)
    child:Hide()
    return { frame = child, controls = controls, height = y + 12 }
end

local function updateScrollIndicator()
    local scroll = window.scroll
    local range = scroll:GetVerticalScrollRange()
    local bar = window.scrollBar
    if range <= 0 then
        bar:Hide()
        return
    end
    local visible = scroll:GetHeight()
    local total = visible + range
    local height = math.max(24, visible * visible / total)
    bar:SetHeight(height)
    bar:ClearAllPoints()
    bar:SetPoint('TOPRIGHT', scroll, 'TOPRIGHT', 10, -(visible - height) * scroll:GetVerticalScroll() / range)
    bar:Show()
end

local function showPage(key)
    for _, page in ipairs(Config.PAGES) do
        local built = pages[page.key]
        if page.key == key then
            if not built then
                built = buildPage(page)
                pages[page.key] = built
            end
            window.scroll:SetScrollChild(built.frame)
            built.frame:Show()
            for _, control in ipairs(built.controls) do
                control:Refresh()
            end
        elseif built then
            built.frame:Hide()
        end
    end
    for pageKey, button in pairs(navButtons) do
        local on = pageKey == key
        button.text:SetTextColor(Style.Color(on and C.selected or C.dim))
        button.lit:SetShown(on)
        button.cursor:SetShown(on)
    end
    currentPage = key
    for _, page in ipairs(Config.PAGES) do
        if page.key == key then
            EUI.Demo.SetPageSections(page.demo)
        end
    end
    window.scroll:SetVerticalScroll(0)
    updateScrollIndicator()
end

-- Rebuilds pages whose items depend on settings (the colour page follows the palette).
function Config.RebuildPage(key)
    local built = pages[key]
    if built then
        built.frame:Hide()
        pages[key] = nil
    end
    if window and window:IsShown() and currentPage == key then
        showPage(key)
    end
end

local function createWindow()
    window = CreateFrame('Frame', 'EorzeaUIConfig', UIParent)
    window:SetSize(WIDTH, HEIGHT)
    window:SetPoint('CENTER')
    -- Blizzard's Settings panel's strata, under the colour picker (DIALOG).
    window:SetFrameStrata('HIGH')
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag('LeftButton')
    window:SetScript('OnDragStart', window.StartMoving)
    window:SetScript('OnDragStop', window.StopMovingOrSizing)
    window:Hide()
    if UISpecialFrames then
        table.insert(UISpecialFrames, 'EorzeaUIConfig')
    end

    -- FFXI menu window: deep blue fading to black, a thin silver edge.
    local bg = window:CreateTexture(nil, 'BACKGROUND')
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 1)
    if not pcall(bg.SetGradient, bg, 'VERTICAL', CreateColor(0.02, 0.03, 0.06, 0.94), CreateColor(0.07, 0.10, 0.19, 0.94)) then
        bg:SetVertexColor(0.04, 0.06, 0.12, 0.94)
    end
    for _, edge in ipairs({
        { 'TOPLEFT', 'TOPRIGHT', true }, { 'BOTTOMLEFT', 'BOTTOMRIGHT', true },
        { 'TOPLEFT', 'BOTTOMLEFT', false }, { 'TOPRIGHT', 'BOTTOMRIGHT', false },
    }) do
        local line = Widgets.Solid(window, 'BORDER', '#A6BCE366')
        line:SetPoint(edge[1])
        line:SetPoint(edge[2])
        if edge[3] then
            line:SetHeight(1)
        else
            line:SetWidth(1)
        end
    end

    local title = Widgets.Text(window, 18, C.accent)
    title:SetPoint('TOPLEFT', 18, -14)
    title:SetText('EorzeaUI')
    local subtitle = Widgets.Text(window, 11, C.dim)
    subtitle:SetPoint('LEFT', title, 'RIGHT', 10, -1)
    subtitle:SetText('Settings')

    local close = CreateFrame('Button', nil, window)
    close:SetSize(26, 26)
    close:SetPoint('TOPRIGHT', -8, -8)
    close.text = Widgets.Text(close, 18, C.dim)
    close.text:SetPoint('CENTER')
    close.text:SetText('x')
    close:SetScript('OnEnter', function(self) self.text:SetTextColor(1, 1, 1, 1) end)
    close:SetScript('OnLeave', function(self) self.text:SetTextColor(Style.Color(C.dim)) end)
    close:SetScript('OnClick', function() window:Hide() end)
    Widgets.SetTooltip(close, 'Close', 'Escape also closes the window.')

    local divider = Widgets.Solid(window, 'BORDER', '#A6BCE333')
    divider:SetWidth(1)
    divider:SetPoint('TOPLEFT', NAV_WIDTH + 12, -50)
    divider:SetPoint('BOTTOMLEFT', NAV_WIDTH + 12, 54)

    -- Page list. The chosen page has the hover bar and the FFXI hand cursor pointing at it.
    local y = -56
    for _, page in ipairs(Config.PAGES) do
        local button = CreateFrame('Button', nil, window)
        button:SetSize(NAV_WIDTH - 24, 26)
        button:SetPoint('TOPLEFT', 30, y)
        button.text = Widgets.Text(button, 13)
        button.text:SetPoint('LEFT', 10, 0)
        button.text:SetText(page.label)
        button.lit = button:CreateTexture(nil, 'BACKGROUND')
        button.lit:SetTexture(Style.AssetPath('hud/Hover'))
        button.lit:SetVertexColor(Style.Color(C.hover))
        button.lit:SetAllPoints()
        button.lit:Hide()
        button.cursor = button:CreateTexture(nil, 'OVERLAY')
        button.cursor:SetTexture(Style.AssetPath('hud/Cursor'))
        button.cursor:SetSize(30, 19)
        button.cursor:SetPoint('RIGHT', button, 'LEFT', 4, 0)
        button.cursor:Hide()
        Widgets.AddHover(button)
        button:SetScript('OnClick', function() showPage(page.key) end)
        Widgets.SetTooltip(button, page.label, page.tip)
        navButtons[page.key] = button
        y = y - 28
    end

    local scroll = CreateFrame('ScrollFrame', nil, window)
    scroll:SetPoint('TOPLEFT', NAV_WIDTH + 28, -52)
    scroll:SetPoint('BOTTOMRIGHT', -24, 56)
    scroll:EnableMouseWheel(true)
    scroll:SetScript('OnMouseWheel', function(self, delta)
        local range = self:GetVerticalScrollRange()
        local next = math.max(0, math.min(range, self:GetVerticalScroll() - delta * 48))
        self:SetVerticalScroll(next)
        updateScrollIndicator()
    end)
    scroll:SetScript('OnScrollRangeChanged', function() updateScrollIndicator() end)
    window.scroll = scroll
    window.scrollBar = Widgets.Solid(window, 'ARTWORK', '#A6BCE366')
    window.scrollBar:SetWidth(3)
    window.scrollBar:Hide()

    -- Footer: the reload bar.
    local footerLine = Widgets.Solid(window, 'BORDER', '#A6BCE333')
    footerLine:SetHeight(1)
    footerLine:SetPoint('BOTTOMLEFT', 12, 48)
    footerLine:SetPoint('BOTTOMRIGHT', -12, 48)

    local reloadBar = CreateFrame('Frame', nil, window)
    reloadBar:SetPoint('BOTTOMLEFT', 12, 12)
    reloadBar:SetPoint('BOTTOMRIGHT', -12, 12)
    reloadBar:SetHeight(28)
    window.reloadText = Widgets.Text(reloadBar, 12, '#FFD966FF')
    window.reloadText:SetPoint('RIGHT', reloadBar, 'RIGHT', -110, 0)
    window.combatText = Widgets.Text(reloadBar, 12, '#FF5050FF')
    window.combatText:SetPoint('RIGHT', reloadBar, 'RIGHT', -110, 0)
    local reload = Widgets.Button(reloadBar, 'Reload UI', function()
        if InCombatLockdown() then
            EUI.Print('reload after combat')
            return
        end
        ReloadUI()
    end, 96)
    reload:SetPoint('RIGHT', 0, 0)
    Widgets.SetTooltip(reload, 'Reload UI', 'Reloads the interface so the changes listed here take effect.')
    window.reloadButton = reload
    -- The full lists while hovering the summaries.
    local summary = CreateFrame('Frame', nil, reloadBar)
    summary:SetPoint('TOPLEFT', reloadBar, 'TOPLEFT', 0, 0)
    summary:SetPoint('BOTTOMRIGHT', reloadBar, 'BOTTOMRIGHT', -110, 0)
    summary:EnableMouse(true)
    summary:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_TOP')
        local reloadLabels, waiting = window.reloadLabels or {}, window.combatLabels or {}
        if #reloadLabels > 0 then
            GameTooltip:AddLine('Applies after a reload', 1, 1, 1)
            for _, label in ipairs(reloadLabels) do
                GameTooltip:AddLine(label)
            end
        end
        if #waiting > 0 then
            GameTooltip:AddLine('Applies once combat ends', 1, 0.31, 0.31)
            for _, label in ipairs(waiting) do
                GameTooltip:AddLine(label)
            end
        end
        GameTooltip:Show()
    end)
    summary:SetScript('OnLeave', function() GameTooltip:Hide() end)
    reloadBar:Hide()
    window.reloadBar = reloadBar

    local hint = Widgets.Text(window, 11, C.dim)
    hint:SetPoint('BOTTOMLEFT', 20, 22)
    hint:SetText('/ffui config')

    -- Bottom of the page list: every frame's demo at once.
    local function demoLabel()
        return EUI.Demo.toggled and 'Demo all: on' or 'Demo all: off'
    end
    local demo = Widgets.Button(window, demoLabel(), function(self)
        EUI.Demo.Toggle()
        self:SetLabel(demoLabel())
    end, NAV_WIDTH - 24)
    demo:SetPoint('BOTTOMLEFT', 30, 60)
    Widgets.SetTooltip(demo, 'Demo all', 'Fill every frame with sample data, whichever page is open (/ffui demo). Each page shows its own frames anyway.')
    window.demoButton = demo
    window.demoLabel = demoLabel

    window:SetScript('OnShow', function()
        Config.HideLockPrompt()
        showPage(currentPage or Config.PAGES[1].key)
        window.demoButton:SetLabel(window.demoLabel())
        updateReloadBar()
    end)
    window:SetScript('OnHide', function()
        EUI.Demo.SetPageSections(nil)
        Config.ShowLockPrompt()
    end)
end

local lockPrompt

local function createLockPrompt()
    local frame = CreateFrame('Frame', 'EorzeaUILockPrompt', UIParent)
    frame:SetSize(330, 70)
    frame:SetPoint('TOP', 0, -120)
    frame:SetFrameStrata('DIALOG')
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag('LeftButton')
    frame:SetScript('OnDragStart', frame.StartMoving)
    frame:SetScript('OnDragStop', frame.StopMovingOrSizing)
    frame:Hide()
    local bg = frame:CreateTexture(nil, 'BACKGROUND')
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 1)
    if not pcall(bg.SetGradient, bg, 'VERTICAL', CreateColor(0.02, 0.03, 0.06, 0.94), CreateColor(0.07, 0.10, 0.19, 0.94)) then
        bg:SetVertexColor(0.04, 0.06, 0.12, 0.94)
    end
    for _, edge in ipairs({
        { 'TOPLEFT', 'TOPRIGHT', true }, { 'BOTTOMLEFT', 'BOTTOMRIGHT', true },
        { 'TOPLEFT', 'BOTTOMLEFT', false }, { 'TOPRIGHT', 'BOTTOMRIGHT', false },
    }) do
        local line = Widgets.Solid(frame, 'BORDER', '#A6BCE366')
        line:SetPoint(edge[1])
        line:SetPoint(edge[2])
        if edge[3] then
            line:SetHeight(1)
        else
            line:SetWidth(1)
        end
    end
    local note = Widgets.Text(frame, 12, C.text)
    note:SetPoint('TOP', 0, -12)
    note:SetText('EorzeaUI frames are unlocked: drag them to move.')
    local lock = Widgets.Button(frame, 'Lock frames', function()
        EUI.EditMode.SetUnlocked(false)
    end, 110)
    lock:SetPoint('BOTTOMRIGHT', frame, 'BOTTOM', -4, 8)
    Widgets.SetTooltip(lock, 'Lock frames', 'Hide the drag handles and keep the frames where they are.')
    local settings = Widgets.Button(frame, 'Settings', function()
        Config.Toggle()
    end, 110)
    settings:SetPoint('BOTTOMLEFT', frame, 'BOTTOM', 4, 8)
    Widgets.SetTooltip(settings, 'Settings', 'Open the EorzeaUI settings window again.')
    return frame
end

-- While frames are unlocked outside Edit Mode, a small panel offers to lock them; locking by any
-- route hides it (EditMode.SetUnlocked).
function Config.ShowLockPrompt()
    local editMode = EditModeManagerFrame and EditModeManagerFrame:IsShown()
    if not EUI.EditMode.unlocked or editMode then
        return
    end
    lockPrompt = lockPrompt or createLockPrompt()
    lockPrompt:Show()
end

function Config.HideLockPrompt()
    if lockPrompt then
        lockPrompt:Hide()
    end
end

function Config.Toggle(pageKey)
    if not window then
        createWindow()
    end
    if pageKey then
        currentPage = pageKey
    end
    if window:IsShown() and not pageKey then
        window:Hide()
        return
    end
    window:Show()
    if pageKey then
        showPage(pageKey)
    end
end

-- Re-reads every control on the shown page (after a slash command changed a value).
function Config.Refresh()
    if window and window:IsShown() and currentPage and pages[currentPage] then
        for _, control in ipairs(pages[currentPage].controls) do
            control:Refresh()
        end
        updateReloadBar()
    end
end

-- A page under Options > AddOns with a button that opens the window. Blizzard's panel stays
-- open underneath; the window draws above it.
function Config.RegisterBlizzardEntry()
    -- Blizzard's Settings; the file's Settings is EUI.Settings.
    local blizzard = _G.Settings
    if not (blizzard and blizzard.RegisterCanvasLayoutCategory and blizzard.RegisterAddOnCategory) then
        EUI.LogOnce('config:blizzardEntry', 'Settings.RegisterCanvasLayoutCategory missing; no AddOns options entry')
        return
    end
    local panel = CreateFrame('Frame')
    local title = Widgets.Text(panel, 18, C.accent)
    title:SetPoint('TOPLEFT', 16, -16)
    title:SetText('EorzeaUI')
    local note = Widgets.Text(panel, 12, C.text)
    note:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -10)
    note:SetText('Settings live in their own window, also opened with /ffui.')
    local open = Widgets.Button(panel, 'Open settings', function()
        Config.Toggle('general')
    end, 140)
    open:SetPoint('TOPLEFT', note, 'BOTTOMLEFT', -6, -12)
    local ok, err = pcall(function()
        local category = blizzard.RegisterCanvasLayoutCategory(panel, 'EorzeaUI')
        blizzard.RegisterAddOnCategory(category)
    end)
    if not ok then
        EUI.LogOnce('config:blizzardEntryFailed', 'AddOns options entry failed: %s', tostring(err))
    end
end

-- The minimap addon compartment (## AddonCompartmentFunc in the .toc).
function EorzeaUI_OnAddonCompartmentClick()
    if EUI.ready then
        Config.Toggle()
    end
end
