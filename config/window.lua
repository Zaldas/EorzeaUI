local addonName, EUI = ...

-- The settings window (/ffui config): a header with search, the page list on the left grouped as
-- EUI.Config.PAGES (config/options.lua), the chosen page's title over its controls in a scrolling
-- column that runs to the window's right edge, and a footer with the reload status. Options
-- marked reload are read when the frames are built; changing one lists it in the footer.

local Config = EUI.Config
local Widgets = EUI.Widgets
local Style = EUI.Style
local Settings = EUI.Settings
local C = Widgets.COLORS

local WIDTH, HEIGHT = 1160, 800
local HEADER, FOOTER, SIDEBAR = 56, 52, 232
-- Content inset from the page list, and the gap between the content and the scrollbar.
local PAD, SCROLL_GAP = 32, 32
local CONTENT_WIDTH = WIDTH - SIDEBAR - PAD - SCROLL_GAP
local ROW_HEIGHT = 46
local SECTION_GAP = 22
local SCROLL_STEP = 60

local window
local pages = {}
local navButtons = {}
local currentPage
local searching = false
-- The search results' scroll child.
local results

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

local IDLE_STATUS = 'Changes save as you make them.'
-- Room for the footer status between the command chip and the buttons.
local STATUS_WIDTH = 560

-- The footer: reload options changed since the frames were built (gold) over options waiting
-- for combat to end (red), else the idle line.
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
    window.idleText:SetShown(not reload and not combat)
    window.reloadText:SetPoint('LEFT', window.kbd, 'RIGHT', 12, combat and 8 or 0)
    window.combatText:SetPoint('LEFT', window.kbd, 'RIGHT', 12, reload and -8 or 0)
    window.reloadButton:SetVariant(reload and 'gold' or 'default')
    -- Every change passes here; the section and page resets follow it.
    local built = currentPage and pages[currentPage]
    for _, header in ipairs(built and built.headers or {}) do
        header:Refresh()
    end
    window.resetPage:Refresh()
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

