local addonName, EUI = ...

-- The settings window (/ffui config), in the in-game look of the settings design: a navy panel
-- with a silver sprig off two corners, a header with search, the page list on the left grouped as
-- EUI.Config.PAGES (config/options.lua), the page's rows in a scrolling column that runs to the
-- window's right edge, and a footer whose help line follows the hovered row. Options marked
-- reload are read when the frames are built; changing one lists it in the footer status.

local Config = EUI.Config
local Widgets = EUI.Widgets
local Style = EUI.Style
local Settings = EUI.Settings
local C = Widgets.COLORS

local WIDTH, HEIGHT = 1000, 800
local HEADER, FOOTER, SIDEBAR = 48, 44, 200
-- Content inset from the page list (room for the row cursor), and the gap before the scrollbar.
local PAD, SCROLL_GAP = 48, 32
local CONTENT_WIDTH = WIDTH - SIDEBAR - PAD - SCROLL_GAP
local ROW_HEIGHT = 30
-- Controls start in one column after the page's longest label, at least this far in.
local LABEL_WIDTH = 220
local LABEL_GAP = 36
local SECTION_GAP = 18
local SCROLL_STEP = 60
local SPRIG_SIZE, SPRIG_ORIGIN = 128, 24
local SPRIG_TINT = '#B8C4D6FF'

local window
local pages = {}
local navButtons = {}
local currentPage
local searching = false
-- The search results' scroll child.
local results
-- The row the hover bar and cursor are on, and its help line text.
local hotRow
-- Button rows with an active() button, refreshed on every change.
local activeRows = {}

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

