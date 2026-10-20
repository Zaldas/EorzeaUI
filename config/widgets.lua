local _, EUI = ...

-- Controls for the settings window, in the in-game look of the settings design (canvas page
-- "In-game pass"): Inter text outlined over a navy panel, Cinzel titles, glass buttons, the rail
-- toggle, the light-pillar choice rail, diamond-thumbed sliders and brush-stroke colour swatches.
-- Art is in assets/settings (tools/settingsArt.py) plus the HUD's hover bar, cursor and pips. Each
-- control is a frame whose :Refresh() re-reads its value; sizes are UI units at the window's scale.

EUI.Widgets = {}
local Widgets = EUI.Widgets
local Style = EUI.Style

local C = {
    text = '#DCE4F0FF',
    bright = '#F4FBFFFF',
    title = '#EEF3FAFF',
    body = '#C9D4E5FF',
    dim = '#8E9CB3FF',
    faint = '#7F8DA3FF',
    off = '#8291A8FF',
    heading = '#9FB0C8FF',
    value = '#CFE0F2FF',
    line = '#96B4E180',
    edgeDark = '#01040AFF',
    edgeLight = '#96B4E14D',
    rim = '#AAD7FF6B',
    well = '#050B16CC',
    wellRim = '#AAD7FF52',
    goldText = '#F0DDB3FF',
    red = '#FF7A7AFF',
}
Widgets.COLORS = C

-- Accents follow the palette the frames were built with: Vana'diel's crystal cyan or Azeroth's
-- gold. hover is the hover bar's tint; tint the cyan-or-gold glass.
local ACCENTS = {
    vanadiel = {
        accent = '#6FD3E8FF', text = '#8FDDEFFF', pale = '#DDF8FFFF', deep = '#2C7487FF',
        hover = '#6FD3E85C', tint = '#78E1F5FF', rimHot = '#8CE1F5D9',
    },
    azeroth = {
        accent = '#E3B65EFF', text = '#F0D08AFF', pale = '#FFF0CFFF', deep = '#7A5A22FF',
        hover = '#E3B65E5C', tint = '#F0CD8CFF', rimHot = '#F0D296D9',
    },
}
local A = ACCENTS.vanadiel
Widgets.ACCENT = A

-- Picks the accent set for palette name (unknown names keep crystal cyan).
function Widgets.SetAccent(name)
    A = ACCENTS[name] or ACCENTS.vanadiel
    Widgets.ACCENT = A
end

function Widgets.Accent()
    return A
end

