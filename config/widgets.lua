local _, EUI = ...

-- Controls for the settings window, drawn from plain textures and font strings in the HUD's
-- look: outlined Friz text, header lines, the FFXI hover bar. Each control is a row frame of
-- Widgets.ROW_HEIGHT (sliders taller) whose :Refresh() re-reads its value.

EUI.Widgets = {}
local Widgets = EUI.Widgets
local Style = EUI.Style

local FONT = 'Fonts\\FRIZQT__.TTF'

Widgets.ROW_HEIGHT = 26
Widgets.COLORS = {
    text = '#F0FFFFFF',
    dim = '#8C96A8FF',
    accent = '#A6BCE3FF',
    selected = '#FFFFFFFF',
    hover = '#9C94E8AA',
    box = '#A6BCE3B3',
    fill = '#6AB4F8FF',
    track = '#FFFFFF33',
}
local C = Widgets.COLORS

function Widgets.Text(parent, size, color, outline)
    local text = parent:CreateFontString(nil, 'OVERLAY')
    text:SetFont(FONT, size or 12, outline or '')
    text:SetTextColor(Style.Color(color or C.text))
    text:SetShadowColor(0, 0, 0, 0.9)
    text:SetShadowOffset(1, -1)
    text:SetJustifyH('LEFT')
    return text
end

function Widgets.Solid(parent, layer, color)
    local texture = parent:CreateTexture(nil, layer or 'ARTWORK')
    texture:SetColorTexture(Style.Color(color))
    return texture
end

-- The HUD's hover bar (hud/Hover), shown while the mouse is over frame.
function Widgets.AddHover(frame, target)
    local hover = (target or frame):CreateTexture(nil, 'BACKGROUND')
    hover:SetTexture(Style.AssetPath('hud/Hover'))
    hover:SetVertexColor(Style.Color(C.hover))
    hover:SetAllPoints(target or frame)
    hover:Hide()
    frame:HookScript('OnEnter', function() hover:Show() end)
    frame:HookScript('OnLeave', function() hover:Hide() end)
    return hover
end