-- 'Palette, Fonts', or the first MAX_NAMED and a count of the rest.
local function summarize(labels)
    if #labels <= MAX_NAMED then
        return table.concat(labels, ', ')
    end
    local named = {}
    for i = 1, MAX_NAMED do
        named[i] = labels[i]
    end
    return string.format('%s and %d more', table.concat(named, ', '), #labels - MAX_NAMED)
end

-- Labels of options changed in combat that wait for it to end, in change order.
local combatLabels = {}

-- The footer status: options waiting for a reload (gold) and for combat to end (red).
local function updateReloadBar()
    if not window then
        return
    end
    local labels = pendingLabels()
    window.reloadLabels = labels
    window.combatLabels = combatLabels
    local parts = {}
    if #labels > 0 then
        parts[#parts + 1] = '|cfff0ddb3Reload to apply \194\183 ' .. summarize(labels) .. '|r'
    end
    if #combatLabels > 0 then
        parts[#parts + 1] = '|cffff7a7aAfter combat \194\183 ' .. summarize(combatLabels) .. '|r'
    end
    window.status:SetText(table.concat(parts, '    '))
    window.reloadButton:SetVariant(#labels > 0 and 'gold' or 'default')
    -- Every change passes here; the section and page resets follow it.
    local built = currentPage and pages[currentPage]
    for _, header in ipairs(built and built.headers or {}) do
        header:Refresh()
    end
    for _, group in ipairs(activeRows) do
        group:Refresh()
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

-- The help line shows this while nothing hovered has a tip.
local IDLE_HELP = "I'm here to help explain!"

local function setHelp(text)
    if window then
        window.help:SetText((text and text ~= '') and text or IDLE_HELP)
    end
end

-- Moves the hover bar and cursor to holder (a row from makeHot); its tip becomes the help line.
local function setHot(holder)
    if hotRow == holder then
        return
    end
    if hotRow then
        hotRow:SetHot(false)
    end
    hotRow = holder
    if holder then
        holder:SetHot(true)
        setHelp(rawget(holder, 'tip'))
    end
end

-- Control spec for one registry item; item fields as documented in config/options.lua.
-- spec.row.holder is set once the row exists, so parts of the control can claim the hover.
local function bind(item)
    local spec = {
        label = item.label,
        tip = item.tip,
        choices = item.choices,
        min = item.min, max = item.max, step = item.step, format = item.format, range = item.range,
        alpha = item.alpha,
        row = {},
    }
    spec.onHelp = function(text)
        setHot(spec.row.holder)
        setHelp(text)
    end
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

-- An item's value as its control shows it: the choice's name, On/Off, the slider's text, a hex.
local function describe(item, value)
    if item.kind == 'toggle' then
        if item.invert then
            value = not value
        end
        return value and 'On' or 'Off'
    end
    for _, choice in ipairs(item.choices or {}) do
        if choice[1] == value then
            return choice[2]
        end
    end
    if item.kind == 'slider' and type(value) == 'number' then
        if type(item.format) == 'function' then
            return item.format(value)
        end
        return string.format(item.format or '%d', value)
    end
    if type(value) == 'string' and value:match('^#%x+$') then
        return value:sub(2, 7)
    end
    return tostring(value)
end

local function currentValue(item)
    if item.get then
        return item.get()
    end
    return Settings.Get(itemPath(item))
end

local function defaultValue(item)
    if item.defaultValue then
        return item.defaultValue()
    end
    local path = itemPath(item)
    return path and Settings.Default(path)
end

-- A reset over items: { isDefault(), reset(), changes() -> { { label, from, to }, ... } }, or nil
-- when none of them can reset.
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
        changes = function()
            local changes = {}
            for _, item in ipairs(resettable) do
                if not itemIsDefault(item) then
                    changes[#changes + 1] = {
                        label = item.label or '',
                        from = describe(item, currentValue(item)),
                        to = describe(item, defaultValue(item)),
                    }
                end
            end
            return changes
        end,
    }
end

-- Every page's items, built fresh; colour items cover the current palette.
local function allItems()
    local items = {}
    for _, page in ipairs(Config.PAGES) do
        local list = page.items
        if type(list) == 'function' then
            list = list()
        end
        for _, item in ipairs(list) do
            items[#items + 1] = item
        end
    end
    return items
end

function Config.AllDefault()
    local reset = resetFor(allItems())
    return not reset or reset.isDefault()
end

function Config.ResetAll()
    local reset = resetFor(allItems())
    if reset then
        reset.reset()
    end
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

-- Claims the hover for holder while the mouse is over it or any control inside it. Moving
-- between holder and its controls leaves one and enters the other, so the row stays lit.
local function hookHover(frame, holder)
    if frame:IsMouseEnabled() then
        frame:HookScript('OnEnter', function()
            setHot(holder)
        end)
        frame:HookScript('OnLeave', function()
            if hotRow == holder then
                holder:SetHot(false)
                hotRow = nil
                setHelp('')
            end
        end)
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        hookHover(child, holder)
    end
end

-- How far the cursor and the highlight start before their label, and how far the highlight fades
-- out past the label's end.
local CURSOR_LEAD, HOT_LEAD, HOT_TAIL = 14, 7, 24

-- Gives holder a highlight sized to label (a font string labelLeft in from holder's left edge)
-- and the hand cursor in the gutter; tip shows in the footer while it is hot. The highlight holds
-- its tint over most of the label and fades out just past it. cursorLeft (default labelLeft): the
-- left edge the cursor points at, for rows with art before the label.
local function makeHot(holder, tip, label, labelLeft, cursorLeft)
    holder.tip = tip
    labelLeft = labelLeft or 0
    local hover = Widgets.Accent().hover
    local reach = HOT_LEAD + math.ceil(label:GetStringWidth())
    local solid = Widgets.Solid(holder, 'BACKGROUND', hover, 2)
    solid:SetPoint('TOPLEFT', labelLeft - HOT_LEAD, -3)
    solid:SetPoint('BOTTOMLEFT', labelLeft - HOT_LEAD, 3)
    solid:SetWidth(reach * 0.8)
    local fade = Widgets.Solid(holder, 'BACKGROUND', '#FFFFFFFF', 2)
    fade:SetPoint('TOPLEFT', solid, 'TOPRIGHT')
    fade:SetPoint('BOTTOMLEFT', solid, 'BOTTOMRIGHT')
    fade:SetWidth(reach * 0.2 + HOT_TAIL)
    Widgets.Gradient(fade, 'HORIZONTAL', hover, hover:sub(1, 7) .. '00')
    solid:Hide()
    fade:Hide()
    local cursor = Widgets.Cursor(holder)
    cursor:SetPoint('RIGHT', holder, 'LEFT', (cursorLeft or labelLeft) - CURSOR_LEAD + 4, 0)
    Widgets.ShowCursor(cursor, false)
    function holder:SetHot(on)
        solid:SetShown(on)
        fade:SetShown(on)
        Widgets.ShowCursor(cursor, on)
    end
    holder:EnableMouse(true)
    hookHover(holder, holder)
end

---------------------------------------------------------------------------------------------
-- Rows

-- The in-game art an indicator draws, centred in a dark glass tile; pieces as
-- EUI.Indicators.Samples, plus fill (a colour block). Wide enough for the AFK and DND badges.
local ART_TILE_WIDTH, ART_GAP = 100, 6

local function artTile(parent, pieces)
    local tile = CreateFrame('Frame', nil, parent)
    tile:SetSize(ART_TILE_WIDTH, 32)
    Widgets.Well(tile, 7)
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

-- A settings row: optional art tile, the label, the control in the column after the labels.
-- spec (optional): the control's spec; setting through it refreshes the whole row.
local function row(parent, item, control, spec)
    local holder = CreateFrame('Frame', nil, parent)
    local height = item.art and 38 or ROW_HEIGHT
    holder:SetSize(CONTENT_WIDTH, height)
    local left = 0
    if item.art then
        local tile = artTile(holder, item.art())
        tile:SetPoint('LEFT', 0, 0)
        left = ART_TILE_WIDTH + 16
    end
    local label = Widgets.Text(holder, 14, C.text)
    label:SetPoint('LEFT', left, 0)
    label:SetText(item.label or '')
    control:SetParent(holder)
    -- Where the label ends and how wide the control is; buildPage picks the page's column.
    holder.labelRight = left + math.ceil(label:GetStringWidth())
    holder.controlWidth = control:GetWidth()
    function holder:SetColumn(x)
        control:ClearAllPoints()
        control:SetPoint('LEFT', holder, 'LEFT', x, 0)
    end
    holder:SetColumn(LABEL_WIDTH)
    makeHot(holder, item.tip, label, left, 0)
    if spec then
        spec.row.holder = holder
    end
    function holder:Refresh()
        control:Refresh()
        local enabled = not item.enabled or item.enabled()
        setEnabled(control, enabled)
        local alpha = enabled and 1 or 0.4
        -- Indicator rows dim while their indicator is off.
        if item.art and item.path and not Settings.Get(item.path) then
            alpha = 0.6
        end
        label:SetAlpha(alpha)
        control:SetAlpha(alpha)
    end
    if spec then
        local set = spec.set
        spec.set = function(value)
            set(value)
            holder:Refresh()
        end
    end
    return holder
end

-- Column titles over the scale table.
local SCALE_LABEL, SCALE_SLIDER, SCALE_FINAL = 220, 290, 70

local function scaleColumns(parent)
    local holder = CreateFrame('Frame', nil, parent)
    holder:SetSize(CONTENT_WIDTH, 22)
    local function column(text, x, width)
        local label = Widgets.Text(holder, 10, C.faint, 'display')
        label:SetText(text)
        label:SetPoint('BOTTOMLEFT', x, 4)
        if width then
            label:SetWidth(width)
            label:SetJustifyH('RIGHT')
        end
    end
    column('OWN', SCALE_LABEL)
    column('FINAL', SCALE_LABEL + SCALE_SLIDER + 14, SCALE_FINAL)
    function holder:Refresh() end
    return holder
end

-- A scale table row: name, slider and value, then the final scale.
local function scaleRow(parent, item)
    local holder = CreateFrame('Frame', nil, parent)
    holder:SetSize(CONTENT_WIDTH, ROW_HEIGHT)
    local label = Widgets.Text(holder, 14, C.text)
    label:SetPoint('LEFT', 0, 0)
    label:SetText(item.label)
    local spec = bind(item)
    spec.width = SCALE_SLIDER
    local slider = Widgets.Slider(holder, spec)
    slider:SetPoint('LEFT', SCALE_LABEL, 0)
    local final = Widgets.Text(holder, 14, C.dim)
    final:SetPoint('LEFT', SCALE_LABEL + SCALE_SLIDER + 14, 0)
    final:SetWidth(SCALE_FINAL)
    final:SetJustifyH('RIGHT')
    makeHot(holder, item.tip, label, 0)
    spec.row.holder = holder
    function holder:Refresh()
        slider:Refresh()
        local value = item.final()
        final:SetText(string.format('%.2f\195\151', value))
        final:SetTextColor(Style.Color(math.abs(value - 1) < 0.001 and C.dim or Widgets.Accent().text))
        local enabled = not item.enabled or item.enabled()
        setEnabled(slider, enabled)
        label:SetAlpha(enabled and 1 or 0.4)
        slider:SetAlpha(enabled and 1 or 0.4)
    end
    return holder
end

-- A font row: name, a sample in the chosen font inside a dark glass frame, and the font list.
local function fontRow(parent, item)
    local holder = CreateFrame('Frame', nil, parent)
    holder:SetSize(CONTENT_WIDTH, 40)
    local label = Widgets.Text(holder, 14, C.text)
    label:SetPoint('LEFT', 0, 0)
    label:SetText(item.label)
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
    sample:SetPoint('LEFT', 150, 0)
    sample:SetPoint('RIGHT', dropdown, 'LEFT', -18, 0)
    sample:SetHeight(30)
    Widgets.Well(sample, 8)
    local text = sample:CreateFontString(nil, 'OVERLAY')
    text:SetPoint('LEFT', 14, 0)
    text:SetPoint('RIGHT', -14, 0)
    text:SetJustifyH('LEFT')
    text:SetWordWrap(false)
    makeHot(holder, item.tip, label, 0)
    spec.row.holder = holder
    function holder:Refresh()
        dropdown:Refresh()
        Style.SetFont(text, spec.get(), 16, 'OUTLINE')
        text:SetTextColor(Style.Color(C.bright))
        text:SetText(item.preview)
    end
    return holder
end

-- Colour cells two to a row, each a brush stroke of its colour.
local COLOR_COLUMNS, COLOR_GAP = 2, 40

local function colorGrid(parent, items)
    local holder = CreateFrame('Frame', nil, parent)
    local cellWidth = (CONTENT_WIDTH - COLOR_GAP * (COLOR_COLUMNS - 1)) / COLOR_COLUMNS
    local cells = {}
    for i, item in ipairs(items) do
        local spec = bind(item)
        local cell = Widgets.Color(holder, cellWidth, spec, i)
        local column, line = (i - 1) % COLOR_COLUMNS, math.floor((i - 1) / COLOR_COLUMNS)
        cell:SetPoint('TOPLEFT', column * (cellWidth + COLOR_GAP), -line * 32)
        makeHot(cell, item.tip, rawget(cell, 'labelText'), 104)
        spec.row.holder = cell
        cells[#cells + 1] = cell
    end
    holder:SetSize(CONTENT_WIDTH, math.ceil(#items / COLOR_COLUMNS) * 32)
    function holder:Refresh()
        for _, cell in ipairs(cells) do
            cell:Refresh()
        end
    end
    return holder
end

-- The swatches a palette card shows, as palette keys, and their stroke lengths and offsets.
local CARD_KEYS = { 'hp', 'cast', 'powerColors.0', 'name', 'combo' }
local CARD_LENGTHS = { 196, 176, 188, 168, 182 }
local CARD_OFFSETS = { 0, 8, 3, 12, 5 }

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

-- One glass card per palette: its colours as a vertical stack of brush strokes, its name and
-- whether it is in use.
local CARD_WIDTH, CARD_HEIGHT, CARD_GAP = 240, 156, 22

local function paletteCards(parent, item)
    local holder = CreateFrame('Frame', nil, parent)
    local spec = bind(item)
    local cards = {}
    local A = Widgets.Accent()
    for i, choice in ipairs(item.choices) do
        local card = CreateFrame('Button', nil, holder)
        card:SetSize(CARD_WIDTH, CARD_HEIGHT)
        card:SetPoint('TOPLEFT', (i - 1) * (CARD_WIDTH + CARD_GAP), -4)
        local fill = Widgets.Rounded(card, 'BACKGROUND', 10)
        fill:SetAllPoints()
        Widgets.Gradient(fill, 'VERTICAL', '#0A142D66', '#3A5A9026')
        local lit = Widgets.Rounded(card, 'BACKGROUND', 10, A.accent:sub(1, 7) .. '22', false, 1)
        lit:SetAllPoints()
        lit:SetBlendMode('ADD')
        local rim = Widgets.Rounded(card, 'BORDER', 10, nil, true)
        rim:SetAllPoints()
        local strip = {}
        for k, key in ipairs(CARD_KEYS) do
            local stroke = Widgets.Brush(card, k + i, CARD_LENGTHS[k], 24, paletteColor(choice[1], key))
            stroke:SetPoint('TOPLEFT', 16 + CARD_OFFSETS[k], -12 - (k - 1) * 20)
            strip[k] = stroke
        end
        local name = Widgets.Text(card, 15, C.title, 'display')
        name:SetPoint('BOTTOMLEFT', 16, 12)
        name:SetText(choice[2])
        local note = Widgets.Text(card, 13, C.dim)
        note:SetPoint('BOTTOMRIGHT', -16, 13)
        local cursor = Widgets.Cursor(card)
        cursor:SetPoint('RIGHT', card, 'LEFT', 4, 26)
        cards[#cards + 1] = { button = card, value = choice[1], strip = strip, rim = rim, lit = lit, note = note,
            cursor = cursor, hovered = false }
        local entry = cards[#cards]
        card:SetScript('OnEnter', function()
            entry.hovered = true
            holder:Refresh()
            setHot(nil)
            setHelp(choice[3] or item.tip)
        end)
        card:SetScript('OnLeave', function()
            entry.hovered = false
            holder:Refresh()
            setHelp('')
        end)
        card:SetScript('OnClick', EUI.Guard('config palette', function()
            if spec.get() ~= choice[1] then
                Widgets.Sound('IG_MAINMENU_OPTION')
            end
            spec.set(choice[1])
            holder:Refresh()
        end))
    end
    holder:SetSize(CONTENT_WIDTH, CARD_HEIGHT + 12)
    function holder:Refresh()
        local chosen = spec.get()
        local built = Config.style and Config.style.palette
        for _, card in ipairs(cards) do
            local on = card.value == chosen
            card.rim:SetVertexColor(Style.Color((on and A.rimHot) or (card.hovered and '#AAD7FF80') or '#AAD7FF40'))
            card.lit:SetShown(on)
            Widgets.ShowCursor(card.cursor, on)
            if card.value == built then
                card.note:SetText(on and 'Active' or 'Until Reload')
                card.note:SetTextColor(Style.Color(A.text))
            else
                card.note:SetText(on and 'After Reload' or '')
                card.note:SetTextColor(Style.Color(C.goldText))
            end
            for k, key in ipairs(CARD_KEYS) do
                card.strip[k]:SetVertexColor(Style.Color(paletteColor(card.value, key)))
            end
        end
    end
    return holder
end

-- A row of glass buttons in the control column.
local function buttonRow(parent, item)
    local group = CreateFrame('Frame', nil, parent)
    local buttons, defs = {}, {}
    for _, def in ipairs(item.buttons) do
        local button
        button = Widgets.Button(group, def.label, function(self)
            if def.confirm and not rawget(self, 'armed') then
                self.armed = true
                self:SetLabel('Click Again')
                C_Timer.After(3, function()
                    if rawget(self, 'armed') then
                        self.armed = nil
                        self:SetLabel(def.label)
                    end
                end)
                return
            end
            self.armed = nil
            if def.confirm then
                self:SetLabel(def.label)
            end
            def.run(self)
            updateReloadBar()
        end, { variant = def.variant, icon = def.icon })
        if def.tip then
            Widgets.SetTooltip(button, def.label, def.tip)
            if item.bare then
                button:HookScript('OnEnter', function() setHelp(def.tip) end)
                button:HookScript('OnLeave', function() setHelp('') end)
            end
        end
        buttons[#buttons + 1] = button
        defs[#buttons] = def
    end
    -- Bare rows give every button the widest one's width.
    local width = 0
    if item.bare then
        for _, button in ipairs(buttons) do
            width = math.max(width, button:GetWidth())
        end
        for _, button in ipairs(buttons) do
            button:SetWidth(width)
        end
    end
    function group:Refresh()
        local x = 0
        for i, button in ipairs(buttons) do
            if defs[i].labelFn then
                button:SetLabel(defs[i].labelFn())
            end
            if defs[i].active then
                button:SetActive(defs[i].active())
            end
            button:ClearAllPoints()
            button:SetPoint('LEFT', group, 'LEFT', x, 0)
            x = x + button:GetWidth() + 10
        end
        group:SetSize(math.max(1, x - 10), 30)
    end
    group:Refresh()
    for _, def in ipairs(defs) do
        if def.active then
            activeRows[#activeRows + 1] = group
            break
        end
    end
    if not item.bare then
        return row(parent, item, group)
    end
    local holder = CreateFrame('Frame', nil, parent)
    holder:SetSize(CONTENT_WIDTH, ROW_HEIGHT + 8)
    group:SetParent(holder)
    group:SetPoint('LEFT', holder, 'LEFT', 0, 0)
    function holder:Refresh()
        group:Refresh()
    end
    return holder
end

---------------------------------------------------------------------------------------------
-- About

local function addonMetadata(field)
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return get and get(addonName, field)
end

local function hero(parent)
    local holder = CreateFrame('Frame', nil, parent)
    holder:SetSize(CONTENT_WIDTH, 84)
    local icon = holder:CreateTexture(nil, 'ARTWORK')
    icon:SetTexture(string.format('Interface\\AddOns\\%s\\Media\\AddonIcon', addonName))
    icon:SetSize(72, 72)
    icon:SetPoint('LEFT', 0, 0)
    local title = Widgets.Text(holder, 28, C.title, 'display')
    title:SetPoint('BOTTOMLEFT', icon, 'RIGHT', 18, 2)
    title:SetText(addonName)
    local parts = {}
    local version = addonMetadata('Version')
    if version then
        parts[#parts + 1] = 'Ver. ' .. version
    end
    if GetBuildInfo then
        parts[#parts + 1] = 'Client ' .. tostring((GetBuildInfo()))
    end
    local line = Widgets.Text(holder, 14, '#A9B6CBFF')
    line:SetPoint('TOPLEFT', icon, 'RIGHT', 18, -4)
    line:SetText(table.concat(parts, ' \194\183 '))
    local rule = Widgets.FadeLine(holder, '#96B4E18C', 'end')
    rule:SetPoint('LEFT', title, 'RIGHT', 18, 0)
    rule:SetPoint('RIGHT', holder, 'RIGHT', 0, 0)
    function holder:Refresh() end
    return holder
end

local function command(parent, item)
    local holder = CreateFrame('Frame', nil, parent)
    holder:SetSize(CONTENT_WIDTH, ROW_HEIGHT)
    -- Both start on the first line's centre; long text wraps and grows the row.
    local lineTop = -(ROW_HEIGHT - 14) / 2
    local cmd = Widgets.Text(holder, 14, Widgets.Accent().text, 'semibold')
    cmd:SetPoint('TOPLEFT', 0, lineTop)
    cmd:SetText(item.command)
    local text = Widgets.Text(holder, 14, C.body)
    text:SetPoint('TOPLEFT', 200, lineTop)
    text:SetWidth(CONTENT_WIDTH - 200)
    text:SetJustifyH('LEFT')
    text:SetWordWrap(true)
    text:SetSpacing(3)
    text:SetText(item.text)
    holder:SetHeight(math.max(ROW_HEIGHT, math.ceil(text:GetStringHeight()) - 2 * lineTop))
    makeHot(holder, 'Type it in chat.', cmd, 0)
    function holder:Refresh() end
    return holder
end

-- A question that opens to its answer on a diamond marker; relayout() restacks the page.
local function faq(parent, item, relayout)
    local holder = CreateFrame('Frame', nil, parent)
    local A = Widgets.Accent()
    local button = CreateFrame('Button', nil, holder)
    button:SetPoint('TOPLEFT')
    button:SetPoint('TOPRIGHT')
    button:SetHeight(ROW_HEIGHT)
    local marker = Widgets.Pip(button, 11, '#6C7A91FF', false)
    marker:SetPoint('LEFT', 0, 0)
    local label = Widgets.Text(button, 14, C.text)
    label:SetPoint('LEFT', 22, 0)
    label:SetText(item.label)
    local answer = Widgets.Text(holder, 14, '#A9B6CBFF')
    answer:SetPoint('TOPLEFT', 22, -ROW_HEIGHT)
    answer:SetWidth(620)
    answer:SetWordWrap(true)
    answer:SetSpacing(3)
    answer:SetText(item.text)
    local open = false
    local function layout()
        answer:SetShown(open)
        marker:SetVertexColor(Style.Color(open and A.accent or '#6C7A91FF'))
        holder:SetSize(CONTENT_WIDTH, open and (ROW_HEIGHT + math.ceil(answer:GetStringHeight()) + 10) or ROW_HEIGHT)
        holder.tip = open and 'Click to close.' or 'Click to open.'
    end
    button:SetScript('OnClick', EUI.Guard('config faq', function()
        open = not open
        Widgets.Sound('IG_MAINMENU_OPTION')
        layout()
        setHelp(holder.tip)
        relayout()
    end))
    layout()
    makeHot(holder, holder.tip, label, 22, 0)
    function holder:Refresh() end
    return holder
end

---------------------------------------------------------------------------------------------
-- Pages

-- Each builder returns the control and the gap above it (default 0).
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
        if item.style == 'font' then
            return fontRow(parent, item)
        end
        local spec = bind(item)
        return row(parent, item, Widgets.Rail(parent, spec), spec)
    end,
    slider = function(parent, item)
        if item.final then
            return scaleRow(parent, item)
        end
        local spec = bind(item)
        spec.width = item.width
        spec.valueColor = item.emphasis and C.bright or nil
        return row(parent, item, Widgets.Slider(parent, spec), spec)
    end,
    buttons = buttonRow,
    palettes = paletteCards,
    hero = hero,
    command = command,
    faq = faq,
}

-- Stacks a page's entries: rows flush, sections apart.
local function layoutPage(built)
    local y = 18 + 40
    for i, entry in ipairs(built.entries) do
        if i > 1 then
            y = y + (entry.header and SECTION_GAP or entry.gap)
        end
        entry.control:ClearAllPoints()
        entry.control:SetPoint('TOPLEFT', PAD, -y)
        entry.top = y
        y = y + entry.control:GetHeight() + (entry.header and 2 or 0)
    end
    built.frame:SetHeight(y + 24)
end

local function buildPage(page)
    local child = CreateFrame('Frame', nil, window.scroll)
    child:SetWidth(WIDTH - SIDEBAR - 2)
    -- The page title on a rule fading right.
    local title = Widgets.Text(child, 22, C.title, 'display')
    title:SetPoint('TOPLEFT', PAD, -18)
    title:SetText(page.label)
    local rule = Widgets.FadeLine(child, '#96B4E18C', 'end')
    rule:SetPoint('LEFT', title, 'RIGHT', 14, 0)
    rule:SetPoint('RIGHT', child, 'LEFT', PAD + CONTENT_WIDTH, 0)
    -- entries: { control, gap, header, first, last (item indexes), top }.
    local built = { frame = child, controls = {}, headers = {}, entries = {} }
    local items = page.items
    if type(items) == 'function' then
        items = items()
    end
    built.items = items
    local function relayout()
        layoutPage(built)
    end
    local function add(control, first, last, gap, header)
        built.entries[#built.entries + 1] = { control = control, first = first, last = last, gap = gap or 0, header = header }
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
                add(build(child, item, section), i, i, 0, true)
            elseif build then
                local control, gap = build(child, item, relayout)
                add(control, i, i, gap)
            else
                EUI.LogOnce('config:kind:' .. tostring(item.kind), 'config: unknown item kind %s', tostring(item.kind))
            end
            i = i + 1
        end
    end
    -- One control column per page: past the longest label, but never pushing a control off the edge.
    local labelRight, controlWidth = 0, 0
    for _, entry in ipairs(built.entries) do
        if rawget(entry.control, 'SetColumn') then
            labelRight = math.max(labelRight, entry.control.labelRight)
            controlWidth = math.max(controlWidth, entry.control.controlWidth)
        end
    end
    local column = math.min(math.max(LABEL_WIDTH, labelRight + LABEL_GAP), CONTENT_WIDTH - controlWidth)
    for _, entry in ipairs(built.entries) do
        if rawget(entry.control, 'SetColumn') then
            entry.control:SetColumn(column)
        end
    end
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

local function pageByKey(key)
    for _, page in ipairs(Config.PAGES) do
        if page.key == key then
            return page
        end
    end
end

-- Fades a freshly shown page in over 80ms.
local function fadeIn(frame)
    window.fadeTarget, window.fadeTime = frame, 0
    frame:SetAlpha(0)
    window.fader:Show()
end

-- fade: fade the page in (a switch from the page list). Any fade still running stops first, so a
-- page is never left part-faded by a close or a second switch.
local function showPage(key, fade)
    Widgets.CloseMenus()
    if results then
        results:Hide()
    end
    window.fader:Hide()
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
            setHot(nil)
            setHelp('')
            built.frame:SetAlpha(1)
            if fade then
                fadeIn(built.frame)
            end
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

local RESULT_HEIGHT = 44
local openResult

local function resultRow(index)
    local button = results.rows[index]
    if button then
        return button
    end
    button = CreateFrame('Button', nil, results)
    button:SetSize(CONTENT_WIDTH, RESULT_HEIGHT)
    local bar = Widgets.HoverBar(button)
    bar:SetPoint('TOPLEFT', -14, -4)
    bar:SetPoint('BOTTOMLEFT', -14, 4)
    bar:SetWidth(420)
    bar:Hide()
    local cursor = Widgets.Cursor(button)
    cursor:SetPoint('RIGHT', button, 'LEFT', -10, 0)
    Widgets.ShowCursor(cursor, false)
    button.label = Widgets.Text(button, 14, C.text)
    button.label:SetPoint('TOPLEFT', 0, -6)
    button.crumb = Widgets.Text(button, 13, C.dim)
    button.crumb:SetPoint('TOPLEFT', button.label, 'BOTTOMLEFT', 0, -4)
    button:SetScript('OnEnter', function(self)
        bar:Show()
        Widgets.ShowCursor(cursor, true)
        local match = rawget(self, 'match')
        setHelp(match and ('Opens ' .. match.crumb .. '.') or '')
    end)
    button:SetScript('OnLeave', function()
        bar:Hide()
        Widgets.ShowCursor(cursor, false)
        setHelp('')
    end)
    button:SetScript('OnClick', EUI.Guard('config search result', function(self)
        openResult(rawget(self, 'match'))
    end))
    results.rows[index] = button
    return button
end

local function showResults(query)
    if not results then
        results = CreateFrame('Frame', nil, window.scroll)
        results:SetWidth(WIDTH - SIDEBAR - 2)
        results.rows = {}
        results.title = Widgets.Text(results, 22, C.title, 'display')
        results.title:SetPoint('TOPLEFT', PAD, -18)
        results.title:SetText('Search')
        results.count = Widgets.Text(results, 14, C.dim)
        results.count:SetPoint('LEFT', results.title, 'RIGHT', 16, -2)
    end
    for _, built in pairs(pages) do
        built.frame:Hide()
    end
    setHot(nil)
    local matches = searchMatches(query)
    for i, match in ipairs(matches) do
        local button = resultRow(i)
        button.match = match
        button.label:SetText(match.label)
        button.crumb:SetText(match.crumb)
        button:ClearAllPoints()
        button:SetPoint('TOPLEFT', PAD, -(66 + (i - 1) * (RESULT_HEIGHT + 2)))
        button:Show()
    end
    for i = #matches + 1, #results.rows do
        results.rows[i]:Hide()
    end
    results.count:SetText(#matches == 0 and string.format('Nothing matches \226\128\156%s\226\128\157.', query)
        or (#matches == 1 and '1 setting' or string.format('%d settings', #matches)))
    results:SetHeight(84 + #matches * (RESULT_HEIGHT + 2))
    window.scroll:SetScrollChild(results)
    results:Show()
    setHelp('')
    for _, button in pairs(navButtons) do
        button:SetCurrent(false)
    end
    scrollTo(0)
end

local function setSearching(on)
    searching = on
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
    Widgets.Sound('IG_ABILITY_PAGE_TURN')
    showPage(match.page.key)
    for _, entry in ipairs(pages[match.page.key].entries) do
        if entry.first and entry.first <= match.index and match.index <= entry.last then
            scrollTo(entry.top - 60)
            flash(entry.control)
            if rawget(entry.control, 'SetHot') then
                setHot(entry.control)
            end
            break
        end
    end
end

---------------------------------------------------------------------------------------------
-- The window

local function createNavButton(parent, page)
    local A = Widgets.Accent()
    local button = CreateFrame('Button', nil, parent)
    button:SetSize(SIDEBAR - 38, 32)
    local glassTex = Widgets.Rounded(button, 'BACKGROUND', 7)
    glassTex:SetTexture(Style.AssetPath('settings/glass8'))
    glassTex:SetAllPoints()
    if glassTex.SetTextureSliceMargins then
        glassTex:SetTextureSliceMargins(8, 8, 8, 8)
    end
    glassTex:SetVertexColor(Style.Color(A.tint))
    local hoverFill = Widgets.Rounded(button, 'BACKGROUND', 7, '#A0CDFF1A', false, 1)
    hoverFill:SetAllPoints()
    local rim = Widgets.Rounded(button, 'BORDER', 7, nil, true)
    rim:SetAllPoints()
    local bar = Widgets.HoverBar(button)
    bar:SetPoint('TOPLEFT', 2, -3)
    bar:SetPoint('BOTTOMRIGHT', button, 'BOTTOM', 20, 3)
    local cursor = Widgets.Cursor(button, 28, 18)
    cursor:SetPoint('RIGHT', button, 'LEFT', 2, 0)
    local icon = Widgets.Icon(button, page.icon, 16, '#AEBBD0FF')
    icon:SetPoint('LEFT', 12, 0)
    local label = Widgets.Text(button, 14, '#AEBBD0FF')
    label:SetPoint('LEFT', icon, 'RIGHT', 10, 0)
    label:SetText(page.label)
    local current, hovered = false, false
    local function paint()
        glassTex:SetShown(current)
        bar:SetShown(current)
        Widgets.ShowCursor(cursor, current)
        hoverFill:SetShown(hovered and not current)
        rim:SetVertexColor(Style.Color((current and A.rimHot) or (hovered and '#AAD7FF29') or '#00000000'))
        label:SetTextColor(Style.Color((current or hovered) and C.bright or '#AEBBD0FF'))
        icon:SetVertexColor(Style.Color((current and A.text) or (hovered and C.bright) or '#AEBBD0FF'))
    end
    function button:SetCurrent(on)
        current = on
        paint()
    end
    button:SetScript('OnEnter', function()
        hovered = true
        paint()
        setHelp(page.tip)
    end)
    button:SetScript('OnLeave', function()
        hovered = false
        paint()
        setHelp('')
    end)
    button:SetScript('OnClick', function()
        if searching then
            window.search:SetText('')
            window.search:ClearFocus()
            setSearching(false)
        end
        local switching = currentPage ~= page.key
        if switching then
            Widgets.Sound('IG_CHARACTER_INFO_TAB')
        end
        showPage(page.key, switching)
    end)
    paint()
    return button
end

local function createSidebar()
    local sidebar = CreateFrame('Frame', nil, window)
    sidebar:SetPoint('TOPLEFT', 1, -(HEADER + 1))
    sidebar:SetPoint('BOTTOMLEFT', 1, FOOTER + 1)
    sidebar:SetWidth(SIDEBAR - 1)
    local fill = Widgets.Solid(sidebar, 'BACKGROUND', '#FFFFFFFF')
    fill:SetAllPoints()
    Widgets.Gradient(fill, 'VERTICAL', '#02050C94', '#02050C61')
    local edge = Widgets.FadeLine(sidebar, '#96B4E166', 'both', true)
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
            local heading = Widgets.Text(sidebar, 12, C.faint, 'display')
            heading:SetPoint('TOPLEFT', 40, y)
            heading:SetText(group:upper())
            y = y - 20
        end
        local button = createNavButton(sidebar, page)
        button:SetPoint('TOPLEFT', 28, y)
        navButtons[page.key] = button
        y = y - 33
    end

    -- Bottom: drag handles on every frame, and every frame's demo at once.
    local controlHeading = Widgets.Text(sidebar, 12, C.faint, 'display')
    controlHeading:SetPoint('BOTTOM', sidebar, 'BOTTOMLEFT', SIDEBAR / 2, 86)
    controlHeading:SetText('FRAME CONTROL')
    local function sideToggle(label, bottom, spec, help)
        local title = Widgets.Text(sidebar, 14, C.body)
        title:SetText(label)
        local toggle = Widgets.Toggle(sidebar, spec)
        toggle.title = title
        toggle.bottom = bottom
        toggle:HookScript('OnEnter', function() setHelp(help) end)
        toggle:HookScript('OnLeave', function() setHelp('') end)
        return toggle
    end
    window.moveToggle = sideToggle('Move', 52, {
        get = function() return EUI.EditMode.unlocked end,
        set = function(value) EUI.EditMode.SetUnlocked(value) end,
    }, 'Show drag handles on every frame. Opening Edit Mode does the same; Reset Positions is on General.')
    window.demoToggle = sideToggle('Demo', 18, {
        get = function() return EUI.Demo.toggled end,
        set = function() EUI.Demo.Toggle() end,
    }, 'Fill every frame with sample data, whichever page is open (/ffui demo). Each page shows its own frames anyway.')
    -- Labels and toggles centred as one block under the heading; the toggles share a column 24px
    -- past the longer label.
    local labelWidth = math.ceil(math.max(window.moveToggle.title:GetStringWidth(),
        window.demoToggle.title:GetStringWidth()))
    local blockLeft = math.floor((SIDEBAR - (labelWidth + 24 + window.moveToggle:GetWidth())) / 2)
    for _, toggle in ipairs({ window.moveToggle, window.demoToggle }) do
        toggle.title:SetPoint('BOTTOMLEFT', blockLeft, toggle.bottom + 4)
        toggle:SetPoint('BOTTOMLEFT', blockLeft + labelWidth + 24, toggle.bottom)
    end
end

local function createHeader()
    local icon = window:CreateTexture(nil, 'ARTWORK')
    icon:SetTexture(string.format('Interface\\AddOns\\%s\\Media\\AddonIcon', addonName))
    icon:SetSize(30, 30)
    icon:SetPoint('LEFT', window, 'TOPLEFT', 14, -HEADER / 2)
    local title = Widgets.Text(window, 17, C.title, 'display')
    title:SetPoint('LEFT', icon, 'RIGHT', 12, 0)
    title:SetText(addonName)
    local rule = Widgets.FadeLine(window, '#96B4E180', 'both')
    rule:SetPoint('TOPLEFT', 1, -HEADER)
    rule:SetPoint('TOPRIGHT', -1, -HEADER)

    local close = CreateFrame('Button', nil, window)
    close:SetSize(28, 28)
    close:SetPoint('RIGHT', window, 'TOPRIGHT', -10, -HEADER / 2)
    local cross = Widgets.Text(close, 20, C.dim)
    cross:SetPoint('CENTER', 0, 1)
    cross:SetText('\195\151')
    close:SetScript('OnEnter', function() cross:SetTextColor(Style.Color(C.bright)) end)
    close:SetScript('OnLeave', function() cross:SetTextColor(Style.Color(C.dim)) end)
    close:SetScript('OnClick', function() window:Hide() end)
    Widgets.SetTooltip(close, 'Close', 'Escape also closes the window.')

    local search = Widgets.Input(window, { width = 220, height = 30, inset = 12 })
    search:SetPoint('RIGHT', close, 'LEFT', -10, 0)
    local placeholder = Widgets.Text(search, 14, '#6C7A91FF', 'regular', '')
    placeholder:SetPoint('LEFT', 12, 0)
    placeholder:SetText('Search')
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
            openResult(rawget(first, 'match'))
        end
        self:ClearFocus()
    end)
    window.search = search
end

local function createFooter()
    local rule = Widgets.FadeLine(window, '#96B4E180', 'both')
    rule:SetPoint('BOTTOMLEFT', 1, FOOTER)
    rule:SetPoint('BOTTOMRIGHT', -1, FOOTER)

    local footer = CreateFrame('Frame', nil, window)
    footer:SetPoint('BOTTOMLEFT', 1, 1)
    footer:SetPoint('BOTTOMRIGHT', -1, 1)
    footer:SetHeight(FOOTER - 1)
    local marker = footer:CreateTexture(nil, 'ARTWORK')
    marker:SetTexture(string.format('Interface\\AddOns\\%s\\Media\\Moogle', addonName))
    marker:SetSize(26, 26)
    marker:SetPoint('LEFT', 14, 0)

    local reload = Widgets.Button(footer, 'Reload', function()
        if InCombatLockdown() then
            EUI.Print('reload after combat')
            return
        end
        ReloadUI()
    end)
    reload:SetPoint('RIGHT', -14, 0)
    Widgets.SetTooltip(reload, 'Reload', function()
        if #(window.reloadLabels or {}) > 0 then
            return 'Reloads the interface so the changes waiting for it take effect.'
        end
        return 'Reloads the interface. Nothing is waiting for one.'
    end)
    window.reloadButton = reload

    local status = Widgets.Text(footer, 14, C.dim)
    status:SetPoint('RIGHT', reload, 'LEFT', -16, 0)
    status:SetJustifyH('RIGHT')
    window.status = status
    local help = Widgets.Text(footer, 14, '#A9B6CBFF')
    help:SetPoint('LEFT', marker, 'RIGHT', 12, 0)
    help:SetPoint('RIGHT', status, 'LEFT', -24, 0)
    help:SetText(IDLE_HELP)
    window.help = help

    -- The full lists while hovering the status.
    local summary = CreateFrame('Frame', nil, footer)
    summary:SetAllPoints(status)
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
            lines[#lines + 1] = '|cffff7a7aApplies once combat ends|r'
            for _, label in ipairs(waiting) do
                lines[#lines + 1] = label
            end
        end
        return #lines > 0 and table.concat(lines, '\n') or nil
    end)
end

local function createScroll()
    local scroll = CreateFrame('ScrollFrame', nil, window)
    scroll:SetPoint('TOPLEFT', SIDEBAR + 1, -(HEADER + 1))
    scroll:SetPoint('BOTTOMRIGHT', -1, FOOTER + 1)
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
    local bar = Widgets.Rounded(thumb, 'ARTWORK', 3, '#96B4E14D')
    bar:SetAllPoints()
    local dragging
    thumb:SetScript('OnEnter', function() bar:SetVertexColor(Style.Color('#96B4E180')) end)
    thumb:SetScript('OnLeave', function()
        if not dragging then
            bar:SetVertexColor(Style.Color('#96B4E14D'))
        end
    end)
    thumb:SetScript('OnMouseDown', function(self)
        local _, y = GetCursorPosition()
        dragging = { y = y / self:GetEffectiveScale(), offset = scroll:GetVerticalScroll() }
    end)
    thumb:SetScript('OnMouseUp', function(self)
        dragging = nil
        if not self:IsMouseOver() then
            bar:SetVertexColor(Style.Color('#96B4E14D'))
        end
    end)
    thumb:SetScript('OnUpdate', function(self)
        if not dragging then
            return
        end
        local _, y = GetCursorPosition()
        local travel = scroll:GetHeight() - self:GetHeight()
        if travel > 0 then
            local moved = dragging.y - y / self:GetEffectiveScale()
            scrollTo(dragging.offset + moved * scroll:GetVerticalScrollRange() / travel)
        end
    end)
    thumb:Hide()
    window.scrollThumb = thumb

    -- The search highlight, fading out.
    local flashFrame = CreateFrame('Frame', nil, scroll)
    local flashFill = Widgets.Rounded(flashFrame, 'BACKGROUND', 8, Widgets.Accent().accent:sub(1, 7) .. '2E')
    flashFill:SetAllPoints()
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

    -- Page change fade.
    local fader = CreateFrame('Frame', nil, window)
    fader:Hide()
    fader:SetScript('OnUpdate', function(self, elapsed)
        local target = window.fadeTarget
        window.fadeTime = window.fadeTime + elapsed
        local alpha = math.min(1, window.fadeTime / 0.08)
        target:SetAlpha(alpha)
        if alpha >= 1 then
            self:Hide()
        end
    end)
    window.fader = fader
end

-- The silver sprig off the top-left and bottom-right corners, hanging outside the frame.
local function createSprigs()
    for _, corner in ipairs({ { 'TOPLEFT', -1, 1, false }, { 'BOTTOMRIGHT', 1, -1, true } }) do
        local sprig = window:CreateTexture(nil, 'OVERLAY')
        sprig:SetTexture(Style.AssetPath('settings/sprig'))
        sprig:SetSize(SPRIG_SIZE, SPRIG_SIZE)
        sprig:SetVertexColor(Style.Color(SPRIG_TINT))
        if corner[4] then
            sprig:SetTexCoord(1, 0, 1, 0)
        end
        sprig:SetPoint(corner[1], window, corner[1], corner[2] * SPRIG_ORIGIN, corner[3] * SPRIG_ORIGIN)
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
    -- Accents follow the palette the frames were built with.
    Widgets.SetAccent(Config.style and Config.style.palette or Settings.Get('style'))
    Widgets.Panel(window)
    createSprigs()

    createHeader()
    createScroll()
    createSidebar()
    createFooter()

    local ok, opening = pcall(function()
        local group = window:CreateAnimationGroup()
        local fade = group:CreateAnimation('Alpha')
        fade:SetFromAlpha(0)
        fade:SetToAlpha(1)
        fade:SetDuration(0.14)
        fade:SetSmoothing('OUT')
        return group
    end)

    window:SetScript('OnShow', function()
        window:SetScale(Widgets.Scale())
        Config.HideLockPrompt()
        if searching then
            window.search:SetText('')
            setSearching(false)
        end
        showPage(currentPage or Config.PAGES[1].key)
        window.demoToggle:Refresh()
        window.moveToggle:Refresh()
        updateReloadBar()
        if ok and opening then
            opening:Play()
        end
        Widgets.Sound('IG_MAINMENU_OPEN')
    end)
    window:SetScript('OnHide', function()
        Widgets.CloseMenus()
        Widgets.HideTooltip()
        EUI.Demo.SetPageSections(nil)
        Config.ShowLockPrompt()
        Widgets.Sound('IG_MAINMENU_CLOSE')
    end)
end

---------------------------------------------------------------------------------------------
-- Lock prompt

local lockPrompt

local function createLockPrompt()
    local frame = CreateFrame('Frame', 'EorzeaUILockPrompt', UIParent)
    frame:SetSize(400, 100)
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
    local note = Widgets.Text(frame, 14, C.text)
    note:SetPoint('TOP', 0, -20)
    note:SetText('EorzeaUI frames are unlocked: drag them to move.')
    local lock = Widgets.Button(frame, 'Lock Frames', function()
        EUI.EditMode.SetUnlocked(false)
    end, { variant = 'primary', width = 140 })
    lock:SetPoint('BOTTOMRIGHT', frame, 'BOTTOM', -5, 16)
    Widgets.SetTooltip(lock, 'Lock Frames', 'Hide the drag handles and keep the frames where they are.')
    local settings = Widgets.Button(frame, 'Settings', function()
        Config.Toggle()
    end, { width = 140 })
    settings:SetPoint('BOTTOMLEFT', frame, 'BOTTOM', 5, 16)
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
        window.moveToggle:Refresh()
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
    local title = Widgets.Text(panel, 20, C.title, 'display')
    title:SetPoint('TOPLEFT', 16, -16)
    title:SetText('EorzeaUI')
    local note = Widgets.Text(panel, 14, C.text)
    note:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -10)
    note:SetText('Settings live in their own window, also opened with /ffui.')
    local open = Widgets.Button(panel, 'Open Settings', function()
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