local FONTS = {
    regular = 'Inter-Regular.ttf',
    medium = 'Inter-Medium.ttf',
    semibold = 'Inter-SemiBold.ttf',
    display = 'Cinzel-Bold.ttf',
    mono = 'Inconsolata-Regular.ttf',
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

local function playSound(key)
    local id = SOUNDKIT and SOUNDKIT[key]
    if id and PlaySound then
        pcall(PlaySound, id)
    end
end
Widgets.Sound = playSound

-- flags: font flags, 'OUTLINE' by default; '' draws with a drop shadow instead.
function Widgets.Text(parent, size, color, weight, flags, layer)
    local text = parent:CreateFontString(nil, layer or 'OVERLAY')
    flags = flags or 'OUTLINE'
    Style.SetFont(text, FONTS[weight or 'regular'], size or 14, flags)
    if flags == '' then
        text:SetShadowColor(0, 0, 0, 0.85)
        text:SetShadowOffset(1, -1)
    end
    text:SetTextColor(Style.Color(color or C.text))
    text:SetJustifyH('LEFT')
    text:SetWordWrap(false)
    return text
end

-- Unsnapped, a line thinner than a screen pixel blends across two pixels instead of rounding
-- away to nothing.
local function unsnap(texture)
    if texture.SetSnapToPixelGrid then
        texture:SetSnapToPixelGrid(false)
        texture:SetTexelSnappingBias(0)
    end
end

function Widgets.Solid(parent, layer, color, subLevel)
    local texture = parent:CreateTexture(nil, layer or 'ARTWORK', nil, subLevel)
    texture:SetColorTexture(Style.Color(color))
    unsnap(texture)
    return texture
end

local function asColor(hex)
    local r, g, b, a = Style.Color(hex)
    return CreateColor(r, g, b, a)
end

-- Two-colour gradient on a texture ('VERTICAL' runs bottom to top); vertex colour from first
-- where SetGradient is missing.
function Widgets.Gradient(texture, orientation, first, second)
    if not pcall(texture.SetGradient, texture, orientation, asColor(first), asColor(second)) then
        texture:SetVertexColor(Style.Color(first))
    end
end

local slicesMissing = false

-- A rounded rect sliced so the corners keep their size; ring: the 1px edge only. art: a texture
-- name in assets/settings ('fill', 'ring' or 'glass'), radius appended.
local function sliced(parent, layer, art, radius, color, subLevel)
    local texture = parent:CreateTexture(nil, layer or 'BACKGROUND', nil, subLevel)
    texture:SetTexture(Style.AssetPath(string.format('settings/%s%d', art, radius)))
    unsnap(texture)
    if texture.SetTextureSliceMargins then
        texture:SetTextureSliceMargins(radius, radius, radius, radius)
    elseif not slicesMissing then
        slicesMissing = true
        EUI.LogOnce('settings:slices', 'SetTextureSliceMargins missing; settings corners stretch')
    end
    if color then
        texture:SetVertexColor(Style.Color(color))
    end
    return texture
end

function Widgets.Rounded(parent, layer, radius, color, ring, subLevel)
    return sliced(parent, layer, ring and 'ring' or 'fill', radius, color, subLevel)
end

-- A dark glass well (search box, font samples, dropdown lists): deep navy fading lighter downward.
function Widgets.Well(frame, radius)
    local fill = sliced(frame, 'BACKGROUND', 'fill', radius or 8)
    fill:SetAllPoints()
    Widgets.Gradient(fill, 'VERTICAL', '#12203AA0', '#030710C8')
    local rim = sliced(frame, 'BORDER', 'ring', radius or 8, C.wellRim)
    rim:SetAllPoints()
    return fill, rim
end

-- The window material: a top-lit navy fill inside a dark outer and light inner edge, rounded 4.
function Widgets.Panel(frame)
    local fill = sliced(frame, 'BACKGROUND', 'fill', 4)
    fill:SetAllPoints()
    Widgets.Gradient(fill, 'VERTICAL', '#0A1121FF', '#1B2846FF')
    local outer = sliced(frame, 'BORDER', 'ring', 4, C.edgeDark)
    outer:SetAllPoints()
    local inner = sliced(frame, 'BORDER', 'ring', 3, C.edgeLight, 1)
    inner:SetPoint('TOPLEFT', 1, -1)
    inner:SetPoint('BOTTOMRIGHT', -1, 1)
    local shine = Widgets.Solid(frame, 'BORDER', '#D6E8FF14', 2)
    shine:SetHeight(1)
    shine:SetPoint('TOPLEFT', 4, -2)
    shine:SetPoint('TOPRIGHT', -4, -2)
    return fill
end

-- A 1px line fading out: 'both' ends (header rules) or toward the 'end' (section rules, which
-- start bright at the label). vertical: runs top to bottom.
function Widgets.FadeLine(parent, color, mode, vertical)
    local frame = CreateFrame('Frame', nil, parent)
    if vertical then
        frame:SetWidth(1)
    else
        frame:SetHeight(1)
    end
    local r, g, b = Style.Color(color or C.line)
    local clear = string.format('#%02X%02X%02X00', math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5))
    local solid = color or C.line
    local orientation = vertical and 'VERTICAL' or 'HORIZONTAL'
    local function piece()
        local texture = frame:CreateTexture(nil, 'ARTWORK')
        texture:SetColorTexture(1, 1, 1, 1)
        unsnap(texture)
        return texture
    end
    if mode == 'end' then
        local texture = piece()
        texture:SetAllPoints()
        if vertical then
            Widgets.Gradient(texture, orientation, clear, solid)
        else
            Widgets.Gradient(texture, orientation, solid, clear)
        end
    else
        local first, second = piece(), piece()
        if vertical then
            first:SetPoint('TOPLEFT')
            first:SetPoint('BOTTOMRIGHT', frame, 'RIGHT', 0, 0)
            second:SetPoint('TOPLEFT', frame, 'LEFT', 0, 0)
            second:SetPoint('BOTTOMRIGHT')
            Widgets.Gradient(first, orientation, solid, clear)
            Widgets.Gradient(second, orientation, clear, solid)
        else
            first:SetPoint('TOPLEFT')
            first:SetPoint('BOTTOMRIGHT', frame, 'BOTTOM', 0, 0)
            second:SetPoint('TOPLEFT', frame, 'TOP', 0, 0)
            second:SetPoint('BOTTOMRIGHT')
            Widgets.Gradient(first, orientation, clear, solid)
            Widgets.Gradient(second, orientation, solid, clear)
        end
    end
    return frame
end

function Widgets.Icon(parent, name, size, color, layer)
    local texture = parent:CreateTexture(nil, layer or 'ARTWORK')
    texture:SetTexture(Style.AssetPath('settings/' .. name))
    texture:SetSize(size, size)
    texture:SetVertexColor(Style.Color(color or C.text))
    return texture
end

-- The HUD's diamond pip (filled, or the outline when hollow).
function Widgets.Pip(parent, size, color, hollow, layer, subLevel)
    local texture = parent:CreateTexture(nil, layer or 'OVERLAY', nil, subLevel)
    texture:SetTexture(Style.AssetPath(hollow and 'pips/diamondLine-16' or 'pips/diamondFill-16'))
    texture:SetSize(size, size)
    texture:SetVertexColor(Style.Color(color))
    return texture
end

function Widgets.Glow(parent, width, height, color, layer, subLevel)
    local texture = parent:CreateTexture(nil, layer or 'ARTWORK', nil, subLevel)
    texture:SetTexture(Style.AssetPath('settings/glow'))
    texture:SetSize(width, height)
    texture:SetBlendMode('ADD')
    texture:SetVertexColor(Style.Color(color))
    return texture
end

-- The HUD's hover bar, tinted with the accent; the selection and hover highlight.
function Widgets.HoverBar(parent, layer)
    local texture = parent:CreateTexture(nil, layer or 'BACKGROUND', nil, 2)
    texture:SetTexture(Style.AssetPath('hud/Hover'))
    texture:SetVertexColor(Style.Color(A.hover))
    return texture
end

-- The HUD's hand cursor, bobbing 2px while shown.
function Widgets.Cursor(parent, width, height)
    local texture = parent:CreateTexture(nil, 'OVERLAY', nil, 6)
    texture:SetTexture(Style.AssetPath('hud/Cursor'))
    texture:SetSize(width or 30, height or 19)
    local ok, bob = pcall(function()
        local group = texture:CreateAnimationGroup()
        group:SetLooping('BOUNCE')
        local move = group:CreateAnimation('Translation')
        move:SetOffset(2, 0)
        move:SetDuration(0.4)
        move:SetSmoothing('IN_OUT')
        return group
    end)
    if ok and bob then
        texture.bob = bob
    end
    return texture
