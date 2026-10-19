local _, EUI = ...

-- Controls for the settings window, in the settings design's look: Inter text, Cinzel titles,
-- rounded boxes from the 9-slice art in assets/settings (tools/settingsArt.py), crystal-cyan
-- accents. Each control is a frame whose :Refresh() re-reads its value; sizes are design pixels
-- (UI units at UIParent's scale, as Blizzard's own panels).

EUI.Widgets = {}
local Widgets = EUI.Widgets
local Style = EUI.Style

local C = {
    window = '#0C1424FF',
    bar = '#0A1120FF',
    main = '#0E1729FF',
    input = '#0A1120FF',
    deep = '#070C16FF',
    line = '#A0B9DC38',
    lineSoft = '#A0B9DC24',
    lineFaint = '#A0B9DC14',
    sectionLine = '#A0B9DC29',
    text = '#E6ECF5FF',
    bright = '#F2F5FAFF',
    body = '#A9B6CBFF',
    dim = '#8E9CB3FF',
    faint = '#7F8DA3FF',
    value = '#CFD8E6FF',
    accent = '#6FD3E8FF',
    accentText = '#8FDDEFFF',
    accentPale = '#DDF8FFFF',
    gold = '#C9A96AFF',
    goldText = '#F0DDB3FF',
    red = '#FF6B6BFF',
}
Widgets.COLORS = C

local FONTS = {
    regular = 'Inter-Regular.ttf',
    medium = 'Inter-Medium.ttf',
    semibold = 'Inter-SemiBold.ttf',
    display = 'Cinzel-Bold.ttf',
    mono = 'consola.ttf',
    friz = 'Fonts\\FRIZQT__.TTF',
}
Widgets.FONTS = FONTS

-- The settings fonts load while the loading screen is up, so the window's first SetFont finds them.
do
    local preload = CreateFrame('Frame')
    preload:Hide()
    for _, file in pairs(FONTS) do
        Style.SetFont(preload:CreateFontString(nil, 'OVERLAY'), file, 12, '')
    end
end

-- UIParent's own scale, shrunk only when the settings window (800 tall) would not fit.
local WINDOW_HEIGHT, SCREEN_MARGIN = 800, 48

function Widgets.Scale()
    local height = UIParent:GetHeight()
    if not height or height <= 0 then
        return 1
    end
    return math.min(1, (height - SCREEN_MARGIN) / WINDOW_HEIGHT)
end

-- Unsnapped, a line thinner than a screen pixel blends across two pixels instead of rounding
-- away to nothing.
local function unsnap(texture)
    if texture.SetSnapToPixelGrid then
        texture:SetSnapToPixelGrid(false)
        texture:SetTexelSnappingBias(0)
    end
end

function Widgets.Text(parent, size, color, weight, layer)
    local text = parent:CreateFontString(nil, layer or 'OVERLAY')
    Style.SetFont(text, FONTS[weight or 'regular'], size or 13, '')
    text:SetTextColor(Style.Color(color or C.text))
    text:SetJustifyH('LEFT')
    text:SetWordWrap(false)
    return text
end