-- Control spec for one registry item; item fields as documented in config/options.lua.
local function bind(item)
    local spec = {
        label = item.label,
        tip = item.tip,
        choices = item.choices,
        min = item.min, max = item.max, step = item.step, format = item.format, range = item.range,
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
-- nil for items a reset skips (noReset, or no saved value).
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

-- A reset over items: { isDefault(), reset() }, or nil when none of them can reset.
local function resetFor(items)
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

-- Enables or disables every control in frame, recursively.
local function setEnabled(frame, on)
    if frame.SetEnabled then
        frame:SetEnabled(on)
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        setEnabled(child, on)
    end
end

---------------------------------------------------------------------------------------------
-- Rows

-- The in-game art an indicator draws, centred in a dark tile; pieces as EUI.Indicators.Samples,
-- plus fill (a colour block). Wide enough for the AFK and DND badges side by side.
local ART_TILE_WIDTH, ART_GAP = 100, 6

local function artTile(parent, pieces)
    local tile = CreateFrame('Frame', nil, parent)
    tile:SetSize(ART_TILE_WIDTH, 34)
    Widgets.Box(tile, 7, C.input, '#A0B9DC2E')
    local strip = CreateFrame('Frame', nil, tile)
    local x, height = 0, 0
    for i, piece in ipairs(pieces or {}) do
        local w, h = piece.size and piece.size[1] or 18, piece.size and piece.size[2] or 18
        local texture = strip:CreateTexture(nil, 'ARTWORK')
        texture:SetSize(w, h)
        texture:SetPoint('LEFT', x, 0)
        if piece.fill then
            texture:SetColorTexture(Style.Color(piece.fill))
        elseif piece.rest then
            local loop = EUI.Indicators.SetRestArt(texture)
            if loop then
                loop:Play()
                tile:HookScript('OnShow', function()
                    if not loop:IsPlaying() then
                        loop:Play()
                    end
                end)
            end
        elseif piece.atlas then
            Style.SetAtlas(texture, piece.atlas, piece.path and { path = piece.path, coords = piece.coords })
        else
            texture:SetTexture(piece.path)
            if piece.coords then
                texture:SetTexCoord(unpack(piece.coords))
            end
        end
        if piece.color then
            texture:SetVertexColor(Style.Color(piece.color))
        end
        x = x + w + (i < #pieces and (piece.gap or ART_GAP) or 0)
        height = math.max(height, h)
    end
    strip:SetSize(math.max(1, x), math.max(1, height))
    strip:SetPoint('CENTER')
    return tile
end

-- A settings row: optional art tile, label with the item's tip under it, the control on the
-- right. Grows past ROW_HEIGHT for wrapped tips. spec (optional): the control's spec; setting
-- through it refreshes the whole row.
local function row(parent, item, control, spec)
    local holder = CreateFrame('Frame', nil, parent)
    local left = 0
    local tile
    if item.art then
        tile = artTile(holder, item.art())
        left = ART_TILE_WIDTH + 16
    end
    local textWidth = CONTENT_WIDTH - left - control:GetWidth() - 24
    local label = Widgets.Text(holder, 13, C.text)
    label:SetText(item.label or '')
    local hint
    if item.tip then
        hint = Widgets.Text(holder, 12, C.dim)
        hint:SetWidth(textWidth)
        hint:SetWordWrap(true)
        hint:SetSpacing(2)
        hint:SetText(item.tip)
    end
    local textHeight = 17 + (hint and (hint:GetStringHeight() + 2) or 0)
    local height = math.max(ROW_HEIGHT, math.ceil(textHeight) + 16, control:GetHeight() + 12)
    holder:SetSize(CONTENT_WIDTH, height)
    label:SetPoint('TOPLEFT', left, -math.floor((height - textHeight) / 2))
    if hint then
        hint:SetPoint('TOPLEFT', label, 'BOTTOMLEFT', 0, -2)
    end
    if tile then
        tile:SetPoint('LEFT', 0, 0)
    end
    control:SetParent(holder)
    control:ClearAllPoints()
    control:SetPoint('RIGHT', 0, 0)
    local separator = Widgets.Solid(holder, 'BACKGROUND', C.lineFaint)
    separator:SetHeight(1)
    separator:SetPoint('BOTTOMLEFT')
    separator:SetPoint('BOTTOMRIGHT')
    function holder:Refresh()
        control:Refresh()
        local enabled = not item.enabled or item.enabled()
        setEnabled(control, enabled)
        local alpha = enabled and 1 or 0.38
        -- Indicator rows dim while their indicator is off.
        if item.art and item.path and not Settings.Get(item.path) then
            alpha = 0.6
        end
        self:SetAlpha(alpha)
    end
    if spec then
        local set = spec.set
        spec.set = function(value)
            set(value)
            holder:Refresh()
        end
    end
    return holder, 0, separator
end

-- Column titles over the scale table.
local SCALE_SLIDER_WIDTH, SCALE_FINAL_WIDTH = 318, 64

local function scaleColumns(parent)
    local holder = CreateFrame('Frame', nil, parent)
    holder:SetSize(CONTENT_WIDTH, 26)
    local function column(text, x, right)
        local label = Widgets.Text(holder, 11, C.dim, 'semibold')
        label:SetText(Widgets.Caps(text))
        if right then
            label:SetPoint('BOTTOMRIGHT', 0, 6)
        else
            label:SetPoint('BOTTOMLEFT', x, 6)
        end
    end
    column('Frame', 0)
    column('Own scale', CONTENT_WIDTH - SCALE_FINAL_WIDTH - 14 - SCALE_SLIDER_WIDTH)
    column('Final', 0, true)
    function holder:Refresh() end
    return holder
end

-- A scale table row: name, slider and value, then the final scale.
local function scaleRow(parent, item)
    local holder = CreateFrame('Frame', nil, parent)
    holder:SetSize(CONTENT_WIDTH, 40)
    local line = Widgets.Solid(holder, 'BACKGROUND', C.lineFaint)
    line:SetHeight(1)
    line:SetPoint('TOPLEFT')
    line:SetPoint('TOPRIGHT')
    local label = Widgets.Text(holder, 13, C.text)
    label:SetPoint('LEFT', 0, 0)
    label:SetText(item.label)
    local hit = CreateFrame('Frame', nil, holder)
    hit:SetAllPoints(label)
    hit:EnableMouse(true)
    Widgets.SetTooltip(hit, item.label, item.tip)
    local spec = bind(item)
    spec.width = SCALE_SLIDER_WIDTH
    local slider = Widgets.Slider(holder, spec)
    slider:SetPoint('RIGHT', -(SCALE_FINAL_WIDTH + 14), 0)
    local final = Widgets.Text(holder, 12, C.dim)
    final:SetPoint('RIGHT', 0, 0)
    final:SetWidth(SCALE_FINAL_WIDTH)
    final:SetJustifyH('RIGHT')
    function holder:Refresh()
        slider:Refresh()
        local value = item.final()
        final:SetText(string.format('%.2f\195\151', value))
        final:SetTextColor(Style.Color(math.abs(value - 1) < 0.001 and C.dim or C.accentPale))
        local enabled = not item.enabled or item.enabled()
        setEnabled(slider, enabled)
        self:SetAlpha(enabled and 1 or 0.38)
    end
    return holder
end

-- A font row: name, a sample in the chosen font, and the font list.
local function fontRow(parent, item)
    local holder = CreateFrame('Frame', nil, parent)
    holder:SetSize(CONTENT_WIDTH, 58)
    local label = Widgets.Text(holder, 13, C.text)
    label:SetPoint('LEFT', 0, 0)
    label:SetText(item.label)
    local hit = CreateFrame('Frame', nil, holder)
    hit:SetPoint('LEFT')
    hit:SetSize(150, 40)
    hit:EnableMouse(true)
    Widgets.SetTooltip(hit, item.label, item.tip)
    local spec = bind(item)
    spec.fontPreview = true
    -- A pick redraws the sample too, not only the dropdown.
    local set = spec.set
    spec.set = function(value)
        set(value)
        holder:Refresh()
    end
    local dropdown = Widgets.Dropdown(holder, spec)
    dropdown:SetPoint('RIGHT', 0, 0)
    local sample = CreateFrame('Frame', nil, holder)
    sample:SetPoint('LEFT', 168, 0)
    sample:SetPoint('RIGHT', dropdown, 'LEFT', -18, 0)
    sample:SetHeight(36)
    Widgets.Box(sample, 7, C.deep, '#A0B9DC1A')
    local text = sample:CreateFontString(nil, 'OVERLAY')
    text:SetPoint('LEFT', 12, 0)
    text:SetPoint('RIGHT', -12, 0)
    text:SetJustifyH('LEFT')
    text:SetWordWrap(false)
    local separator = Widgets.Solid(holder, 'BACKGROUND', C.lineFaint)
    separator:SetHeight(1)
    separator:SetPoint('BOTTOMLEFT')
    separator:SetPoint('BOTTOMRIGHT')
    function holder:Refresh()
        dropdown:Refresh()
        Style.SetFont(text, spec.get(), 15, 'OUTLINE')
        text:SetText(item.preview)
    end
    return holder, 0, separator
end

-- Colour cells two to a row.
local COLOR_COLUMNS, COLOR_GAP = 2, 24

local function colorGrid(parent, items)
    local holder = CreateFrame('Frame', nil, parent)
    local cellWidth = (CONTENT_WIDTH - COLOR_GAP * (COLOR_COLUMNS - 1)) / COLOR_COLUMNS
    local cells = {}
    for i, item in ipairs(items) do
        local cell = Widgets.Color(holder, cellWidth, bind(item))
        local column, line = (i - 1) % COLOR_COLUMNS, math.floor((i - 1) / COLOR_COLUMNS)
        cell:SetPoint('TOPLEFT', column * (cellWidth + COLOR_GAP), -line * 44)
        cells[#cells + 1] = cell
    end
    holder:SetSize(CONTENT_WIDTH, math.ceil(#items / COLOR_COLUMNS) * 44)
    function holder:Refresh()
        for _, cell in ipairs(cells) do
            cell:Refresh()
        end
    end
    return holder
end

-- The swatches a palette card shows, as palette keys.
local CARD_KEYS = { 'hp', 'cast', 'powerColors.0', 'name', 'combo' }

local function paletteColor(name, key)
    local saved = Settings.Get(string.format('colors.%s.%s', name, key))
    if saved then
        return saved
    end
    local value = EUI.StyleKit.PALETTES[name]
    for part in key:gmatch('[^.]+') do
        value = type(value) == 'table' and value[tonumber(part) or part] or nil
    end
    return value or '#FFFFFFFF'
end

-- One card per palette: its colours as a strip, its name, and whether it is in use.
local function paletteCards(parent, item)
    local holder = CreateFrame('Frame', nil, parent)
    local spec = bind(item)
    local count = #item.choices
    local columns = math.min(3, count)
    local gap = 12
    local cardWidth = (CONTENT_WIDTH - gap * (columns - 1)) / columns
    local cards = {}
    for i, choice in ipairs(item.choices) do
        local card = CreateFrame('Button', nil, holder)
        card:SetSize(cardWidth, 70)
        card:SetPoint('TOPLEFT', ((i - 1) % columns) * (cardWidth + gap), -math.floor((i - 1) / columns) * (70 + gap))
        card.box = Widgets.Box(card, 10)
        local strip = {}
        local swatchWidth = (cardWidth - 24 - 4 * (#CARD_KEYS - 1)) / #CARD_KEYS
        for k, key in ipairs(CARD_KEYS) do
            local swatch = Widgets.Rounded(card, 'ARTWORK', 3, paletteColor(choice[1], key))
            swatch:SetSize(swatchWidth, 18)
            swatch:SetPoint('TOPLEFT', 12 + (k - 1) * (swatchWidth + 4), -12)
            strip[k] = swatch
        end
        local name = Widgets.Text(card, 12, C.text, 'medium')
        name:SetPoint('BOTTOMLEFT', 12, 12)
        name:SetText(choice[2])
        card.note = Widgets.Text(card, 11, C.dim)
        card.note:SetPoint('BOTTOMRIGHT', -12, 12)
        card.value, card.strip, card.hovered = choice[1], strip, false
        card:SetScript('OnEnter', function(self)
            self.hovered = true
            holder:Refresh()
        end)
        card:SetScript('OnLeave', function(self)
            self.hovered = false
            holder:Refresh()
        end)
        card:SetScript('OnClick', EUI.Guard('config palette', function()
            spec.set(choice[1])
            holder:Refresh()
        end))
        Widgets.SetTooltip(card, choice[2], choice[3] or item.tip)
        cards[#cards + 1] = card
    end
    holder:SetSize(CONTENT_WIDTH, math.ceil(count / columns) * (70 + gap) - gap + 10)
    function holder:Refresh()
        local chosen = spec.get()
        local built = Config.style and Config.style.palette
        for _, card in ipairs(cards) do
            local on = card.value == chosen
            card.box:SetColors('#0A11208C', (on and '#6FD3E8B3') or (card.hovered and '#A0B9DC66') or '#A0B9DC29')
            if card.value == built then
                card.note:SetText(on and 'In use' or 'In use until reload')
            else
                card.note:SetText(on and 'After reload' or '')
            end
            card.note:SetTextColor(Style.Color(card.value == built and C.dim or C.goldText))
            for k, key in ipairs(CARD_KEYS) do
                card.strip[k]:SetVertexColor(Style.Color(paletteColor(card.value, key)))
            end
        end
    end
    return holder
end

-- A row of buttons, labelled as any row.
local function buttonRow(parent, item)
    local group = CreateFrame('Frame', nil, parent)
    -- Right to left: the last button sits at the right edge.
    local buttons, labelFns = {}, {}
    for i = #item.buttons, 1, -1 do
        local def = item.buttons[i]
        local button = Widgets.Button(group, def.label, function(self)
            def.run(self)
            updateReloadBar()
        end, { variant = def.variant, icon = def.icon })
        if def.tip then
            Widgets.SetTooltip(button, def.label, def.tip)
        end
        buttons[#buttons + 1] = button
        labelFns[#buttons] = def.labelFn
    end
    function group:Refresh()
        local x = 0
        for i, button in ipairs(buttons) do
            if labelFns[i] then
                button:SetLabel(labelFns[i]())
            end
            button:ClearAllPoints()
            button:SetPoint('RIGHT', group, 'RIGHT', -x, 0)
            x = x + button:GetWidth() + 8
        end
        group:SetSize(math.max(1, x - 8), 34)
    end
    group:Refresh()
    return row(parent, item, group)
end

---------------------------------------------------------------------------------------------
-- Support & About

local function addonMetadata(field)
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return get and get(addonName, field)
end

local function hero(parent)
    local holder = CreateFrame('Frame', nil, parent)
    holder:SetSize(CONTENT_WIDTH, 132)
    local tile = holder:CreateTexture(nil, 'ARTWORK')
    tile:SetTexture(string.format('Interface\\AddOns\\%s\\Media\\AddonIcon', addonName))
    tile:SetSize(84, 84)
    tile:SetPoint('TOPLEFT', 0, -4)
    local kicker = Widgets.Text(holder, 11, C.accentText, 'semibold')
    kicker:SetPoint('TOPLEFT', tile, 'TOPRIGHT', 24, -2)
    kicker:SetText(Widgets.Caps('Addon'))
    local title = Widgets.Text(holder, 30, C.bright, 'display')
    title:SetPoint('TOPLEFT', kicker, 'BOTTOMLEFT', 0, -6)
    title:SetText(addonName)
    local notes = Widgets.Text(holder, 13, C.body)
    notes:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -6)
    notes:SetText(addonMetadata('Notes') or '')
    local chips = {}
    local version = addonMetadata('Version')
    if version then
        chips[#chips + 1] = 'Version ' .. version
    end
    if GetBuildInfo then
        chips[#chips + 1] = 'Game ' .. tostring((GetBuildInfo()))
    end
    local previous
    for _, text in ipairs(chips) do
        local chip = Widgets.Kbd(holder, text)
        if previous then
            chip:SetPoint('LEFT', previous, 'RIGHT', 8, 0)
        else
            chip:SetPoint('TOPLEFT', notes, 'BOTTOMLEFT', 0, -12)
        end
        previous = chip
    end
    local line = Widgets.Solid(holder, 'BACKGROUND', '#A0B9DC1A')
    line:SetHeight(1)
    line:SetPoint('BOTTOMLEFT')
    line:SetPoint('BOTTOMRIGHT')
    function holder:Refresh() end
    return holder
end

local function command(parent, item)
    local holder = CreateFrame('Frame', nil, parent)
    local text = Widgets.Text(holder, 13, C.body)
    text:SetWidth(CONTENT_WIDTH - 164)
    text:SetWordWrap(true)
    text:SetText(item.text)
    local height = math.max(40, math.ceil(text:GetStringHeight()) + 18)
    holder:SetSize(CONTENT_WIDTH, height)
    local kbd = Widgets.Kbd(holder, item.command)
    kbd:SetPoint('LEFT', 0, 0)
    text:SetPoint('LEFT', 164, 0)
    local separator = Widgets.Solid(holder, 'BACKGROUND', C.lineFaint)
    separator:SetHeight(1)
    separator:SetPoint('BOTTOMLEFT')
    separator:SetPoint('BOTTOMRIGHT')
    function holder:Refresh() end
    return holder, 0, separator
end

-- A question that opens to its answer; relayout() restacks the page.
local function faq(parent, item, relayout)
    local holder = CreateFrame('Frame', nil, parent)
    local button = CreateFrame('Button', nil, holder)
    button:SetPoint('TOPLEFT')
    button:SetPoint('TOPRIGHT')
    button:SetHeight(44)
    local box = Widgets.Box(holder, 10, '#0A11208C', '#A0B9DC24')
    local label = Widgets.Text(button, 13, C.text)
    label:SetPoint('LEFT', 16, 0)
    label:SetText(item.label)
    local chevron = Widgets.Icon(button, 'chevron', 14, C.body)
    chevron:SetPoint('RIGHT', -14, 0)
    local answer = Widgets.Text(holder, 13, C.body)
    answer:SetPoint('TOPLEFT', 16, -44)
    answer:SetWidth(CONTENT_WIDTH - 32)
    answer:SetWordWrap(true)
    answer:SetSpacing(3)
    answer:SetText(item.text)
    local open = false
    local function layout()
        answer:SetShown(open)
        chevron:SetRotation(open and 0 or math.pi / 2)
        holder:SetSize(CONTENT_WIDTH, open and (44 + math.ceil(answer:GetStringHeight()) + 14) or 44)
    end
    button:SetScript('OnEnter', function() label:SetTextColor(Style.Color(C.bright)) end)
    button:SetScript('OnLeave', function() label:SetTextColor(Style.Color(C.text)) end)
    button:SetScript('OnClick', EUI.Guard('config faq', function()
        open = not open
        layout()
        box:SetColors('#0A11208C', open and '#A0B9DC38' or '#A0B9DC24')
        relayout()
    end))
    layout()
    function holder:Refresh() end
    return holder, 8
end

---------------------------------------------------------------------------------------------
-- Pages

-- Each builder returns the control, the gap above it (default 0) and the separator line under
-- it, if it has one.
local BUILDERS = {
    header = function(parent, item, section)
        return Widgets.Header(parent, CONTENT_WIDTH, item.label, resetFor(section))
    end,
    note = function(parent, item)
        return Widgets.Note(parent, CONTENT_WIDTH, item.text, item.color, item.shown)
    end,
    toggle = function(parent, item)
        local spec = bind(item)
        return row(parent, item, Widgets.Toggle(parent, spec), spec)
    end,
    choice = function(parent, item)
        if item.style == 'tabs' then
            return Widgets.Tabs(parent, CONTENT_WIDTH, bind(item)), 4
        elseif item.style == 'font' then
            return fontRow(parent, item)
        end
        return row(parent, item, Widgets.Segmented(parent, bind(item)))
    end,
    slider = function(parent, item)
        if item.final then
            return scaleRow(parent, item)
        end
        local spec = bind(item)
        spec.width = item.width
        spec.valueColor = item.emphasis and C.bright or nil
        return row(parent, item, Widgets.Slider(parent, spec))
    end,
    buttons = buttonRow,
    palettes = paletteCards,
    hero = hero,
    command = command,
    faq = faq,
}

-- Stacks a page's entries: sections apart, rows flush, a separator between consecutive rows.
local function layoutPage(built)
    local y = 20
    for i, entry in ipairs(built.entries) do
        if i > 1 then
            y = y + (entry.header and SECTION_GAP or entry.gap)
        end
        entry.control:ClearAllPoints()
        entry.control:SetPoint('TOPLEFT', PAD, -y)
        entry.top = y
        y = y + entry.control:GetHeight() + (entry.header and 4 or 0)
        if entry.separator then
            local nextEntry = built.entries[i + 1]
            entry.separator:SetShown(nextEntry ~= nil and nextEntry.separator ~= nil)
        end
    end
    built.frame:SetHeight(y + 28)
end

local function buildPage(page)
    local child = CreateFrame('Frame', nil, window.scroll)
    child:SetWidth(WIDTH - SIDEBAR - 2)
    -- entries: { control, gap, separator, header, first, last (item indexes), top }.
    local built = { frame = child, controls = {}, headers = {}, entries = {} }
    local items = page.items
    if type(items) == 'function' then
        items = items()
    end
    built.items = items
    local function relayout()
        layoutPage(built)
    end
    local function add(control, first, last, gap, separator, header)
        built.entries[#built.entries + 1] = {
            control = control, first = first, last = last, gap = gap or 0, separator = separator, header = header,
        }
        built.controls[#built.controls + 1] = control
        if header then
            built.headers[#built.headers + 1] = control
        end
    end
    local i = 1
    while i <= #items do
        local item = items[i]
        if item.kind == 'color' then
            -- Consecutive colours share one grid.
            local run = {}
            while items[i] and items[i].kind == 'color' do
                run[#run + 1] = items[i]
                i = i + 1
            end
            add(colorGrid(child, run), i - #run, i - 1, 2)
        else
            local build = BUILDERS[item.kind]
            if item.kind == 'slider' and item.final and not (items[i - 1] and items[i - 1].final) then
                add(scaleColumns(child))
            end
            if item.kind == 'header' then
                local section = {}
                for j = i + 1, #items do
                    if items[j].kind == 'header' then
                        break
                    end
                    section[#section + 1] = items[j]
                end
                add(build(child, item, section), i, i, 0, nil, true)
            elseif build then
                local control, gap, separator = build(child, item, relayout)
                add(control, i, i, gap, separator)
            else
                EUI.LogOnce('config:kind:' .. tostring(item.kind), 'config: unknown item kind %s', tostring(item.kind))
            end
            i = i + 1
        end
    end
    built.reset = resetFor(items)
    layoutPage(built)
    child:Hide()
    return built
end

local function updateScrollbar()
    local scroll = window.scroll
    local range = scroll:GetVerticalScrollRange()
    local thumb = window.scrollThumb
    if range <= 0 then
        thumb:Hide()
        return
    end
    local visible = scroll:GetHeight()
    local total = visible + range
    local height = math.max(32, visible * visible / total)
    thumb:SetHeight(height)
    thumb:ClearAllPoints()
    thumb:SetPoint('TOPRIGHT', scroll, 'TOPRIGHT', 0, -(visible - height) * scroll:GetVerticalScroll() / range)
    thumb:Show()
end

local function scrollTo(offset)
    local scroll = window.scroll
    scroll:SetVerticalScroll(math.max(0, math.min(scroll:GetVerticalScrollRange(), offset)))
    updateScrollbar()
end

-- The fixed title area over the scrolling column.
local function setPageHeader(kicker, title, description, reloadNote)
    local header = window.pageHeader
    header.kicker:SetText(Widgets.Caps(kicker))
    header.title:SetText(title)
    header.description:SetText(description or '')
    local height = 24 + 16 + 4 + 32 + 6 + math.ceil(header.description:GetStringHeight()) + 18
    header:SetHeight(height)
    window.scroll:SetPoint('TOPLEFT', window, 'TOPLEFT', SIDEBAR + 1, -(HEADER + height))
    header.chip:SetShown(reloadNote and true or false)
end

local function pageByKey(key)
    for _, page in ipairs(Config.PAGES) do
        if page.key == key then
            return page
        end
    end
end

local function showPage(key)
    Widgets.CloseMenus()
    if results then
        results:Hide()
    end
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
            setPageHeader(page.group, page.label, page.tip, page.reloadNote)
        elseif built then
            built.frame:Hide()
        end
    end
    for pageKey, button in pairs(navButtons) do
        button:SetCurrent(pageKey == key and not searching)
    end
    currentPage = key
    local page = pageByKey(key)
    if page then
        EUI.Demo.SetPageSections(page.demo)
    end
    scrollTo(0)
    updateReloadBar()
end

-- Rebuilds pages whose items depend on settings (the colour page follows the palette).
function Config.RebuildPage(key)
    local built = pages[key]
    if built then
        built.frame:Hide()
        pages[key] = nil
    end
    if window and window:IsShown() and currentPage == key and not searching then
        showPage(key)
    end
end

---------------------------------------------------------------------------------------------
-- Search: every page's labelled items whose label or tip holds the text, listed by page; a
-- result opens its page scrolled to the setting.

local SEARCHABLE = { toggle = true, choice = true, slider = true, color = true, buttons = true, palettes = true,
    faq = true, command = true }

local function plain(text)
    return (text or ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''):lower()
end

local function searchMatches(query)
    local matches = {}
    query = query:lower()
    for _, page in ipairs(Config.PAGES) do
        local items = pages[page.key] and pages[page.key].items or page.items
        if type(items) == 'function' then
            items = items()
        end
        local section
        for index, item in ipairs(items) do
            if item.kind == 'header' then
                section = item.label
            elseif SEARCHABLE[item.kind] then
                local label = item.label or item.command or ''
                local haystack = plain(label) .. '\n' .. plain(item.tip) .. '\n' .. plain(item.text)
                if haystack:find(query, 1, true) then
                    matches[#matches + 1] = {
                        page = page, index = index, label = label,
                        crumb = section and (page.label .. '  \226\128\186  ' .. section) or page.label,
                    }
                end
            end
        end
    end
    return matches
end

local RESULT_HEIGHT = 50
local openResult

local function resultRow(index)
    local button = results.rows[index]
    if button then
        return button
    end
    button = CreateFrame('Button', nil, results)
    button:SetSize(CONTENT_WIDTH, RESULT_HEIGHT)
    button.box = Widgets.Box(button, 8)
    button.label = Widgets.Text(button, 13, C.text)
    button.label:SetPoint('TOPLEFT', 12, -9)
    button.crumb = Widgets.Text(button, 12, C.dim)
    button.crumb:SetPoint('TOPLEFT', button.label, 'BOTTOMLEFT', 0, -3)
    local arrow = Widgets.Icon(button, 'chevron', 14, C.body)
    arrow:SetRotation(math.pi / 2)
    arrow:SetPoint('RIGHT', -12, 0)
    button:SetScript('OnEnter', function(self) self.box:SetColors('#A0B9DC12', '#A0B9DC29') end)
    button:SetScript('OnLeave', function(self) self.box:SetColors(nil, nil) end)
    button:SetScript('OnClick', EUI.Guard('config search result', function(self)
        openResult(self.match)
    end))
    results.rows[index] = button
    return button
end

local function showResults(query)
    if not results then
        results = CreateFrame('Frame', nil, window.scroll)
        results:SetWidth(WIDTH - SIDEBAR - 2)
        results.rows = {}
        results.empty = Widgets.Text(results, 13, C.dim)
        results.empty:SetPoint('TOPLEFT', PAD, -24)
    end
    for _, built in pairs(pages) do
        built.frame:Hide()
    end
    local matches = searchMatches(query)
    for i, match in ipairs(matches) do
        local button = resultRow(i)
        button.match = match
        button.label:SetText(match.label)
        button.crumb:SetText(match.crumb)
        button.box:SetColors(nil, nil)
        button:ClearAllPoints()
        button:SetPoint('TOPLEFT', PAD - 12, -(16 + (i - 1) * (RESULT_HEIGHT + 2)))
        button:SetWidth(CONTENT_WIDTH + 24)
        button:Show()
    end
    for i = #matches + 1, #results.rows do
        results.rows[i]:Hide()
    end
    results.empty:SetShown(#matches == 0)
    results.empty:SetText(string.format('No settings match \226\128\156%s\226\128\157.', query))
    results:SetHeight(32 + #matches * (RESULT_HEIGHT + 2))
    window.scroll:SetScrollChild(results)
    results:Show()
    setPageHeader('Search', 'Results', #matches == 1 and '1 setting matches.'
        or string.format('%d settings match.', #matches))
    for _, button in pairs(navButtons) do
        button:SetCurrent(false)
    end
    scrollTo(0)
end

local function setSearching(on)
    searching = on
    window.resetPage:SetShown(not on)
end

-- A brief highlight behind the control a search result opened.
local function flash(control)
    local glow = window.flash
    glow:ClearAllPoints()
    glow:SetPoint('TOPLEFT', control, 'TOPLEFT', -12, 2)
    glow:SetPoint('BOTTOMRIGHT', control, 'BOTTOMRIGHT', 12, -2)
    glow:SetParent(control:GetParent())
    glow:SetFrameLevel(math.max(0, control:GetFrameLevel() - 1))
    glow.elapsed = 0
    glow:Show()
end

openResult = function(match)
    window.search:SetText('')
    window.search:ClearFocus()
    setSearching(false)
    showPage(match.page.key)
    for _, entry in ipairs(pages[match.page.key].entries) do
        if entry.first and entry.first <= match.index and match.index <= entry.last then
            scrollTo(entry.top - 60)
            flash(entry.control)
            break
        end
    end
end

---------------------------------------------------------------------------------------------
-- The window

local function createNavButton(parent, page)
    local button = CreateFrame('Button', nil, parent)
    button:SetSize(SIDEBAR - 24, 32)
    local box = Widgets.Box(button, 7)
    local pointer = Widgets.Icon(button, 'pointer', 12, C.gold)
    pointer:SetPoint('LEFT', 2, 0)
    local icon = Widgets.Icon(button, page.icon, 16, C.body)
    icon:SetPoint('LEFT', 14, 0)
    local label = Widgets.Text(button, 13, C.body)
    label:SetPoint('LEFT', icon, 'RIGHT', 10, 0)
    label:SetText(page.label)
    local current, hovered = false, false
    local function paint()
        if current then
            box:SetColors('#6FD3E81C', '#6FD3E847')
            label:SetTextColor(Style.Color(C.bright))
            icon:SetVertexColor(Style.Color(C.accentText))
        else
            box:SetColors(hovered and '#A0B9DC12' or nil, nil)
            label:SetTextColor(Style.Color(hovered and C.text or C.body))
            icon:SetVertexColor(Style.Color(hovered and C.text or C.body))
        end
        pointer:SetShown(current)
    end
    function button:SetCurrent(on)
        current = on
        paint()
    end
    button:SetScript('OnEnter', function()
        hovered = true
        paint()
    end)
    button:SetScript('OnLeave', function()
        hovered = false
        paint()
    end)
    button:SetScript('OnClick', function()
        if searching then
            window.search:SetText('')
            window.search:ClearFocus()
            setSearching(false)
        end
        showPage(page.key)
    end)
    paint()
    return button
end

local function createSidebar()
    local sidebar = CreateFrame('Frame', nil, window)
    sidebar:SetPoint('TOPLEFT', 1, -HEADER)
    sidebar:SetPoint('BOTTOMLEFT', 1, FOOTER)
    sidebar:SetWidth(SIDEBAR - 1)
    local fill = Widgets.Solid(sidebar, 'BACKGROUND', '#090E1BFF')
    fill:SetAllPoints()
    local edge = Widgets.Solid(sidebar, 'BORDER', '#A0B9DC1F')
    edge:SetWidth(1)
    edge:SetPoint('TOPRIGHT')
    edge:SetPoint('BOTTOMRIGHT')

    local y = -18
    local group
    for _, page in ipairs(Config.PAGES) do
        if page.group ~= group then
            if group then
                y = y - 14
            end
            group = page.group
            local heading = Widgets.Text(sidebar, 10, C.faint, 'semibold')
            heading:SetPoint('TOPLEFT', 22, y)
            heading:SetText(Widgets.Caps(group))
            y = y - 20
        end
        local button = createNavButton(sidebar, page)
        button:SetPoint('TOPLEFT', 12, y)
        navButtons[page.key] = button
        y = y - 33
    end

    -- Bottom: every frame's demo at once.
    local line = Widgets.Solid(sidebar, 'BORDER', C.lineSoft)
    line:SetHeight(1)
    line:SetPoint('BOTTOMLEFT', 12, 64)
    line:SetPoint('BOTTOMRIGHT', -12, 64)
    local demoTitle = Widgets.Text(sidebar, 12, C.text)
    demoTitle:SetPoint('BOTTOMLEFT', 22, 36)
    demoTitle:SetText('Demo frames')
    local demoHint = Widgets.Text(sidebar, 11, C.dim)
    demoHint:SetPoint('TOPLEFT', demoTitle, 'BOTTOMLEFT', 0, -2)
    demoHint:SetText('Show test units')
    local demo = Widgets.Toggle(sidebar, {
        get = function() return EUI.Demo.toggled end,
        set = function() EUI.Demo.Toggle() end,
    })
    demo:SetPoint('BOTTOMRIGHT', -22, 26)
    Widgets.SetTooltip(demo, 'Demo frames',
        'Fill every frame with sample data, whichever page is open (/ffui demo). Each page shows its own frames anyway.')
    window.demoToggle = demo
end

local function createHeader()
    local fill = Widgets.Rounded(window, 'BACKGROUND', 12, C.bar, false, 1)
    fill:SetPoint('TOPLEFT')
    fill:SetPoint('TOPRIGHT')
    fill:SetHeight(HEADER + 12)
    local line = Widgets.Solid(window, 'BORDER', C.lineSoft)
    line:SetHeight(1)
    line:SetPoint('TOPLEFT', 1, -HEADER)
    line:SetPoint('TOPRIGHT', -1, -HEADER)

    local logo = window:CreateTexture(nil, 'ARTWORK')
    logo:SetTexture(string.format('Interface\\AddOns\\%s\\Media\\AddonIcon', addonName))
    logo:SetSize(36, 36)
    logo:SetPoint('LEFT', window, 'TOPLEFT', 14, -HEADER / 2)
    local title = Widgets.Text(window, 18, C.bright, 'display')
    title:SetPoint('LEFT', logo, 'RIGHT', 12, 0)
    title:SetText(addonName)
    local subtitle = Widgets.Text(window, 11, C.dim, 'medium')
    subtitle:SetPoint('LEFT', title, 'RIGHT', 14, 0)
    subtitle:SetText(Widgets.Caps('Settings'))

    local close = Widgets.Button(window, '', function() window:Hide() end,
        { variant = 'ghost', icon = 'close', iconSize = 16, width = 34 })
    close:SetPoint('RIGHT', window, 'TOPRIGHT', -12, -HEADER / 2)
    Widgets.SetTooltip(close, 'Close', 'Escape also closes the window.')

    local search = Widgets.Input(window, { width = 260, height = 34, inset = 34 })
    search:SetPoint('RIGHT', close, 'LEFT', -12, 0)
    local glass = Widgets.Icon(search, 'search', 14, C.dim)
    glass:SetPoint('LEFT', 12, 0)
    local placeholder = Widgets.Text(search, 12, C.faint)
    placeholder:SetPoint('LEFT', 34, 0)
    placeholder:SetText('Search settings')
    search:SetScript('OnTextChanged', EUI.Guard('config search', function(self)
        local text = (self:GetText() or ''):gsub('^%s+', ''):gsub('%s+$', '')
        placeholder:SetShown(self:GetText() == '')
        if text ~= '' then
            setSearching(true)
            showResults(text)
        elseif searching then
            setSearching(false)
            showPage(currentPage or Config.PAGES[1].key)
        end
    end))
    search:SetScript('OnEscapePressed', function(self)
        self:SetText('')
        self:ClearFocus()
    end)
    search:SetScript('OnEnterPressed', function(self)
        local first = results and results.rows[1]
        if searching and first and first:IsShown() then
            openResult(first.match)
        end
        self:ClearFocus()
    end)
    window.search = search
end

local function createPageHeader()
    local header = CreateFrame('Frame', nil, window)
    header:SetPoint('TOPLEFT', SIDEBAR, -HEADER)
    header:SetPoint('TOPRIGHT', -1, -HEADER)
    header:SetHeight(120)
    local line = Widgets.Solid(header, 'BORDER', C.lineFaint)
    line:SetHeight(1)
    line:SetPoint('BOTTOMLEFT')
    line:SetPoint('BOTTOMRIGHT')
    header.kicker = Widgets.Text(header, 11, C.accentText, 'semibold')
    header.kicker:SetPoint('TOPLEFT', PAD, -24)
    header.title = Widgets.Text(header, 26, C.bright, 'display')
    header.title:SetPoint('TOPLEFT', PAD, -44)
    header.description = Widgets.Text(header, 13, C.body)
    header.description:SetPoint('TOPLEFT', PAD, -82)
    header.description:SetWidth(600)
    header.description:SetWordWrap(true)
    header.description:SetSpacing(2)

    -- 'Applies after a reload' with its own Reload button, on pages where everything does.
    local chip = CreateFrame('Frame', nil, header)
    chip:SetHeight(30)
    chip:SetPoint('BOTTOMRIGHT', -SCROLL_GAP, 18)
    Widgets.Box(chip, 15, '#C9A96A14', '#C9A96A66')
    local text = Widgets.Text(chip, 12, C.goldText)
    text:SetPoint('LEFT', 14, 0)
    text:SetText('Applies after a reload')
    local reload = Widgets.Button(chip, 'Reload', function()
        if InCombatLockdown() then
            EUI.Print('reload after combat')
            return
        end
        ReloadUI()
    end, { variant = 'gold', height = 22, pad = 10 })
    reload:SetPoint('RIGHT', -4, 0)
    chip:SetWidth(14 + text:GetStringWidth() + 10 + reload:GetWidth() + 4)
    header.chip = chip
    window.pageHeader = header
end

local function createFooter()
    local fill = Widgets.Rounded(window, 'BACKGROUND', 12, C.bar, false, 1)
    fill:SetPoint('BOTTOMLEFT')
    fill:SetPoint('BOTTOMRIGHT')
    fill:SetHeight(FOOTER + 12)
    local line = Widgets.Solid(window, 'BORDER', C.lineSoft)
    line:SetHeight(1)
    line:SetPoint('BOTTOMLEFT', 1, FOOTER)
    line:SetPoint('BOTTOMRIGHT', -1, FOOTER)

    local footer = CreateFrame('Frame', nil, window)
    footer:SetPoint('BOTTOMLEFT', 1, 1)
    footer:SetPoint('BOTTOMRIGHT', -1, 1)
    footer:SetHeight(FOOTER - 1)
    local kbd = Widgets.Kbd(footer, '/ffui config')
    kbd:SetPoint('LEFT', 19, 0)
    window.kbd = kbd
    window.idleText = Widgets.Text(footer, 12, C.dim)
    window.idleText:SetPoint('LEFT', kbd, 'RIGHT', 12, 0)
    window.idleText:SetText(IDLE_STATUS)
    window.reloadText = Widgets.Text(footer, 12, C.goldText)
    window.reloadText:SetPoint('LEFT', kbd, 'RIGHT', 12, 0)
    window.reloadText:SetWidth(STATUS_WIDTH)
    window.combatText = Widgets.Text(footer, 12, C.red)
    window.combatText:SetPoint('LEFT', kbd, 'RIGHT', 12, 0)
    window.combatText:SetWidth(STATUS_WIDTH)

    local reload = Widgets.Button(footer, 'Reload UI', function()
        if InCombatLockdown() then
            EUI.Print('reload after combat')
            return
        end
        ReloadUI()
    end, { variant = 'default' })
    reload:SetPoint('RIGHT', -19, 0)
    Widgets.SetTooltip(reload, 'Reload UI', function()
        if #(window.reloadLabels or {}) > 0 then
            return 'Reloads the interface so the changes listed here take effect.'
        end
        return 'Reloads the interface. Nothing is waiting for one.'
    end)
    window.reloadButton = reload

    -- Two clicks: the first asks, the second resets.
    local resetPage
    resetPage = Widgets.Button(footer, 'Reset this page', function(self)
        local built = currentPage and pages[currentPage]
        if not (built and built.reset) then
            return
        end
        if self.armed then
            self.armed = nil
            built.reset.reset()
            self:SetLabel('Reset this page')
            resetPage:Refresh()
            return
        end
        self.armed = true
        self:SetLabel('Click again to reset')
        C_Timer.After(3, function()
            if self.armed then
                self.armed = nil
                self:SetLabel('Reset this page')
            end
        end)
    end, { variant = 'ghost' })
    resetPage:SetPoint('RIGHT', reload, 'LEFT', -8, 0)
    Widgets.SetTooltip(resetPage, 'Reset this page', 'Put every setting on this page back to its default.')
    function resetPage:Refresh()
        local built = currentPage and pages[currentPage]
        local reset = built and built.reset
        self:SetShown(reset ~= nil and not searching)
        if reset then
            self:SetActive(not reset.isDefault())
        end
    end
    window.resetPage = resetPage

    -- The full lists while hovering the status.
    local summary = CreateFrame('Frame', nil, footer)
    summary:SetPoint('TOPLEFT', kbd, 'TOPRIGHT', 8, 8)
    summary:SetPoint('BOTTOMRIGHT', resetPage, 'BOTTOMLEFT', -8, -8)
    summary:EnableMouse(true)
    Widgets.SetTooltip(summary, 'Waiting changes', function()
        local lines = {}
        local reloadLabels, waiting = window.reloadLabels or {}, window.combatLabels or {}
        if #reloadLabels > 0 then
            lines[#lines + 1] = '|cfff0ddb3Applies after a reload|r'
            for _, label in ipairs(reloadLabels) do
                lines[#lines + 1] = label
            end
        end
        if #waiting > 0 then
            lines[#lines + 1] = '|cffff6b6bApplies once combat ends|r'
            for _, label in ipairs(waiting) do
                lines[#lines + 1] = label
            end
        end
        return #lines > 0 and table.concat(lines, '\n') or nil
    end)
end

local function createScroll()
    local main = Widgets.Solid(window, 'BACKGROUND', C.main, 2)
    main:SetPoint('TOPLEFT', SIDEBAR, -HEADER)
    main:SetPoint('BOTTOMRIGHT', -1, FOOTER)

    local scroll = CreateFrame('ScrollFrame', nil, window)
    scroll:SetPoint('TOPLEFT', SIDEBAR + 1, -(HEADER + 120))
    scroll:SetPoint('BOTTOMRIGHT', -1, FOOTER)
    scroll:EnableMouseWheel(true)
    scroll:SetScript('OnMouseWheel', function(self, delta)
        Widgets.CloseMenus()
        scrollTo(self:GetVerticalScroll() - delta * SCROLL_STEP)
    end)
    scroll:SetScript('OnScrollRangeChanged', function() updateScrollbar() end)
    window.scroll = scroll

    -- Flush against the window's right edge; drag it to scroll.
    local thumb = CreateFrame('Button', nil, window)
    thumb:SetWidth(6)
    thumb:SetFrameLevel(scroll:GetFrameLevel() + 20)
    local bar = Widgets.Rounded(thumb, 'ARTWORK', 3, '#A0B9DC40')
    bar:SetAllPoints()
    thumb:SetScript('OnEnter', function() bar:SetVertexColor(Style.Color('#A0B9DC73')) end)
    thumb:SetScript('OnLeave', function(self)
        if not self.dragging then
            bar:SetVertexColor(Style.Color('#A0B9DC40'))
        end
    end)
    thumb:SetScript('OnMouseDown', function(self)
        local _, y = GetCursorPosition()
        self.dragging = { y = y / self:GetEffectiveScale(), offset = scroll:GetVerticalScroll() }
    end)
    thumb:SetScript('OnMouseUp', function(self)
        self.dragging = nil
        if not self:IsMouseOver() then
            bar:SetVertexColor(Style.Color('#A0B9DC40'))
        end
    end)
    thumb:SetScript('OnUpdate', function(self)
        if not self.dragging then
            return
        end
        local _, y = GetCursorPosition()
        local travel = scroll:GetHeight() - self:GetHeight()
        if travel > 0 then
            local moved = self.dragging.y - y / self:GetEffectiveScale()
            scrollTo(self.dragging.offset + moved * scroll:GetVerticalScrollRange() / travel)
        end
    end)
    thumb:Hide()
    window.scrollThumb = thumb

    -- The search highlight, fading out.
    local flashFrame = CreateFrame('Frame', nil, scroll)
    flashFrame.fill = Widgets.Rounded(flashFrame, 'BACKGROUND', 8, '#6FD3E81F')
    flashFrame.fill:SetAllPoints()
    flashFrame:Hide()
    flashFrame:SetScript('OnUpdate', function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        local alpha = 1 - math.max(0, self.elapsed - 0.8) / 0.8
        if alpha <= 0 then
            self:Hide()
            return
        end
        self:SetAlpha(alpha)
    end)
    window.flash = flashFrame
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
    Widgets.Panel(window)

    createHeader()
    createScroll()
    createSidebar()
    createPageHeader()
    createFooter()

    window:SetScript('OnShow', function()
        window:SetScale(Widgets.Scale())
        Config.HideLockPrompt()
        if searching then
            window.search:SetText('')
            setSearching(false)
        end
        showPage(currentPage or Config.PAGES[1].key)
        window.demoToggle:Refresh()
        updateReloadBar()
    end)
    window:SetScript('OnHide', function()
        Widgets.CloseMenus()
        Widgets.HideTooltip()
        EUI.Demo.SetPageSections(nil)
        Config.ShowLockPrompt()
    end)
end

---------------------------------------------------------------------------------------------
-- Lock prompt

local lockPrompt

local function createLockPrompt()
    local frame = CreateFrame('Frame', 'EorzeaUILockPrompt', UIParent)
    frame:SetSize(400, 108)
    frame:SetPoint('TOP', 0, -120)
    frame:SetFrameStrata('DIALOG')
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag('LeftButton')
    frame:SetScript('OnDragStart', frame.StartMoving)
    frame:SetScript('OnDragStop', frame.StopMovingOrSizing)
    frame:Hide()
    Widgets.Panel(frame)
    local note = Widgets.Text(frame, 13, C.text)
    note:SetPoint('TOP', 0, -20)
    note:SetText('EorzeaUI frames are unlocked: drag them to move.')
    local lock = Widgets.Button(frame, 'Lock frames', function()
        EUI.EditMode.SetUnlocked(false)
    end, { variant = 'primary', width = 130 })
    lock:SetPoint('BOTTOMRIGHT', frame, 'BOTTOM', -4, 18)
    Widgets.SetTooltip(lock, 'Lock frames', 'Hide the drag handles and keep the frames where they are.')
    local settings = Widgets.Button(frame, 'Settings', function()
        Config.Toggle()
    end, { width = 130 })
    settings:SetPoint('BOTTOMLEFT', frame, 'BOTTOM', 4, 18)
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
    lockPrompt:SetScale(Widgets.Scale())
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
        if searching then
            window.search:SetText('')
            setSearching(false)
        end
        showPage(pageKey)
    end
end

-- Re-reads every control on the shown page (after a slash command changed a value).
function Config.Refresh()
    if window and window:IsShown() and currentPage and pages[currentPage] and not searching then
        for _, control in ipairs(pages[currentPage].controls) do
            control:Refresh()
        end
        window.demoToggle:Refresh()
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
    local title = Widgets.Text(panel, 20, C.bright, 'display')
    title:SetPoint('TOPLEFT', 16, -16)
    title:SetText('EorzeaUI')
    local note = Widgets.Text(panel, 13, C.text)
    note:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -10)
    note:SetText('Settings live in their own window, also opened with /ffui.')
    local open = Widgets.Button(panel, 'Open settings', function()
        Config.Toggle('general')
    end, { variant = 'primary' })
    open:SetPoint('TOPLEFT', note, 'BOTTOMLEFT', 0, -14)
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