end

-- Shows or hides a cursor from Widgets.Cursor, starting or stopping its bob.
function Widgets.ShowCursor(texture, shown)
    texture:SetShown(shown)
    local bob = rawget(texture, 'bob')
    if bob then
        if shown and not bob:IsPlaying() then
            bob:Play()
        elseif not shown then
            bob:Stop()
        end
    end
end

-- A painted brush stroke (variant 1-3) tinted hex.
function Widgets.Brush(parent, variant, width, height, hex, layer)
    local texture = parent:CreateTexture(nil, layer or 'ARTWORK')
    texture:SetTexture(Style.AssetPath('settings/brush' .. ((variant - 1) % 3 + 1)))
    texture:SetSize(width, height)
    texture:SetVertexColor(Style.Color(hex))
    return texture
end

-- Eases value toward target over duration, calling apply(value) each frame; returns a function
-- that starts a new move. Snaps when the frame is hidden.
local function animator(frame, duration, apply)
    local from, to, elapsed = 0, 0, duration
    local driver = CreateFrame('Frame', nil, frame)
    driver:Hide()
    driver:SetScript('OnUpdate', function(self, dt)
        elapsed = elapsed + dt
        local t = math.min(1, elapsed / duration)
        -- Ease out with a slight overshoot.
        local eased = 1 + 2.2 * (t - 1) ^ 3 + 1.2 * (t - 1) ^ 2
        apply(from + (to - from) * eased)
        if t >= 1 then
            apply(to)
            self:Hide()
        end
    end)
    return function(target, instant)
        if instant or not frame:IsVisible() then
            from, to, elapsed = target, target, duration
            driver:Hide()
            apply(target)
            return
        end
        from, to, elapsed = to, target, 0
        driver:Show()
    end
end

---------------------------------------------------------------------------------------------
-- Tooltip: the glass panel, the title in the accent colour, above-right of the control.

local TOOLTIP_PAD_X, TOOLTIP_PAD_Y = 12, 10
local TOOLTIP_MAX_WIDTH = 280
local tooltip

local function createTooltip()
    local frame = CreateFrame('Frame', 'EorzeaUITooltip', UIParent)
    frame:SetFrameStrata('TOOLTIP')
    frame:SetClampedToScreen(true)
    frame:Hide()
    local fill = sliced(frame, 'BACKGROUND', 'fill', 8)
    fill:SetAllPoints()
    Widgets.Gradient(fill, 'VERTICAL', '#0A1121F5', '#1B2846F5')
    local gloss = sliced(frame, 'BACKGROUND', 'glass', 8, '#8CBEFA60', 1)
    gloss:SetAllPoints()
    local rim = sliced(frame, 'BORDER', 'ring', 8, '#AAD7FF73')
    rim:SetAllPoints()
    frame.title = Widgets.Text(frame, 13, A.text, 'semibold')
    frame.title:SetPoint('TOPLEFT', TOOLTIP_PAD_X, -TOOLTIP_PAD_Y)
    frame.body = Widgets.Text(frame, 13, C.text)
    frame.body:SetPoint('TOPLEFT', frame.title, 'BOTTOMLEFT', 0, -4)
    frame.body:SetWordWrap(true)
    frame.body:SetSpacing(2)
    return frame
end

local function showTooltip(owner, title, body)
    tooltip = tooltip or createTooltip()
    tooltip:SetScale(Widgets.Scale())
    tooltip.title:SetTextColor(Style.Color(A.text))
    tooltip.title:SetText(title or '')
    tooltip.body:SetText(body)
    tooltip.body:SetWidth(TOOLTIP_MAX_WIDTH)
    local unwrapped = tooltip.body.GetUnboundedStringWidth and tooltip.body:GetUnboundedStringWidth()
        or TOOLTIP_MAX_WIDTH
    local width = math.min(TOOLTIP_MAX_WIDTH, math.max(unwrapped, tooltip.title:GetStringWidth()))
    tooltip.body:SetWidth(width)
    tooltip:SetSize(width + TOOLTIP_PAD_X * 2,
        tooltip.title:GetStringHeight() + 4 + tooltip.body:GetStringHeight() + TOOLTIP_PAD_Y * 2)
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
-- Buttons: glass plates, blue by default, accent-tinted for the primary action, gold for a
-- waiting reload.

local function buttonLook(variant)
    if variant == 'primary' then
        return { tint = A.tint, rim = A.rimHot, text = A.pale }
    elseif variant == 'gold' then
        return { tint = '#F0CD8CFF', rim = '#E6C88C99', text = '#FFF0CFFF', glow = '#E6C88C' }
    end
    return { tint = '#8CBEFAFF', rim = C.rim, text = '#EAF4FFFF' }
end