local function setTooltip(frame, title, body)
    if not body then
        return
    end
    frame:HookScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
        GameTooltip:SetText(title, 1, 1, 1)
        GameTooltip:AddLine(body, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    frame:HookScript('OnLeave', function()
        GameTooltip:Hide()
    end)
end
Widgets.SetTooltip = setTooltip

local function row(parent, width, height)
    local frame = CreateFrame('Frame', nil, parent)
    frame:SetSize(width, height or Widgets.ROW_HEIGHT)
    return frame
end

-- Text button with the hover bar; no frame. onClick(button).
function Widgets.Button(parent, label, onClick, width)
    local button = CreateFrame('Button', nil, parent)
    button.label = Widgets.Text(button, 12, C.accent)
    button.label:SetPoint('CENTER')
    button.label:SetText(label)
    button:SetSize(width or math.max(60, button.label:GetStringWidth() + 24), 22)
    local line = Widgets.Solid(button, 'ARTWORK', C.box)
    line:SetHeight(1)
    line:SetPoint('BOTTOMLEFT', 6, 1)
    line:SetPoint('BOTTOMRIGHT', -6, 1)
    Widgets.AddHover(button)
    button:SetScript('OnClick', EUI.Guard('config button', function(self)
        onClick(self)
    end))
    function button:SetLabel(text)
        self.label:SetText(text)
    end
    return button
end

-- spec = { label, tip, get(), set(value) }
function Widgets.Toggle(parent, width, spec)
    local frame = row(parent, width)
    local button = CreateFrame('Button', nil, frame)
    button:SetAllPoints()
    local box = CreateFrame('Frame', nil, button)
    box:SetSize(14, 14)
    box:SetPoint('LEFT', 4, 0)
    for _, edge in ipairs({ { 'TOPLEFT', 'TOPRIGHT' }, { 'BOTTOMLEFT', 'BOTTOMRIGHT' } }) do
        local line = Widgets.Solid(box, 'ARTWORK', C.box)
        line:SetHeight(1)
        line:SetPoint(edge[1])
        line:SetPoint(edge[2])
    end
    for _, edge in ipairs({ { 'TOPLEFT', 'BOTTOMLEFT' }, { 'TOPRIGHT', 'BOTTOMRIGHT' } }) do
        local line = Widgets.Solid(box, 'ARTWORK', C.box)
        line:SetWidth(1)
        line:SetPoint(edge[1])
        line:SetPoint(edge[2])
    end
    local check = Widgets.Solid(box, 'OVERLAY', C.fill)
    check:SetPoint('TOPLEFT', 3, -3)
    check:SetPoint('BOTTOMRIGHT', -3, 3)
    local label = Widgets.Text(button, 12)
    label:SetPoint('LEFT', box, 'RIGHT', 8, 0)
    label:SetText(spec.label)
    Widgets.AddHover(button)
    setTooltip(button, spec.label, spec.tip)
    function frame:Refresh()
        local on = spec.get() and true or false
        check:SetShown(on)
        label:SetTextColor(Style.Color(on and C.text or C.dim))
    end
    button:SetScript('OnClick', EUI.Guard('config toggle', function()
        spec.set(not spec.get())
        frame:Refresh()
    end))
    frame:Refresh()
    return frame
end

-- spec = { label, tip, choices = { { value, label, tip }, ... }, stacked, preview, get(), set(value) }
-- The label on the left (above when stacked), the choices as a row of text buttons; the chosen
-- one is lit and underlined. preview (optional, font choices): sample text after the label,
-- drawn in the chosen font file.
function Widgets.Choice(parent, width, spec)
    local rowHeight = Widgets.ROW_HEIGHT
    local frame = row(parent, width, spec.stacked and rowHeight * 2 - 4 or rowHeight)
    local label = Widgets.Text(frame, 12)
    label:SetPoint('TOPLEFT', 4, -(rowHeight - 12) / 2)
    label:SetText(spec.label)
    local hit = CreateFrame('Frame', nil, frame)
    hit:SetPoint('TOPLEFT')
    hit:SetSize(190, rowHeight)
    hit:EnableMouse(true)
    setTooltip(hit, spec.label, spec.tip)
    local buttons = {}
    local x = spec.stacked and 0 or 200
    local y = spec.stacked and -(rowHeight - 4) or -2
    for _, choice in ipairs(spec.choices) do
        local button = CreateFrame('Button', nil, frame)
        button.text = Widgets.Text(button, 12)
        button.text:SetPoint('CENTER')
        button.text:SetText(choice[2])
        local w = button.text:GetStringWidth() + 18
        button:SetSize(w, 22)
        button:SetPoint('TOPLEFT', x, y)
        x = x + w + 4
        button.underline = Widgets.Solid(button, 'ARTWORK', C.fill)
        button.underline:SetHeight(2)
        button.underline:SetPoint('BOTTOMLEFT', 6, 1)
        button.underline:SetPoint('BOTTOMRIGHT', -6, 1)
        Widgets.AddHover(button)
        -- The choice's own tip, else the option's.
        setTooltip(button, string.format('%s: %s', spec.label, choice[2]), choice[3] or spec.tip)
        button:SetScript('OnClick', EUI.Guard('config choice', function()
            spec.set(choice[1])
            frame:Refresh()
        end))
        button.value = choice[1]
        buttons[#buttons + 1] = button
    end
    local sample
    if spec.preview then
        sample = Widgets.Text(frame, 14, C.text, 'OUTLINE')
        sample:SetPoint('LEFT', label, 'LEFT', 140, 0)
        sample:SetPoint('RIGHT', frame, 'RIGHT', -4, 0)
        sample:SetWordWrap(false)
        sample:SetText(spec.preview)
    end

    function frame:Refresh()
        local value = spec.get()
        if sample and not sample:SetFont(Style.FontPath(value), 14, 'OUTLINE') then
            sample:SetFont(FONT, 14, 'OUTLINE')
        end
        for _, button in ipairs(buttons) do
            local on = button.value == value
            button.underline:SetShown(on)
            button.text:SetTextColor(Style.Color(on and C.selected or C.dim))
        end
    end
    frame:Refresh()
    return frame
end

-- spec = { label, tip, min, max, step, format (string.format pattern, or fn(value)), lead, range,
-- get(), set(value) }. lead (optional): fn() -> text for a right-aligned column before the label.
-- range (optional): fn() -> min, max, re-read on each Refresh in place of min and max.
-- set runs when the drag ends or a step key/wheel moves it, not on every pixel of a drag.
local LEAD_WIDTH = 40

function Widgets.Slider(parent, width, spec)
    local frame = row(parent, width)
    local label = Widgets.Text(frame, 12)
    label:SetText(spec.label)
    local lead
    if spec.lead then
        lead = Widgets.Text(frame, 12, C.accent)
        lead:SetPoint('LEFT', 4, 0)
        lead:SetWidth(LEAD_WIDTH)
        lead:SetJustifyH('RIGHT')
        label:SetPoint('LEFT', lead, 'RIGHT', 10, 0)
    else
        label:SetPoint('LEFT', 4, 0)
    end
    local hit = CreateFrame('Frame', nil, frame)
    hit:SetPoint('TOPLEFT')
    hit:SetPoint('BOTTOMLEFT')
    hit:SetWidth(190)
    hit:EnableMouse(true)
    setTooltip(hit, spec.label, spec.tip)

    local slider = CreateFrame('Slider', nil, frame)
    slider:SetOrientation('HORIZONTAL')
    slider:SetSize(width - 200 - 70, 16)
    slider:SetPoint('LEFT', 204, 0)
    slider:SetMinMaxValues(spec.min, spec.max)
    slider:SetValueStep(spec.step)
    slider:SetObeyStepOnDrag(true)
    slider:EnableMouse(true)
    slider:EnableMouseWheel(true)
    local track = Widgets.Solid(slider, 'BACKGROUND', C.track)
    track:SetHeight(2)
    track:SetPoint('LEFT')
    track:SetPoint('RIGHT')
    local thumb = slider:CreateTexture(nil, 'OVERLAY')
    thumb:SetColorTexture(Style.Color(C.fill))
    thumb:SetSize(6, 14)
    slider:SetThumbTexture(thumb)

    local value = Widgets.Text(frame, 12, C.accent)
    value:SetPoint('LEFT', slider, 'RIGHT', 12, 0)

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

    local refreshing = false
    local dragging = false
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
    slider:SetScript('OnMouseWheel', function(self, delta)
        self:SetValue(snap(self:GetValue() + delta * spec.step))
    end)

    function frame:Refresh()
        refreshing = true
        if spec.range then
            min, max = spec.range()
            slider:SetMinMaxValues(min, max)
        end
        slider:SetValue(spec.get())
        value:SetText(format(spec.get()))
        if lead then
            lead:SetText(spec.lead())
        end
        refreshing = false
    end
    frame:Refresh()
    return frame
end

local function toHex(r, g, b, a)
    return string.format('#%02X%02X%02X%02X', math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5), math.floor((a or 1) * 255 + 0.5))
end
Widgets.ToHex = toHex

-- Our own colour picker on a native ColorSelect. Blizzard's ColorPickerFrame cannot be used: its
-- SetupColorPickerAndShow stores the caller's functions on the frame and, with the gamepad UI
-- on, runs its gamepad cursor setup in the caller's tainted context.
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
    picker.new:SetColorTexture(Style.Color(hex))
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

-- '#RRGGBB' or '#RRGGBBAA' typed into the hex box; alpha keeps the current value when omitted.
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

local function createPicker()
    local frame = CreateFrame('Frame', 'EorzeaUIColorPicker', UIParent)
    frame:SetSize(276, 236)
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
    local bg = frame:CreateTexture(nil, 'BACKGROUND')
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 1)
    if not pcall(bg.SetGradient, bg, 'VERTICAL', CreateColor(0.02, 0.03, 0.06, 0.97), CreateColor(0.07, 0.10, 0.19, 0.97)) then
        bg:SetVertexColor(0.04, 0.06, 0.12, 0.97)
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
    frame.title = Widgets.Text(frame, 13, C.accent)
    frame.title:SetPoint('TOPLEFT', 14, -12)

    -- Wheel, brightness and (when editing alpha) opacity, laid out as Blizzard's picker.
    local select = CreateFrame('ColorSelect', nil, frame)
    select:SetSize(248, 128)
    select:SetPoint('TOPLEFT', 14, -36)
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

    -- Old and new colour, then the hex box.
    local old = frame:CreateTexture(nil, 'ARTWORK')
    old:SetSize(28, 20)
    old:SetPoint('TOPLEFT', select, 'BOTTOMLEFT', 0, -10)
    local new = frame:CreateTexture(nil, 'ARTWORK')
    new:SetSize(28, 20)
    new:SetPoint('LEFT', old, 'RIGHT', 0, 0)
    frame.old, frame.new = old, new

    local hexBox = CreateFrame('EditBox', nil, frame)
    hexBox:SetSize(90, 20)
    hexBox:SetPoint('LEFT', new, 'RIGHT', 14, 0)
    hexBox:SetFont(FONT, 12, '')
    hexBox:SetTextColor(Style.Color(C.text))
    hexBox:SetAutoFocus(false)
    hexBox:SetMaxLetters(8)
    hexBox:SetTextInsets(14, 4, 0, 0)
    local hash = Widgets.Text(hexBox, 12, C.dim)
    hash:SetPoint('LEFT', 4, 0)
    hash:SetText('#')
    local underline = Widgets.Solid(hexBox, 'ARTWORK', C.box)
    underline:SetHeight(1)
    underline:SetPoint('BOTTOMLEFT')
    underline:SetPoint('BOTTOMRIGHT')
    hexBox:SetScript('OnEnterPressed', EUI.Guard('colour hex', function(self)
        applyHexText(self:GetText() or '')
        self:ClearFocus()
    end))
    hexBox:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
    setTooltip(hexBox, 'Hex colour', 'Type RRGGBB, or RRGGBBAA with opacity, and press Enter.')
    frame.hexBox = hexBox

    local cancel = Widgets.Button(frame, 'Cancel', function() frame:Hide() end, 70)
    cancel:SetPoint('BOTTOMRIGHT', -10, 10)
    setTooltip(cancel, 'Cancel', 'Back to the colour before the picker opened. Escape does the same.')
    local okay = Widgets.Button(frame, 'Okay', function()
        frame.done = true
        local hex = pickerColor()
        if hex then
            frame.onChange(hex)
        end
        frame:Hide()
    end, 70)
    okay:SetPoint('RIGHT', cancel, 'LEFT', -6, 0)
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
    local r, g, b, a = Style.Color(hex)
    picker.done = false
    picker.onChange, picker.onCancel = onChange, onCancel
    picker.hasAlpha, picker.startAlpha = hasAlpha == true, a
    picker.title:SetText(title or 'Colour')
    picker.alpha:SetShown(picker.hasAlpha)
    picker.alphaThumb:SetShown(picker.hasAlpha)
    picker:SetWidth(picker.hasAlpha and 276 or 220)
    picker.old:SetColorTexture(r, g, b, a)
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
        picker:SetPoint('TOPLEFT', settings, 'TOPRIGHT', 8, 0)
    else
        picker:SetPoint('CENTER')
    end
    picker:Show()
    return true