-- Caps with the design's letter spacing: WoW has none, so a thin space (0.17em in Inter) follows
-- each character.
local THIN_SPACE = '\226\128\137'
function Widgets.Caps(text)
    local spaced = text:upper():gsub('([%z\1-\127\194-\244][\128-\191]*)', '%1' .. THIN_SPACE)
    return spaced:sub(1, -#THIN_SPACE - 1)
end

function Widgets.Solid(parent, layer, color, subLevel)
    local texture = parent:CreateTexture(nil, layer or 'ARTWORK', nil, subLevel)
    texture:SetColorTexture(Style.Color(color))
    unsnap(texture)
    return texture
end

local slicesMissing = false

-- A rounded rect of radius (3..12, 15) sliced so the corners keep their size; ring: the 1px edge only.
function Widgets.Rounded(parent, layer, radius, color, ring, subLevel)
    local texture = parent:CreateTexture(nil, layer or 'BACKGROUND', nil, subLevel)
    texture:SetTexture(Style.AssetPath(string.format('settings/%s%d', ring and 'ring' or 'fill', radius)))
    unsnap(texture)
    if texture.SetTextureSliceMargins then
        texture:SetTextureSliceMargins(radius, radius, radius, radius)
    elseif not slicesMissing then
        slicesMissing = true
        EUI.LogOnce('settings:slices', 'SetTextureSliceMargins missing; settings corners stretch')
    end
    texture:SetVertexColor(Style.Color(color))
    return texture
end

-- Fill and 1px border filling frame (either colour may be nil). box:SetColors(fill, border).
function Widgets.Box(frame, radius, fill, border, subLevel)
    local box = {}
    box.fill = Widgets.Rounded(frame, 'BACKGROUND', radius, fill or '#00000000', false, subLevel)
    box.fill:SetAllPoints()
    box.border = Widgets.Rounded(frame, 'BORDER', radius, border or '#00000000', true, subLevel)
    box.border:SetAllPoints()
    function box:SetColors(newFill, newBorder)
        self.fill:SetVertexColor(Style.Color(newFill or '#00000000'))
        self.border:SetVertexColor(Style.Color(newBorder or '#00000000'))
    end
    return box
end

function Widgets.Icon(parent, name, size, color, layer)
    local texture = parent:CreateTexture(nil, layer or 'ARTWORK')
    texture:SetTexture(Style.AssetPath('settings/' .. name))
    texture:SetSize(size, size)
    texture:SetVertexColor(Style.Color(color or C.text))
    return texture
end

function Widgets.Disc(parent, layer, size, color, subLevel)
    local texture = parent:CreateTexture(nil, layer or 'ARTWORK', nil, subLevel)
    texture:SetTexture(Style.AssetPath('settings/disc'))
    texture:SetSize(size, size)
    texture:SetVertexColor(Style.Color(color))
    return texture
end

-- A window-style panel: the main fill and the window edge.
function Widgets.Panel(frame, fill)
    return Widgets.Box(frame, 12, fill or C.window, C.line)
end

---------------------------------------------------------------------------------------------
-- Tooltip: Blizzard's tooltip border atlases on a frame of ours, greyscaled and tinted silver,
-- over a deep blue fill. Without NineSliceUtil or the atlases it falls back to a 1px edge.

local TOOLTIP_LAYOUT = 'TooltipDefaultLayout'
local TOOLTIP_BORDER = '#A6BCE3FF'
local TOOLTIP_PAD = 10
local TOOLTIP_MAX_WIDTH = 260
local tooltip

local function hasTooltipArt()
    return NineSliceUtil and NineSliceUtil.ApplyLayout and NineSliceUtil.GetLayout
        and NineSliceUtil.GetLayout(TOOLTIP_LAYOUT) and Style.HasAtlas('Tooltip-NineSlice-CornerTopLeft')
end

local function addFlatEdge(frame)
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
end

local function createTooltip()
    local frame = CreateFrame('Frame', 'EorzeaUITooltip', UIParent)
    frame:SetFrameStrata('TOOLTIP')
    frame:SetClampedToScreen(true)
    frame:Hide()

    local fill
    if hasTooltipArt() then
        -- Applied to the tooltip itself, so the pieces sit in its BACKGROUND/BORDER layers under the text.
        NineSliceUtil.ApplyLayout(frame, NineSliceUtil.GetLayout(TOOLTIP_LAYOUT))
        for _, piece in ipairs({ 'TopLeftCorner', 'TopRightCorner', 'BottomLeftCorner', 'BottomRightCorner',
            'TopEdge', 'BottomEdge', 'LeftEdge', 'RightEdge' }) do
            local texture = frame[piece]
            if texture then
                texture:SetDesaturated(true)
                texture:SetVertexColor(Style.Color(TOOLTIP_BORDER))
            end
        end
        -- The fill takes the place of the layout's Center, so it keeps Blizzard's inset.
        fill = frame.Center
    else
        fill = frame:CreateTexture(nil, 'BACKGROUND')
        fill:SetAllPoints()
        addFlatEdge(frame)
    end
    fill:SetColorTexture(1, 1, 1, 1)
    if not pcall(fill.SetGradient, fill, 'VERTICAL', CreateColor(0.02, 0.03, 0.06, 0.97), CreateColor(0.07, 0.10, 0.19, 0.97)) then
        fill:SetVertexColor(0.04, 0.06, 0.12, 0.97)
    end

    frame.title = Widgets.Text(frame, 13, TOOLTIP_BORDER, 'friz')
    frame.title:SetShadowColor(0, 0, 0, 0.9)
    frame.title:SetShadowOffset(1, -1)
    frame.title:SetPoint('TOPLEFT', TOOLTIP_PAD, -TOOLTIP_PAD)
    frame.body = Widgets.Text(frame, 12, C.text, 'friz')
    frame.body:SetShadowColor(0, 0, 0, 0.9)
    frame.body:SetShadowOffset(1, -1)
    frame.body:SetPoint('TOPLEFT', frame.title, 'BOTTOMLEFT', 0, -4)
    frame.body:SetWordWrap(true)
    frame.body:SetSpacing(2)
    return frame
end

local function showTooltip(owner, title, body)
    tooltip = tooltip or createTooltip()
    tooltip:SetScale(Widgets.Scale())
    tooltip.title:SetText(title or '')
    tooltip.body:SetText(body)
    tooltip.body:SetWidth(TOOLTIP_MAX_WIDTH)
    local unwrapped = tooltip.body.GetUnboundedStringWidth and tooltip.body:GetUnboundedStringWidth()
        or TOOLTIP_MAX_WIDTH
    local width = math.min(TOOLTIP_MAX_WIDTH, math.max(unwrapped, tooltip.title:GetStringWidth()))
    tooltip.body:SetWidth(width)
    tooltip:SetSize(width + TOOLTIP_PAD * 2,
        tooltip.title:GetStringHeight() + 4 + tooltip.body:GetStringHeight() + TOOLTIP_PAD * 2)
    tooltip:ClearAllPoints()
    tooltip:SetPoint('BOTTOMLEFT', owner, 'TOPRIGHT', 0, 0)
    tooltip:Show()
end
Widgets.ShowTooltip = showTooltip

function Widgets.HideTooltip()
    if tooltip then
        tooltip:Hide()
    end
end

-- body may be a function, read when the tooltip opens.
local function setTooltip(frame, title, body)
    if not body then
        return
    end
    frame:HookScript('OnEnter', function(self)
        local text = type(body) == 'function' and body() or body
        if text then
            showTooltip(self, title, text)
        end
    end)
    frame:HookScript('OnLeave', Widgets.HideTooltip)
end
Widgets.SetTooltip = setTooltip

---------------------------------------------------------------------------------------------
-- Buttons

local BUTTON_STYLES = {
    default = { fill = '#A0B9DC0F', border = '#A0B9DC42', text = C.text, hoverFill = '#A0B9DC1F', hoverBorder = '#A0B9DC73' },
    primary = { fill = '#6FD3E824', border = '#6FD3E899', text = C.accentPale, hoverFill = '#6FD3E83D', hoverBorder = '#6FD3E8B3' },
    gold = { fill = '#C9A96A1F', border = '#C9A96A99', text = C.goldText, hoverFill = '#C9A96A38', hoverBorder = '#C9A96AB3' },
    ghost = { text = C.body, hoverFill = '#A0B9DC14', hoverText = C.text },
}

-- opts = { variant (BUTTON_STYLES key), icon, width, height, size (text) }. onClick(button).
function Widgets.Button(parent, label, onClick, opts)
    opts = type(opts) == 'table' and opts or { width = opts }
    local look = BUTTON_STYLES[opts.variant or 'default']
    local height = opts.height or 34
    local button = CreateFrame('Button', nil, parent)
    local box = Widgets.Box(button, height < 26 and 11 or 8, look.fill, look.border)
    button.label = Widgets.Text(button, opts.size or 12, look.text, 'medium')
    local icon
    if opts.icon then
        icon = Widgets.Icon(button, opts.icon, opts.iconSize or 14, look.text)
    end
    local pad = opts.pad or 14
    local text = label or ''
    local function layout()
        button.label:ClearAllPoints()
        local textWidth = text ~= '' and button.label:GetStringWidth() or 0
        if icon then
            local gap = textWidth > 0 and 8 or 0
            local contentWidth = icon:GetWidth() + gap + textWidth
            icon:ClearAllPoints()
            icon:SetPoint('LEFT', button, 'CENTER', -contentWidth / 2, 0)
            button.label:SetPoint('LEFT', icon, 'RIGHT', gap, 0)
        else
            button.label:SetPoint('CENTER')
        end
        if not opts.width then
            local iconWidth = icon and (icon:GetWidth() + (textWidth > 0 and 8 or 0)) or 0
            button:SetSize(math.floor(pad * 2 + iconWidth + textWidth + 0.5), height)
        end
    end
    button.label:SetText(text)
    button:SetSize(opts.width or 60, height)
    layout()

    local hovered = false
    local function paint()
        local textColor = hovered and look.hoverText or look.text
        box:SetColors(hovered and look.hoverFill or look.fill, hovered and look.hoverBorder or look.border)
        button.label:SetTextColor(Style.Color(textColor))
        if icon then
            icon:SetVertexColor(Style.Color(textColor))
        end
    end
    button:SetScript('OnEnter', function()
        hovered = true
        paint()
    end)
    button:SetScript('OnLeave', function()
        hovered = false
        paint()
    end)
    button:SetScript('OnClick', EUI.Guard('config button', function(self)
        onClick(self)
    end))
    function button:SetLabel(newText)
        text = newText or ''
        self.label:SetText(text)
        layout()
    end
    function button:SetVariant(variant)
        look = BUTTON_STYLES[variant]
        paint()
    end
    function button:SetActive(on)
        self:SetEnabled(on)
        self:SetAlpha(on and 1 or 0.38)
    end
    paint()
    return button
end

-- Plain cyan text button (a section's Reset).
function Widgets.Link(parent, label, onClick)
    local button = CreateFrame('Button', nil, parent)
    button.label = Widgets.Text(button, 12, C.accentText)
    button.label:SetPoint('CENTER')
    button.label:SetText(label)
    button:SetSize(button.label:GetStringWidth() + 8, 22)
    button:SetScript('OnEnter', function(self) self.label:SetTextColor(Style.Color('#CFF6FFFF')) end)
    button:SetScript('OnLeave', function(self) self.label:SetTextColor(Style.Color(C.accentText)) end)
    button:SetScript('OnClick', EUI.Guard('config link', function(self) onClick(self) end))
    return button
end

-- A key or value chip: mono text in a small dark box.
function Widgets.Kbd(parent, text)
    local frame = CreateFrame('Frame', nil, parent)
    Widgets.Box(frame, 5, C.input, '#A0B9DC3D')
    frame.text = Widgets.Text(frame, 11, C.value, 'mono')
    frame.text:SetPoint('CENTER')
    function frame:SetText(value)
        self.text:SetText(value)
        self:SetSize(math.floor(self.text:GetStringWidth() + 14.5), 20)
    end
    frame:SetText(text)
    return frame
end

---------------------------------------------------------------------------------------------
-- Controls. spec = { label, tip, get(), set(value) } plus each control's own fields.

-- Switch, 40x22.
function Widgets.Toggle(parent, spec)
    local button = CreateFrame('Button', nil, parent)
    button:SetSize(40, 22)
    local box = Widgets.Box(button, 11)
    local glow = button:CreateTexture(nil, 'ARTWORK', nil, 1)
    glow:SetTexture(Style.AssetPath('settings/glow'))
    glow:SetSize(30, 30)
    glow:SetVertexColor(Style.Color('#6FD3E8B3'))
    local knob = Widgets.Disc(button, 'ARTWORK', 14, C.dim, 2)
    glow:SetPoint('CENTER', knob, 'CENTER')
    local hovered = false
    function button:Refresh()
        local on = spec.get() and true or false
        if on then
            box:SetColors('#6FD3E833', '#6FD3E8BF')
        else
            box:SetColors('#18233AFF', hovered and '#A0B9DC80' or '#A0B9DC47')
        end
        knob:ClearAllPoints()
        knob:SetPoint('LEFT', on and 22 or 4, 0)
        knob:SetVertexColor(Style.Color(on and '#D4F7FFFF' or C.dim))
        glow:SetShown(on)
    end
    button:SetScript('OnEnter', function(self)
        hovered = true
        self:Refresh()
    end)
    button:SetScript('OnLeave', function(self)
        hovered = false
        self:Refresh()
    end)
    button:SetScript('OnClick', EUI.Guard('config toggle', function(self)
        spec.set(not spec.get())
        self:Refresh()
    end))
    button:Refresh()
    return button
end

-- Segmented buttons. spec.choices = { { value, label, tip }, ... }.
function Widgets.Segmented(parent, spec)
    local frame = CreateFrame('Frame', nil, parent)
    Widgets.Box(frame, 9, C.input, '#A0B9DC29')
    local buttons = {}
    local x = 3
    for _, choice in ipairs(spec.choices) do
        local button = CreateFrame('Button', nil, frame)
        local box = Widgets.Box(button, 6)
        button.text = Widgets.Text(button, 12, C.body, 'medium')
        button.text:SetPoint('CENTER')
        button.text:SetText(choice[2])
        local width = math.floor(button.text:GetStringWidth() + 24.5)
        button:SetSize(width, 28)
        button:SetPoint('TOPLEFT', x, -3)
        x = x + width + 2
        button.value, button.box, button.hovered = choice[1], box, false
        button:SetScript('OnEnter', function(self)
            self.hovered = true
            frame:Refresh()
        end)
        button:SetScript('OnLeave', function(self)
            self.hovered = false
            frame:Refresh()
        end)
        button:SetScript('OnClick', EUI.Guard('config choice', function()
            spec.set(choice[1])
            frame:Refresh()
        end))
        setTooltip(button, string.format('%s: %s', spec.label, choice[2]), choice[3])
        buttons[#buttons + 1] = button
    end
    frame:SetSize(x + 1, 34)
    function frame:Refresh()
        local value = spec.get()
        for _, button in ipairs(buttons) do
            local on = button.value == value
            if on then
                button.box:SetColors('#6FD3E826', '#6FD3E880')
                button.text:SetTextColor(Style.Color(C.accentPale))
            elseif button.hovered then
                button.box:SetColors('#A0B9DC14', nil)
                button.text:SetTextColor(Style.Color(C.text))
            else
                button.box:SetColors(nil, nil)
                button.text:SetTextColor(Style.Color(C.body))
            end
        end
    end
    frame:Refresh()
    return frame
end

-- Underlined tabs across width. spec.choices as Segmented.
function Widgets.Tabs(parent, width, spec)
    local frame = CreateFrame('Frame', nil, parent)
    frame:SetSize(width, 40)
    local base = Widgets.Solid(frame, 'BORDER', C.lineSoft)
    base:SetHeight(1)
    base:SetPoint('BOTTOMLEFT')
    base:SetPoint('BOTTOMRIGHT')
    local buttons = {}
    local x = 0
    for _, choice in ipairs(spec.choices) do
        local button = CreateFrame('Button', nil, frame)
        button.text = Widgets.Text(button, 13, C.body)
        button.text:SetPoint('CENTER', 0, 1)
        button.text:SetText(choice[2])
        local w = math.floor(button.text:GetStringWidth() + 28.5)
        button:SetSize(w, 40)
        button:SetPoint('BOTTOMLEFT', x, 0)
        x = x + w + 4
        button.underline = Widgets.Solid(button, 'ARTWORK', C.accent)
        button.underline:SetHeight(2)
        button.underline:SetPoint('BOTTOMLEFT')
        button.underline:SetPoint('BOTTOMRIGHT')
        button.value, button.hovered = choice[1], false
        button:SetScript('OnEnter', function(self)
            self.hovered = true
            frame:Refresh()
        end)
        button:SetScript('OnLeave', function(self)
            self.hovered = false
            frame:Refresh()
        end)
        button:SetScript('OnClick', EUI.Guard('config tab', function()
            spec.set(choice[1])
            frame:Refresh()
        end))
        setTooltip(button, choice[2], choice[3])
        buttons[#buttons + 1] = button
    end
    function frame:Refresh()
        local value = spec.get()
        for _, button in ipairs(buttons) do
            local on = button.value == value
            button.underline:SetShown(on)
            button.text:SetTextColor(Style.Color((on and C.bright) or (button.hovered and C.text) or C.body))
        end
    end
    frame:Refresh()
    return frame
end

-- Slider with a value column. spec = { min, max, step, format (pattern or fn(value)), range
-- (fn() -> min, max, re-read on Refresh), width (whole control, default 280), valueColor }.
-- set runs when a drag ends, not on every pixel of it.
local VALUE_WIDTH = 56

function Widgets.Slider(parent, spec)
    local width = spec.width or 280
    local frame = CreateFrame('Frame', nil, parent)
    frame:SetSize(width, 22)
    local slider = CreateFrame('Slider', nil, frame)
    slider:SetOrientation('HORIZONTAL')
    slider:SetPoint('LEFT')
    slider:SetSize(width - VALUE_WIDTH - 14, 22)
    slider:SetMinMaxValues(spec.min, spec.max)
    slider:SetValueStep(spec.step)
    slider:SetObeyStepOnDrag(true)
    slider:EnableMouse(true)
    local track = Widgets.Solid(slider, 'BACKGROUND', '#22304BFF')
    track:SetHeight(4)
    track:SetPoint('LEFT')
    track:SetPoint('RIGHT')
    local thumb = slider:CreateTexture(nil, 'OVERLAY')
    thumb:SetColorTexture(0, 0, 0, 0)
    thumb:SetSize(14, 22)
    slider:SetThumbTexture(thumb)
    local fill = Widgets.Solid(slider, 'BORDER', '#5CC3DAFF')
    fill:SetHeight(4)
    fill:SetPoint('LEFT', track, 'LEFT')
    fill:SetPoint('RIGHT', thumb, 'CENTER')
    local halo = Widgets.Disc(slider, 'OVERLAY', 22, '#6FD3E824', 1)
    halo:SetPoint('CENTER', thumb, 'CENTER')
    local ring = Widgets.Disc(slider, 'OVERLAY', 14, C.accent, 2)
    ring:SetPoint('CENTER', thumb, 'CENTER')
    local core = Widgets.Disc(slider, 'OVERLAY', 10, '#EAF6FFFF', 3)
    core:SetPoint('CENTER', thumb, 'CENTER')
    slider:SetScript('OnEnter', function()
        halo:SetSize(26, 26)
        halo:SetVertexColor(Style.Color('#6FD3E838'))
    end)
    slider:SetScript('OnLeave', function()
        halo:SetSize(22, 22)
        halo:SetVertexColor(Style.Color('#6FD3E824'))
    end)

    local value = Widgets.Text(frame, 12, spec.valueColor or C.value, spec.valueColor and 'semibold' or 'regular')
    value:SetPoint('RIGHT')
    value:SetWidth(VALUE_WIDTH)
    value:SetJustifyH('RIGHT')

    local function format(v)
        if type(spec.format) == 'function' then
            return spec.format(v)
        end
        return string.format(spec.format or '%d', v)
    end
    local min, max = spec.min, spec.max
    local function snap(v)
        local steps = math.floor((v - min) / spec.step + 0.5)
        return math.min(max, math.max(min, min + steps * spec.step))
    end

    local refreshing, dragging = false, false
    local function commit()
        local v = snap(slider:GetValue())
        if v ~= spec.get() then
            spec.set(v)
        end
    end
    slider:SetScript('OnValueChanged', EUI.Guard('config slider', function(_, v)
        value:SetText(format(snap(v)))
        if not refreshing and not dragging then
            commit()
        end
    end))
    slider:SetScript('OnMouseDown', function()
        dragging = true
    end)
    slider:SetScript('OnMouseUp', EUI.Guard('config slider', function()
        dragging = false
        commit()
    end))

    function frame:Refresh()
        refreshing = true
        if spec.range then
            min, max = spec.range()
            slider:SetMinMaxValues(min, max)
        end
        slider:SetValue(spec.get())
        value:SetText(format(spec.get()))
        refreshing = false
    end
    frame:Refresh()
    return frame
end

---------------------------------------------------------------------------------------------
-- Dropdown: a box showing the choice, opening a list under it. spec.choices as Segmented;
-- spec.fontPreview: each choice value is a font file, drawn in its own face.

local menu

local function createMenu()
    local frame = CreateFrame('Frame', 'EorzeaUIDropdownMenu', UIParent)
    frame:SetFrameStrata('FULLSCREEN_DIALOG')
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()
    Widgets.Box(frame, 8, C.window, C.line)
    -- Clicking anywhere else closes the list.
    local catcher = CreateFrame('Button', nil, UIParent)
    catcher:SetFrameStrata('FULLSCREEN')
    catcher:SetAllPoints(UIParent)
    catcher:Hide()
    catcher:SetScript('OnClick', function() frame:Hide() end)
    frame:SetScript('OnShow', function() catcher:Show() end)
    frame:SetScript('OnHide', function() catcher:Hide() end)
    frame.rows = {}
    return frame
end

local function menuRow(index)
    local row = menu.rows[index]
    if row then
        return row
    end
    row = CreateFrame('Button', nil, menu)
    row:SetHeight(30)
    row.box = Widgets.Box(row, 6)
    row.text = Widgets.Text(row, 12, C.text)
    row.text:SetPoint('LEFT', 10, 0)
    row:SetScript('OnEnter', function(self) self.box:SetColors('#A0B9DC14', nil) end)
    row:SetScript('OnLeave', function(self) self.box:SetColors(nil, nil) end)
    menu.rows[index] = row
    return row
end

local function openMenu(owner, spec, onPick)
    menu = menu or createMenu()
    if menu:IsShown() and menu.owner == owner then
        menu:Hide()
        return
    end
    menu.owner = owner
    menu:SetScale(owner:GetEffectiveScale() / UIParent:GetEffectiveScale())
    local current = spec.get()
    local width = owner:GetWidth()
    for i, choice in ipairs(spec.choices) do
        local row = menuRow(i)
        row:ClearAllPoints()
        row:SetPoint('TOPLEFT', 4, -4 - (i - 1) * 30)
        row:SetPoint('TOPRIGHT', -4, -4 - (i - 1) * 30)
        if spec.fontPreview then
            Style.SetFont(row.text, choice[1], 14, '')
        else
            Style.SetFont(row.text, FONTS.regular, 12, '')
        end
        row.text:SetText(choice[2])
        row.text:SetTextColor(Style.Color(choice[1] == current and C.accentText or C.text))
        row.box:SetColors(nil, nil)
        row:SetScript('OnClick', EUI.Guard('config dropdown', function()
            menu:Hide()
            onPick(choice[1])
        end))
        row:Show()
    end
    for i = #spec.choices + 1, #menu.rows do
        menu.rows[i]:Hide()
    end
    menu:SetSize(width, #spec.choices * 30 + 8)
    menu:ClearAllPoints()
    menu:SetPoint('TOPLEFT', owner, 'BOTTOMLEFT', 0, -4)
    menu:Show()
end

function Widgets.CloseMenus()
    if menu then
        menu:Hide()
    end
end

function Widgets.Dropdown(parent, spec)
    local button = CreateFrame('Button', nil, parent)
    button:SetSize(spec.width or 190, 34)
    local box = Widgets.Box(button, 8, C.input, '#A0B9DC3D')
    button.text = Widgets.Text(button, 12, C.text)
    button.text:SetPoint('LEFT', 12, 0)
    button.text:SetPoint('RIGHT', -32, 0)
    local chevron = Widgets.Icon(button, 'chevron', 14, C.body)
    chevron:SetPoint('RIGHT', -10, 0)
    button:SetScript('OnEnter', function() box:SetColors(C.input, '#A0B9DC73') end)
    button:SetScript('OnLeave', function() box:SetColors(C.input, '#A0B9DC3D') end)
    button:SetScript('OnClick', EUI.Guard('config dropdown', function(self)
        openMenu(self, spec, function(value)
            spec.set(value)
            self:Refresh()
        end)
    end))
    function button:Refresh()
        local value = spec.get()
        for _, choice in ipairs(spec.choices) do
            if choice[1] == value then
                self.text:SetText(choice[2])
                return
            end
        end
        self.text:SetText(tostring(value))
    end
    button:Refresh()
    return button
end

---------------------------------------------------------------------------------------------
-- Colour picker: our own on a native ColorSelect. Blizzard's ColorPickerFrame cannot be used: its
-- SetupColorPickerAndShow stores the caller's functions on the frame and, with the gamepad UI
-- on, runs its gamepad cursor setup in the caller's tainted context.

local function toHex(r, g, b, a)
    return string.format('#%02X%02X%02X%02X', math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5), math.floor((a or 1) * 255 + 0.5))
end
Widgets.ToHex = toHex

local BUTTONS_ART = 'Interface\\Buttons\\UI-ColorPicker-Buttons'
local picker

local function pickerColor()
    local r, g, b = picker.select:GetColorRGB()
    if not r then
        return nil
    end
    local a = picker.startAlpha
    if picker.hasAlpha then
        a = picker.select:GetColorAlpha() or a
    end
    return toHex(r, g, b, a)
end

-- Shows hex on the new-colour swatch and in the hex box (unless it is being typed in).
local function showColor(hex)
    picker.new:SetVertexColor(Style.Color(hex))
    if not picker.hexBox:HasFocus() then
        picker.hexBox:SetText(hex:sub(2, picker.hasAlpha and 9 or 7))
    end
end

local function colorChanged()
    if picker.loading then
        return
    end
    local hex = pickerColor()
    if hex then
        showColor(hex)
        picker.onChange(hex)
    end
end

-- 'RRGGBB' or 'RRGGBBAA' typed into the hex box; alpha keeps the current value when omitted.
local function applyHexText(text)
    text = text:gsub('[^%x]', '')
    if #text ~= 6 and #text ~= 8 then
        return
    end
    local r, g, b, a = Style.Color('#' .. text .. (#text == 6 and 'FF' or ''))
    picker.select:SetColorRGB(r, g, b)
    if picker.hasAlpha and #text == 8 then
        picker.select:SetColorAlpha(a)
    end
    colorChanged()
end

-- A text input in the design's box. opts = { width, height, inset (left text inset) }.
function Widgets.Input(parent, opts)
    local box = CreateFrame('EditBox', nil, parent)
    box:SetSize(opts.width or 120, opts.height or 34)
    box:SetAutoFocus(false)
    Style.SetFont(box, opts.font or FONTS.regular, opts.size or 12, '')
    box:SetTextColor(Style.Color(C.text))
    box:SetTextInsets(opts.inset or 12, 10, 0, 0)
    local frame = Widgets.Box(box, 8, C.input, '#A0B9DC3D')
    box:SetScript('OnEditFocusGained', function() frame:SetColors(C.input, '#6FD3E8B3') end)
    box:SetScript('OnEditFocusLost', function() frame:SetColors(C.input, '#A0B9DC3D') end)
    return box
end

local function createPicker()
    local frame = CreateFrame('Frame', 'EorzeaUIColorPicker', UIParent)
    frame:SetSize(300, 268)
    frame:SetFrameStrata('DIALOG')
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag('LeftButton')
    frame:SetScript('OnDragStart', frame.StartMoving)
    frame:SetScript('OnDragStop', frame.StopMovingOrSizing)
    frame:Hide()
    if UISpecialFrames then
        table.insert(UISpecialFrames, 'EorzeaUIColorPicker')
    end
    Widgets.Panel(frame)
    frame.title = Widgets.Text(frame, 13, C.bright, 'semibold')
    frame.title:SetPoint('TOPLEFT', 18, -16)

    -- Wheel, brightness and (when editing alpha) opacity, laid out as Blizzard's picker.
    local select = CreateFrame('ColorSelect', nil, frame)
    select:SetSize(248, 128)
    select:SetPoint('TOPLEFT', 18, -44)
    local wheel = select:CreateTexture(nil, 'ARTWORK')
    wheel:SetSize(128, 128)
    wheel:SetPoint('TOPLEFT')
    select:SetColorWheelTexture(wheel)
    local wheelThumb = select:CreateTexture(nil, 'OVERLAY')
    wheelThumb:SetTexture(BUTTONS_ART)
    wheelThumb:SetSize(10, 10)
    wheelThumb:SetTexCoord(0, 0.15625, 0, 0.625)
    select:SetColorWheelThumbTexture(wheelThumb)
    local value = select:CreateTexture(nil, 'ARTWORK')
    value:SetSize(32, 128)
    value:SetPoint('LEFT', wheel, 'RIGHT', 24, 0)
    select:SetColorValueTexture(value)
    local valueThumb = select:CreateTexture(nil, 'OVERLAY')
    valueThumb:SetTexture(BUTTONS_ART)
    valueThumb:SetSize(48, 14)
    valueThumb:SetTexCoord(0.25, 1, 0, 0.875)
    select:SetColorValueThumbTexture(valueThumb)
    local alpha = select:CreateTexture(nil, 'ARTWORK')
    alpha:SetSize(32, 128)
    alpha:SetPoint('LEFT', value, 'RIGHT', 24, 0)
    select:SetColorAlphaTexture(alpha)
    local alphaThumb = select:CreateTexture(nil, 'OVERLAY')
    alphaThumb:SetTexture(BUTTONS_ART)
    alphaThumb:SetSize(48, 14)
    alphaThumb:SetTexCoord(0.25, 1, 0, 0.875)
    select:SetColorAlphaThumbTexture(alphaThumb)
    select:SetScript('OnColorSelect', EUI.Guard('colour picker', colorChanged))
    frame.select, frame.alpha, frame.alphaThumb = select, alpha, alphaThumb

    -- Old and new colour side by side, then the hex box.
    local swatch = CreateFrame('Frame', nil, frame)
    swatch:SetSize(58, 28)
    swatch:SetPoint('TOPLEFT', select, 'BOTTOMLEFT', 0, -14)
    swatch:EnableMouse(true)
    frame.old = Widgets.Rounded(swatch, 'ARTWORK', 6, '#FFFFFFFF')
    frame.old:SetPoint('TOPLEFT')
    frame.old:SetSize(28, 28)
    frame.new = Widgets.Rounded(swatch, 'ARTWORK', 6, '#FFFFFFFF')
    frame.new:SetPoint('TOPRIGHT')
    frame.new:SetSize(28, 28)
    setTooltip(swatch, 'Before and after', 'Left: the colour when the picker opened. Right: the new colour.')

    local hexBox = Widgets.Input(frame, { width = 120, height = 30, inset = 24, font = FONTS.mono })
    hexBox:SetPoint('LEFT', swatch, 'RIGHT', 12, 0)
    hexBox:SetMaxLetters(8)
    local hash = Widgets.Text(hexBox, 12, C.dim, 'mono')
    hash:SetPoint('LEFT', 12, 0)
    hash:SetText('#')
    hexBox:SetScript('OnEnterPressed', EUI.Guard('colour hex', function(self)
        applyHexText(self:GetText() or '')
        self:ClearFocus()
    end))
    hexBox:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
    setTooltip(hexBox, 'Hex colour', 'Type RRGGBB, or RRGGBBAA with opacity, and press Enter.')
    frame.hexBox = hexBox

    local cancel = Widgets.Button(frame, 'Cancel', function() frame:Hide() end, { variant = 'ghost' })
    cancel:SetPoint('BOTTOMRIGHT', -14, 14)
    setTooltip(cancel, 'Cancel', 'Back to the colour before the picker opened. Escape does the same.')
    local okay = Widgets.Button(frame, 'Okay', function()
        frame.done = true
        local hex = pickerColor()
        if hex then
            frame.onChange(hex)
        end
        frame:Hide()
    end, { variant = 'primary' })
    okay:SetPoint('RIGHT', cancel, 'LEFT', -8, 0)
    setTooltip(okay, 'Okay', 'Keep this colour.')

    -- Closing any other way than Okay (Cancel, Escape, a new picker) restores the start colour.
    frame:SetScript('OnHide', EUI.Guard('colour picker close', function(self)
        if not self.done and self.onCancel then
            self.onCancel()
        end
        self.onChange, self.onCancel = nil, nil
    end))
    return frame
end

-- Opens the picker on hex. onChange(hex) runs as the colour moves and on Okay; onCancel() when
-- it closes any other way. title: the colour's label.
local function pickColor(hex, hasAlpha, onChange, onCancel, title)
    if not picker then
        picker = createPicker()
    end
    if picker:IsShown() then
        picker:Hide()
    end
    picker:SetScale(Widgets.Scale())
    local r, g, b, a = Style.Color(hex)
    picker.done = false
    picker.onChange, picker.onCancel = onChange, onCancel
    picker.hasAlpha, picker.startAlpha = hasAlpha == true, a
    picker.title:SetText(title or 'Colour')
    picker.alpha:SetShown(picker.hasAlpha)
    picker.alphaThumb:SetShown(picker.hasAlpha)
    picker:SetWidth(picker.hasAlpha and 300 or 244)
    picker.old:SetVertexColor(r, g, b, a)
    picker.loading = true
    picker.select:SetColorRGB(r, g, b)
    if picker.hasAlpha then
        picker.select:SetColorAlpha(a)
    end
    picker.loading = false
    showColor(hex)
    picker:ClearAllPoints()
    local settings = _G.EorzeaUIConfig
    if settings and settings:IsShown() then
        picker:SetPoint('TOPLEFT', settings, 'TOPRIGHT', 12, 0)
    else
        picker:SetPoint('CENTER')
    end
    picker:Show()
    return true
end
Widgets.PickColor = pickColor

-- A colour cell: swatch, label, hex and a reset icon while the colour differs from its default.
-- spec = { label, tip, alpha (bool), get() -> hex, set(hex), isDefault(), reset() }
function Widgets.Color(parent, width, spec)
    local button = CreateFrame('Button', nil, parent)
    button:SetSize(width, 42)
    local hover = Widgets.Rounded(button, 'BACKGROUND', 8, '#A0B9DC0D')
    hover:SetAllPoints()
    hover:Hide()
    local swatch = CreateFrame('Frame', nil, button)
    swatch:SetSize(34, 24)
    swatch:SetPoint('LEFT', 10, 0)
    local checker = Widgets.Rounded(swatch, 'BACKGROUND', 4, '#202020FF')
    checker:SetPoint('TOPLEFT', 3, -3)
    checker:SetPoint('BOTTOMRIGHT', -3, 3)
    local color = Widgets.Rounded(swatch, 'ARTWORK', 4, '#FFFFFFFF')
    color:SetAllPoints(checker)
    local edge = Widgets.Rounded(swatch, 'BORDER', 6, '#A0B9DC4D', true)
    edge:SetAllPoints()
    local label = Widgets.Text(button, 13, C.text)
    label:SetPoint('LEFT', swatch, 'RIGHT', 12, 0)
    label:SetText(spec.label)
    local hex = Widgets.Text(button, 11, C.body, 'mono')
    hex:SetPoint('RIGHT', -44, 0)

    local reset = CreateFrame('Button', nil, button)
    reset:SetSize(24, 24)
    reset:SetPoint('RIGHT', -10, 0)
    local resetBox = Widgets.Rounded(reset, 'BACKGROUND', 5, '#6FD3E81F')
    resetBox:SetAllPoints()
    resetBox:Hide()
    local resetIcon = Widgets.Icon(reset, 'reset', 14, C.accentText)
    resetIcon:SetPoint('CENTER')
    reset:SetScript('OnEnter', function() resetBox:Show() end)
    reset:SetScript('OnLeave', function() resetBox:Hide() end)
    reset:SetScript('OnClick', EUI.Guard('config colour reset', function()
        spec.reset()
        button:Refresh()
    end))
    setTooltip(reset, 'Reset', string.format("Back to the palette's %s colour.", spec.label:lower()))

    button:SetScript('OnEnter', function()
        hover:Show()
        edge:SetVertexColor(Style.Color('#A0B9DC99'))
    end)
    button:SetScript('OnLeave', function()
        hover:Hide()
        edge:SetVertexColor(Style.Color('#A0B9DC4D'))
    end)
    setTooltip(button, spec.label, spec.tip)

    function button:Refresh()
        local value = spec.get()
        color:SetVertexColor(Style.Color(value))
        hex:SetText(value:sub(2, (spec.alpha and 9) or 7))
        reset:SetShown(not spec.isDefault())
    end
    button:SetScript('OnClick', EUI.Guard('config colour', function()
        local start, wasDefault = spec.get(), spec.isDefault()
        pickColor(start, spec.alpha, function(newHex)
            spec.set(newHex)
            button:Refresh()
        end, function()
            if wasDefault then
                spec.reset()
            else
                spec.set(start)
            end
            button:Refresh()
        end, spec.label)
    end))
    button:Refresh()
    return button
end

---------------------------------------------------------------------------------------------
-- Layout pieces

-- A section title: a cyan diamond, the label in spaced caps and a line to the right edge.
-- reset (optional) = { isDefault(), reset() }: a Reset link after the line while the section
-- differs from its defaults.
function Widgets.Header(parent, width, label, reset)
    local holder = CreateFrame('Frame', nil, parent)
    holder:SetSize(width, 24)
    local diamond = Widgets.Icon(holder, 'diamond', 10, C.accent)
    diamond:SetPoint('LEFT', 0, 0)
    local text = Widgets.Text(holder, 11, C.body, 'semibold')
    text:SetPoint('LEFT', diamond, 'RIGHT', 10, 0)
    text:SetText(Widgets.Caps(label))
    local line = Widgets.Solid(holder, 'ARTWORK', C.sectionLine)
    line:SetHeight(1)
    local lineLeft = 20 + math.ceil(text:GetStringWidth()) + 12
    local button
    if reset then
        button = Widgets.Link(holder, 'Reset', function()
            reset.reset()
        end)
        button:SetPoint('RIGHT', 0, 0)
        setTooltip(button, 'Reset section', string.format('Put every %s setting back to its default.', label))
    end
    function holder:Refresh()
        local shown = button and not reset.isDefault()
        if button then
            button:SetShown(shown)
        end
        line:ClearAllPoints()
        line:SetPoint('TOPLEFT', holder, 'TOPLEFT', lineLeft, -12)
        line:SetPoint('TOPRIGHT', holder, 'TOPRIGHT', shown and -(button:GetWidth() + 12) or 0, -12)
    end
    holder:Refresh()
    return holder
end

-- Wrapped 12px text. color (optional): the text colour. shown (optional): fn() -> whether the
-- note shows, re-read on each Refresh; it keeps its height while hidden.
function Widgets.Note(parent, width, text, color, shown)
    local holder = CreateFrame('Frame', nil, parent)
    local note = Widgets.Text(holder, 12, color or C.dim)
    note:SetPoint('TOPLEFT', 0, -4)
    note:SetWidth(width)
    note:SetWordWrap(true)
    note:SetSpacing(3)
    note:SetText(text)
    holder:SetSize(width, math.max(20, math.ceil(note:GetStringHeight()) + 12))
    function holder:Refresh()
        if shown then
            note:SetShown(shown() and true or false)
        end
    end
    holder:Refresh()
    return holder
end