-- opts = { variant ('default' | 'primary' | 'gold'), icon, width, height, pad }. onClick(button).
function Widgets.Button(parent, label, onClick, opts)
    opts = type(opts) == 'table' and opts or { width = opts }
    local variant = opts.variant or 'default'
    local look = buttonLook(variant)
    local height = opts.height or 30
    local radius = height < 26 and 6 or 8
    local button = CreateFrame('Button', nil, parent)
    local glassTex = sliced(button, 'BACKGROUND', 'glass', 8)
    glassTex:SetAllPoints()
    local shine = sliced(button, 'BACKGROUND', 'fill', radius, '#00000000', 1)
    shine:SetAllPoints()
    shine:SetBlendMode('ADD')
    local rim = sliced(button, 'BORDER', 'ring', radius)
    rim:SetAllPoints()
    button.label = Widgets.Text(button, opts.size or 14, look.text, 'medium', '')
    local icon
    if opts.icon then
        icon = Widgets.Icon(button, opts.icon, opts.iconSize or 14, look.text)
    end
    local pad = opts.pad or 16
    local text = label or ''
    local function layout()
        button.label:ClearAllPoints()
        local textWidth = text ~= '' and button.label:GetStringWidth() or 0
        if icon then
            local gap = textWidth > 0 and 8 or 0
            icon:ClearAllPoints()
            icon:SetPoint('LEFT', button, 'CENTER', -(icon:GetWidth() + gap + textWidth) / 2, 0)
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
        glassTex:SetVertexColor(Style.Color(look.tint))
        rim:SetVertexColor(Style.Color(hovered and (look.glow and '#F5D796F2' or A.rimHot) or look.rim))
        shine:SetVertexColor(Style.Color(hovered and (look.glow and '#E6C88C30' or (A.accent:sub(1, 7) .. '30')) or '#00000000'))
        button.label:SetTextColor(Style.Color(look.text))
        if icon then
            icon:SetVertexColor(Style.Color(look.text))
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
        playSound('IG_MAINMENU_OPTION')
        onClick(self)
    end))
    function button:SetLabel(newText)
        text = newText or ''
        self.label:SetText(text)
        layout()
    end
    function button:SetVariant(newVariant)
        look = buttonLook(newVariant)
        paint()
    end
    function button:SetActive(on)
        self:SetEnabled(on)
        self:SetAlpha(on and 1 or 0.4)
    end
    paint()
    return button
end


---------------------------------------------------------------------------------------------
-- Controls. spec = { label, tip, get(), set(value) } plus each control's own fields;
-- spec.onHelp(text) (optional) receives the tip of the part under the mouse.

-- Rail toggle: a diamond pip slides between two hollow sockets along a rail that lights when on.
local RAIL_LEFT, RAIL_RIGHT = 8, 44

function Widgets.Toggle(parent, spec)
    local button = CreateFrame('Button', nil, parent)
    button:SetSize(52, 22)
    local rail = Widgets.Solid(button, 'ARTWORK', '#96B4E159')
    rail:SetHeight(2)
    rail:SetPoint('LEFT', RAIL_LEFT, 0)
    rail:SetPoint('RIGHT', -(52 - RAIL_RIGHT), 0)
    local shadow = Widgets.Solid(button, 'BORDER', C.edgeDark)
    shadow:SetHeight(1)
    shadow:SetPoint('TOPLEFT', rail, 'BOTTOMLEFT')
    shadow:SetPoint('TOPRIGHT', rail, 'BOTTOMRIGHT')
    for _, x in ipairs({ RAIL_LEFT, RAIL_RIGHT }) do
        local socket = Widgets.Pip(button, 8, '#3A475EFF', true, 'ARTWORK', 1)
        socket:SetPoint('CENTER', button, 'LEFT', x, 0)
    end
    local glow = Widgets.Glow(button, 26, 26, A.accent, 'OVERLAY', 1)
    local pip = Widgets.Pip(button, 16, C.dim, false, 'OVERLAY', 2)
    glow:SetPoint('CENTER', pip, 'CENTER')
    local hovered = false
    local on = false
    local slide = animator(button, 0.14, function(x)
        pip:ClearAllPoints()
        pip:SetPoint('CENTER', button, 'LEFT', x, 0)
    end)
    local function paint()
        if on then
            rail:SetColorTexture(1, 1, 1, 1)
            Widgets.Gradient(rail, 'HORIZONTAL', A.accent:sub(1, 7) .. '26', A.accent)
            pip:SetVertexColor(Style.Color(A.pale))
        else
            rail:SetColorTexture(Style.Color('#96B4E159'))
            pip:SetVertexColor(Style.Color(hovered and C.body or C.dim))
        end
        glow:SetShown(on)
    end
    function button:Refresh()
        local value = spec.get() and true or false
        local changed = value ~= on
        on = value
        slide(on and RAIL_RIGHT or RAIL_LEFT, not changed)
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
    button:SetScript('OnClick', EUI.Guard('config toggle', function(self)
        local value = not spec.get()
        playSound(value and 'IG_MAINMENU_OPTION_CHECKBOX_ON' or 'IG_MAINMENU_OPTION_CHECKBOX_OFF')
        spec.set(value)
        self:Refresh()
    end))
    on = spec.get() and true or false
    slide(on and RAIL_RIGHT or RAIL_LEFT, true)
    paint()
    return button
end