end
Widgets.PickColor = pickColor

-- spec = { label, tip, alpha (bool), get() -> hex, set(hex), isDefault(), reset() }
-- A swatch square before the label; "reset" appears while the colour differs from the default.
function Widgets.Color(parent, width, spec)
    local frame = row(parent, width)
    local button = CreateFrame('Button', nil, frame)
    button:SetPoint('TOPLEFT')
    button:SetPoint('BOTTOMLEFT')
    button:SetWidth(width - 70)
    local checker = Widgets.Solid(button, 'ARTWORK', '#202020FF')
    checker:SetSize(28, 14)
    checker:SetPoint('LEFT', 4, 0)
    local swatch = button:CreateTexture(nil, 'OVERLAY')
    swatch:SetColorTexture(1, 1, 1, 1)
    swatch:SetAllPoints(checker)
    local label = Widgets.Text(button, 12)
    label:SetPoint('LEFT', checker, 'RIGHT', 10, 0)
    label:SetText(spec.label)
    Widgets.AddHover(button)
    setTooltip(button, spec.label, spec.tip)

    local reset = Widgets.Button(frame, 'reset', function()
        spec.reset()
        frame:Refresh()
    end, 56)
    reset:SetPoint('RIGHT', -4, 0)
    setTooltip(reset, 'Reset', string.format("Back to the palette's %s colour.", spec.label:lower()))

    function frame:Refresh()
        swatch:SetVertexColor(Style.Color(spec.get()))
        reset:SetShown(not spec.isDefault())
    end
    button:SetScript('OnClick', EUI.Guard('config colour', function()
        local start, wasDefault = spec.get(), spec.isDefault()
        pickColor(start, spec.alpha, function(hex)
            spec.set(hex)
            frame:Refresh()
        end, function()
            if wasDefault then
                spec.reset()
            else
                spec.set(start)
            end
            frame:Refresh()
        end, spec.label)
    end))
    frame:Refresh()
    return frame
end

local RESET_WIDTH = 56

-- A section title: Style.Header's centred label between fading lines, in the accent colour.
-- reset (optional) = { isDefault(), reset() }: a "reset" button right of the lines, shown while
-- the section differs from its defaults.
function Widgets.Header(parent, width, label, fonts, reset)
    local holder = row(parent, width, 30)
    local header = Style.Header(holder, {
        label = label,
        pos = { 0, 10 },
        width = width - RESET_WIDTH - 8,
        height = 14,
        txtLabel = { size = 13, color = C.accent, stroke = '#000000FF', outline = '', font = 'header' },
        line = { color = C.accent, alpha = 0.6, height = 1, gap = 8 },
    }, fonts)
    holder.header = header
    local button
    if reset then
        button = Widgets.Button(holder, 'reset', function()
            reset.reset()
        end, RESET_WIDTH)
        button:SetPoint('RIGHT', -4, -2)
        setTooltip(button, 'Reset section', string.format('Put every %s setting back to its default.', label))
    end
    function holder:Refresh()
        if button then
            button:SetShown(not reset.isDefault())
        end
    end
    holder:Refresh()
    return holder
end

-- Grey wrapped text under a section.
-- color (optional): the text colour. shown (optional): fn() -> whether the note shows, re-read on
-- each Refresh; it keeps its height while hidden.
function Widgets.Note(parent, width, text, color, shown)
    local holder = row(parent, width, 10)
    local note = Widgets.Text(holder, 11, color or C.dim)
    note:SetPoint('TOPLEFT', 4, -2)
    note:SetWidth(width - 8)
    note:SetWordWrap(true)
    note:SetText(text)
    holder:SetHeight(math.max(18, note:GetStringHeight() + 8))
    function holder:Refresh()
        if shown then
            note:SetShown(shown() and true or false)
        end
    end
    holder:Refresh()
    return holder
end