-- Light-pillar choice rail: options in equal columns over a hairline; a soft column of light
-- rises from a lit diamond under the chosen one and slides when the choice changes.
-- spec.choices = { { value, label, tip }, ... }.
function Widgets.Rail(parent, spec)
    local count = #spec.choices
    local column = count > 3 and 92 or (count == 2 and 120 or 100)
    local frame = CreateFrame('Frame', nil, parent)
    frame:SetSize(column * count, 30)
    local hairline = Widgets.FadeLine(frame, '#96B4E173', 'both')
    hairline:SetPoint('BOTTOMLEFT')
    hairline:SetPoint('BOTTOMRIGHT')

    local light = CreateFrame('Frame', nil, frame)
    light:SetSize(column, 30)
    -- The glows use the top half of the glow texture, so the light rises from the hairline only.
    local pillar = Widgets.Glow(light, column * 0.8, 30, A.accent:sub(1, 7) .. '8C', 'BACKGROUND')
    pillar:SetTexCoord(0, 1, 0, 0.5)
    pillar:SetPoint('BOTTOM', light, 'BOTTOM', 0, 0)
    local bar = Widgets.Solid(light, 'ARTWORK', A.pale, 1)
    bar:SetHeight(2)
    bar:SetPoint('BOTTOMLEFT', column * 0.18, 0)
    bar:SetPoint('BOTTOMRIGHT', -column * 0.18, 0)
    local barGlow = Widgets.Glow(light, column * 0.8, 8, A.accent:sub(1, 7) .. 'D9', 'ARTWORK')
    barGlow:SetTexCoord(0, 1, 0, 0.5)
    barGlow:SetPoint('BOTTOM', bar, 'BOTTOM', 0, 0)
    local gem = Widgets.Pip(light, 12, A.pale, false, 'OVERLAY', 3)
    gem:SetPoint('CENTER', light, 'BOTTOM', 0, 0)
    local slide = animator(frame, 0.22, function(x)
        light:ClearAllPoints()
        light:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', x, 0)
    end)

    local buttons = {}
    for i, choice in ipairs(spec.choices) do
        local button = CreateFrame('Button', nil, frame)
        button:SetSize(column, 30)
        button:SetPoint('BOTTOMLEFT', (i - 1) * column, 0)
        button:SetFrameLevel(frame:GetFrameLevel() + 2)
        button.text = Widgets.Text(button, 14, C.off)
        button.text:SetPoint('CENTER', 0, 1)
        button.text:SetText(choice[2])
        button.value, button.index, button.hovered = choice[1], i, false
        button:SetScript('OnEnter', function(self)
            self.hovered = true
            frame:Paint()
            if spec.onHelp then
                spec.onHelp(choice[3] or spec.tip)
            end
        end)
        button:SetScript('OnLeave', function(self)
            self.hovered = false
            frame:Paint()
        end)
        button:SetScript('OnClick', EUI.Guard('config choice', function()
            if spec.get() ~= choice[1] then
                playSound('IG_MAINMENU_OPTION')
            end
            spec.set(choice[1])
            frame:Refresh()
        end))
        buttons[#buttons + 1] = button
    end
    local selected = 1
    function frame:Paint()
        for _, button in ipairs(buttons) do
            local on = button.index == selected
            button.text:SetTextColor(Style.Color((on and C.bright) or (button.hovered and C.text) or C.off))
        end
    end
    function frame:Refresh()
        local value = spec.get()
        local index
        for _, button in ipairs(buttons) do
            if button.value == value then
                index = button.index
            end
        end
        light:SetShown(index ~= nil)
        if index then
            local moved = index ~= selected
            selected = index
            slide((index - 1) * column, not moved)
        end
        self:Paint()
    end
    frame:Refresh()
    slide((selected - 1) * column, true)
    return frame
end

-- Slider: a recessed groove filled in the accent up to a diamond thumb, the value after it.
-- spec = { min, max, step, format (pattern or fn(value)), range (fn() -> min, max, re-read on
-- Refresh), width (whole control, default 280), valueColor }. set runs when a drag ends.
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
    -- The groove draws on the slider itself: a child frame would draw over the thumb's diamond.
    local grooveFill = sliced(slider, 'BACKGROUND', 'fill', 3)
    grooveFill:SetPoint('LEFT')
    grooveFill:SetPoint('RIGHT')
    grooveFill:SetHeight(8)
    Widgets.Gradient(grooveFill, 'VERTICAL', '#0B1324FF', '#050A14FF')
    local grooveRim = sliced(slider, 'BORDER', 'ring', 3, '#96B4E14D')
    grooveRim:SetAllPoints(grooveFill)
    local thumb = slider:CreateTexture(nil, 'OVERLAY')
    thumb:SetColorTexture(0, 0, 0, 0)
    thumb:SetSize(14, 22)
    slider:SetThumbTexture(thumb)
    local fill = Widgets.Solid(slider, 'ARTWORK', '#FFFFFFFF')
    fill:SetPoint('TOPLEFT', grooveFill, 'TOPLEFT', 1, -1)
    fill:SetPoint('BOTTOM', grooveFill, 'BOTTOM', 0, 1)
    fill:SetPoint('RIGHT', thumb, 'CENTER')
    Widgets.Gradient(fill, 'HORIZONTAL', A.deep, A.accent)
    local glow = Widgets.Glow(slider, 24, 24, A.accent:sub(1, 7) .. 'B3', 'OVERLAY', 1)
    glow:SetPoint('CENTER', thumb, 'CENTER')
    local gem = Widgets.Pip(slider, 18, '#EAF6FFFF', false, 'OVERLAY', 2)
    gem:SetPoint('CENTER', thumb, 'CENTER')
    slider:SetScript('OnEnter', function()
        glow:SetSize(30, 30)
        if spec.onHelp then
            spec.onHelp(spec.tip)
        end
    end)
    slider:SetScript('OnLeave', function() glow:SetSize(24, 24) end)

    local value = Widgets.Text(frame, 14, spec.valueColor or C.value, spec.valueColor and 'semibold' or 'regular')
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
        glow:SetVertexColor(Style.Color(A.accent))
    end)
    slider:SetScript('OnMouseUp', EUI.Guard('config slider', function()
        dragging = false
        glow:SetVertexColor(Style.Color(A.accent:sub(1, 7) .. 'B3'))
        playSound('U_CHAT_SCROLL_BUTTON')
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
-- Dropdown: a glass button showing the choice, opening a dark glass list under it. spec.choices
-- as Rail; spec.fontPreview: each choice value is a font file, drawn in its own face.

local menu

local function createMenu()
    local frame = CreateFrame('Frame', 'EorzeaUIDropdownMenu', UIParent)
    frame:SetFrameStrata('FULLSCREEN_DIALOG')
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()
    local fill = sliced(frame, 'BACKGROUND', 'fill', 10)
    fill:SetAllPoints()
    Widgets.Gradient(fill, 'VERTICAL', '#0A1121F8', '#28406AF5')
    local rim = sliced(frame, 'BORDER', 'ring', 10, '#AAD7FF66')
    rim:SetAllPoints()
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
    row:SetHeight(28)
    row.bar = Widgets.HoverBar(row)
    row.bar:SetPoint('TOPLEFT', 20, -3)
    row.bar:SetPoint('BOTTOMRIGHT', -4, 3)
    row.cursor = Widgets.Cursor(row, 26, 17)
    row.cursor:SetPoint('LEFT', 0, 0)
    row.text = Widgets.Text(row, 14, C.text)
    row.text:SetPoint('LEFT', 32, 0)
    row.current = false
    row:SetScript('OnEnter', function(self)
        self.bar:SetShown(true)
        if not self.current then
            self.bar:SetAlpha(0.45)
        end
    end)
    row:SetScript('OnLeave', function(self)
        self.bar:SetShown(self.current)
        self.bar:SetAlpha(1)
    end)
    menu.rows[index] = row
    return row
end

local function openMenu(owner, spec, onPick)
    menu = menu or createMenu()
    if menu:IsShown() and rawget(menu, 'owner') == owner then
        menu:Hide()
        return
    end
    menu.owner = owner
    menu:SetScale(owner:GetEffectiveScale() / UIParent:GetEffectiveScale())
    local current = spec.get()
    for i, choice in ipairs(spec.choices) do
        local row = menuRow(i)
        row:ClearAllPoints()
        row:SetPoint('TOPLEFT', 4, -4 - (i - 1) * 28)
        row:SetPoint('TOPRIGHT', -4, -4 - (i - 1) * 28)
        Style.SetFont(row.text, spec.fontPreview and choice[1] or FONTS.regular, spec.fontPreview and 15 or 14, 'OUTLINE')
        row.text:SetText(choice[2])
        row.current = choice[1] == current
        row.text:SetTextColor(Style.Color(row.current and C.bright or '#AEBBD0FF'))
        row.bar:SetVertexColor(Style.Color(A.hover))
        row.bar:SetShown(row.current)
        row.bar:SetAlpha(1)
        Widgets.ShowCursor(row.cursor, row.current)
        row:SetScript('OnClick', EUI.Guard('config dropdown', function()
            menu:Hide()
            playSound('IG_MAINMENU_OPTION')
            onPick(choice[1])
        end))
        row:Show()
    end
    for i = #spec.choices + 1, #menu.rows do
        menu.rows[i]:Hide()
    end
    menu:SetSize(owner:GetWidth(), #spec.choices * 28 + 8)
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
    local button = Widgets.Button(parent, '', function(self)
        openMenu(self, spec, function(value)
            spec.set(value)
            self:Refresh()
        end)
    end, { width = spec.width or 200 })
    button.label:ClearAllPoints()
    button.label:SetPoint('LEFT', 12, 0)
    button.label:SetPoint('RIGHT', -28, 0)
    button.label:SetJustifyH('LEFT')
    local marker = Widgets.Pip(button, 9, C.dim, false, 'OVERLAY')
    marker:SetPoint('RIGHT', -12, 0)
    function button:Refresh()
        local value = spec.get()
        for _, choice in ipairs(spec.choices) do
            if choice[1] == value then
                self.label:SetText(choice[2])
                return
            end
        end
        self.label:SetText(tostring(value))
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

-- A text input in a dark glass well. opts = { width, height, inset (left text inset), font, size }.
function Widgets.Input(parent, opts)
    local box = CreateFrame('EditBox', nil, parent)
    box:SetSize(opts.width or 120, opts.height or 30)
    box:SetAutoFocus(false)
    Style.SetFont(box, opts.font or FONTS.regular, opts.size or 14, '')
    box:SetTextColor(Style.Color(C.text))
    box:SetTextInsets(opts.inset or 12, 10, 0, 0)
    local _, rim = Widgets.Well(box, 8)
    box:SetScript('OnEditFocusGained', function() rim:SetVertexColor(Style.Color(A.rimHot)) end)
    box:SetScript('OnEditFocusLost', function() rim:SetVertexColor(Style.Color(C.wellRim)) end)
    return box
end

local function createPicker()
    local frame = CreateFrame('Frame', 'EorzeaUIColorPicker', UIParent)
    frame:SetSize(300, 272)
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
    frame.title = Widgets.Text(frame, 15, C.title, 'display')
    frame.title:SetPoint('TOPLEFT', 18, -16)

    -- Wheel, brightness and (when editing alpha) opacity, laid out as Blizzard's picker.
    local select = CreateFrame('ColorSelect', nil, frame)
    select:SetSize(248, 128)
    select:SetPoint('TOPLEFT', 18, -46)
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

    local cancel = Widgets.Button(frame, 'Cancel', function() frame:Hide() end)
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

-- A colour cell: a brush stroke of the colour, its label, the hex and a reset glyph while the
-- colour differs from its default. variant: which of the three stroke shapes.
-- spec = { label, tip, alpha (bool), get() -> hex, set(hex), isDefault(), reset(), onHelp }
function Widgets.Color(parent, width, spec, variant)
    local frame = CreateFrame('Frame', nil, parent)
    frame:SetSize(width, 32)
    local swatch = CreateFrame('Button', nil, frame)
    swatch:SetSize(92, 24)
    swatch:SetPoint('LEFT', 0, 0)
    local stroke = Widgets.Brush(swatch, variant or 1, 92, 24, '#FFFFFFFF')
    stroke:SetAllPoints()
    local label = Widgets.Text(frame, 14, C.text)
    label:SetPoint('LEFT', swatch, 'RIGHT', 12, 0)
    label:SetText(spec.label)
    frame.labelText = label
    local hex = Widgets.Text(frame, 12, C.faint, 'mono')
    hex:SetPoint('RIGHT', -26, 0)

    local reset = CreateFrame('Button', nil, frame)
    reset:SetSize(18, 18)
    reset:SetPoint('RIGHT', 0, 0)
    local resetIcon = Widgets.Icon(reset, 'reset', 14, A.text)
    resetIcon:SetPoint('CENTER')
    reset:SetScript('OnEnter', function() resetIcon:SetVertexColor(Style.Color(A.pale)) end)
    reset:SetScript('OnLeave', function() resetIcon:SetVertexColor(Style.Color(A.text)) end)
    reset:SetScript('OnClick', EUI.Guard('config colour reset', function()
        playSound('IG_MAINMENU_OPTION')
        spec.reset()
        frame:Refresh()
    end))

    swatch:SetScript('OnEnter', function()
        stroke:SetAlpha(1)
        if spec.onHelp then
            spec.onHelp(spec.tip)
        end
    end)

    function frame:Refresh()
        local value = spec.get()
        stroke:SetVertexColor(Style.Color(value))
        hex:SetText(value:sub(2, (spec.alpha and 9) or 7))
        reset:SetShown(not spec.isDefault())
    end
    swatch:SetScript('OnClick', EUI.Guard('config colour', function()
        playSound('IG_MAINMENU_OPTION')
        local start, wasDefault = spec.get(), spec.isDefault()
        pickColor(start, spec.alpha, function(newHex)
            spec.set(newHex)
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

---------------------------------------------------------------------------------------------
-- Layout pieces

-- A section title: Cinzel caps and a rule fading to the right. reset (optional) =
-- { isDefault(), reset() }: a Reset link after the rule while the section differs from its defaults.
-- The section reset: "N changed · Reset" inside a half C that opens toward the section rule, its
-- lines and glow fading in from the rule and closing on a diamond at the right end. reset =
-- { isDefault(), reset(), changes() -> { { label, from, to }, ... } }. Hovering the count lists
-- what differs; hovering Reset lists what each option returns to. :Refresh() returns whether anything differs.
local CAP_WIDTH, C_HEIGHT = 13, 26

local function resetC(parent, label, reset)
    local accent = A.accent:sub(1, 7)
    local button = CreateFrame('Button', nil, parent)
    button:SetHeight(C_HEIGHT)
    local capFill = button:CreateTexture(nil, 'BACKGROUND')
    capFill:SetTexture(Style.AssetPath('settings/resetCapFill'))
    capFill:SetSize(CAP_WIDTH, C_HEIGHT)
    capFill:SetPoint('RIGHT', -7, 0)
    unsnap(capFill)
    local capRing = button:CreateTexture(nil, 'BORDER')
    capRing:SetTexture(Style.AssetPath('settings/resetCapRing'))
    capRing:SetAllPoints(capFill)
    unsnap(capRing)
    -- The open side stretches the caps' first texel column, so its lines and fill sample the same
    -- rows as the curve at any sub-pixel offset.
    local fill = button:CreateTexture(nil, 'BACKGROUND')
    fill:SetTexture(Style.AssetPath('settings/resetCapFill'))
    fill:SetTexCoord(0, 1 / 32, 0, 1)
    fill:SetPoint('TOPRIGHT', capFill, 'TOPLEFT')
    fill:SetPoint('BOTTOMRIGHT', capFill, 'BOTTOMLEFT')
    unsnap(fill)
    local rails = button:CreateTexture(nil, 'BORDER')
    rails:SetTexture(Style.AssetPath('settings/resetCapRing'))
    rails:SetTexCoord(0, 1 / 32, 0, 1)
    rails:SetPoint('TOPRIGHT', capFill, 'TOPLEFT')
    rails:SetPoint('BOTTOMRIGHT', capFill, 'BOTTOMLEFT')
    unsnap(rails)
    local hollow = Widgets.Pip(button, 9, A.accent, true, 'OVERLAY', 1)
    hollow:SetPoint('CENTER', button, 'RIGHT', -7, 0)
    local solid = Widgets.Pip(button, 9, A.accent, false, 'OVERLAY', 2)
    solid:SetPoint('CENTER', hollow, 'CENTER')
    local shadow = Widgets.Pip(button, 11, '#0E1729FF', false, 'OVERLAY', 0)
    shadow:SetPoint('CENTER', hollow, 'CENTER')
    local resetText = Widgets.Text(button, 13, A.text)
    resetText:SetText('Reset')
    resetText:SetPoint('RIGHT', -22, 0)
    local sep = Widgets.Text(button, 13, '#5A667AFF')
    sep:SetText('\194\183')
    sep:SetPoint('RIGHT', resetText, 'LEFT', -7, 0)
    local count = Widgets.Text(button, 13, C.goldText)
    count:SetPoint('RIGHT', sep, 'LEFT', -7, 0)
    -- The count is its own hover target, for the list of what changed; clicking it resets too.
    local countHit = CreateFrame('Button', nil, button)
    countHit:SetAllPoints(count)

    local enabled, hovered = false, false
    local function paint()
        local k = enabled and accent or '#6E7D96'
        local strength = (hovered and enabled) and 0.38 or (enabled and 0.22 or 0.08)
        local edge = enabled and 'B3' or '59'
        capFill:SetVertexColor(Style.Color(k .. string.format('%02X', math.floor(strength * 255))))
        capRing:SetVertexColor(Style.Color(k .. edge))
        Widgets.Gradient(fill, 'HORIZONTAL', k .. '00', k .. string.format('%02X', math.floor(strength * 255)))
        Widgets.Gradient(rails, 'HORIZONTAL', k .. '00', k .. edge)
        hollow:SetVertexColor(Style.Color(enabled and A.accent or '#4E5B70FF'))
        solid:SetShown(enabled and hovered)
        resetText:SetTextColor(Style.Color((not enabled and '#4E5B70FF') or (hovered and C.bright) or A.text))
    end
    local function layout()
        local textWidth = resetText:GetStringWidth()
        if count:IsShown() then
            textWidth = textWidth + 7 + sep:GetStringWidth() + 7 + count:GetStringWidth()
        end
        local width = math.ceil(16 + textWidth + 22)
        button:SetWidth(width)
        -- The C spans the right 78% of the button, as the design.
        local open = width * 0.22
        fill:SetPoint('LEFT', button, 'LEFT', open, 0)
        rails:SetPoint('LEFT', button, 'LEFT', open, 0)
    end
    local function doReset()
        if not enabled then
            return
        end
        playSound('IG_MAINMENU_OPTION')
        reset.reset()
    end
    button:SetScript('OnClick', EUI.Guard('config section reset', doReset))
    countHit:SetScript('OnClick', EUI.Guard('config section reset', doReset))
    for _, frame in ipairs({ button, countHit }) do
        frame:HookScript('OnEnter', function()
            hovered = true
            paint()
        end)
        frame:HookScript('OnLeave', function()
            hovered = false
            paint()
        end)
    end
    setTooltip(countHit, 'Changed', function()
        local lines = {}
        for _, change in ipairs(reset.changes()) do
            lines[#lines + 1] = string.format('%s: |cfff0ddb3%s|r', change.label, change.from)
        end
        return #lines > 0 and table.concat(lines, '\n') or nil
    end)
    setTooltip(button, 'Reset ' .. label, function()
        local lines = {}
        for _, change in ipairs(reset.changes()) do
            lines[#lines + 1] = string.format('%s: %s \226\134\146 |cffffffff%s|r', change.label, change.from, change.to)
        end
        return #lines > 0 and table.concat(lines, '\n') or nil
    end)

    function button:Refresh()
        local changes = reset.changes()
        enabled = #changes > 0
        count:SetText(string.format('%d changed', #changes))
        count:SetShown(enabled)
        sep:SetShown(enabled)
        countHit:SetShown(enabled)
        self:EnableMouse(enabled)
        layout()
        paint()
        return enabled
    end
    button:Refresh()
    return button
end

-- A section title: Cinzel caps and a rule fading to the right, ending at the section reset (when
-- reset is given; see resetC).
function Widgets.Header(parent, width, label, reset)
    local holder = CreateFrame('Frame', nil, parent)
    holder:SetSize(width, 26)
    local text = Widgets.Text(holder, 14, C.heading, 'display')
    text:SetPoint('LEFT', 0, 0)
    text:SetText(label:upper())
    local rule = Widgets.FadeLine(holder, '#96B4E18C', 'end')
    local ruleLeft = math.ceil(text:GetStringWidth()) + 12
    local button
    if reset then
        button = resetC(holder, label, reset)
        button:SetPoint('RIGHT', 0, 0)
    end
    function holder:Refresh()
        -- The reset shows only while the section differs from its defaults.
        local shown = button and button:Refresh() or false
        if button then
            button:SetShown(shown)
        end
        rule:ClearAllPoints()
        rule:SetPoint('TOPLEFT', holder, 'TOPLEFT', ruleLeft, -13)
        rule:SetPoint('TOPRIGHT', holder, 'TOPRIGHT', shown and -(button:GetWidth() + 6) or 0, -13)
    end
    holder:Refresh()
    return holder
end

-- Wrapped 14px text. color (optional): the text colour. shown (optional): fn() -> whether the
-- note shows, re-read on each Refresh; it keeps its height while hidden.
function Widgets.Note(parent, width, text, color, shown)
    local holder = CreateFrame('Frame', nil, parent)
    local note = Widgets.Text(holder, 14, color or C.dim)
    note:SetPoint('TOPLEFT', 0, -4)
    note:SetWidth(width)
    note:SetWordWrap(true)
    note:SetSpacing(3)
    note:SetText(text)
    holder:SetSize(width, math.max(22, math.ceil(note:GetStringHeight()) + 10))
    function holder:Refresh()
        if shown then
            note:SetShown(shown() and true or false)
        end
    end
    holder:Refresh()
    return holder
end
