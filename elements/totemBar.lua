local _, EUI = ...

-- Totem timers as Blizzard's TotemFrame draws them (Blizzard_UnitFrame Mainline/TotemFrame.xml and
-- .lua): one button per active totem in its priority order, packed left to right, each a ring
-- around a round icon with a reverse cooldown swipe and the time left underneath. Right-click
-- dismisses, hover shows the totem tooltip. Sizes are Blizzard's, in UI units: the anchor scales
-- by /ffui scale only, while the "Totems" header takes the root scale like the other labels.
-- All frames are plain: DestroyTotem is not protected, as Blizzard's own plain buttons show.

EUI.TotemBar = {}
local TotemBar = EUI.TotemBar

local Style = EUI.Style

local MAX_TOTEMS = MAX_TOTEMS or 4
local WARNING_TIME = BUFF_DURATION_WARNING_TIME or 60

local function setDurationText(button, timeLeft)
    local duration = button.duration
    local show = timeLeft ~= nil and GetCVarBool and GetCVarBool('buffDurations') ~= false
    duration:SetShown(show)
    if not show then
        return
    end
    if SecondsToTimeAbbrev then
        duration:SetFormattedText(SecondsToTimeAbbrev(timeLeft))
    else
        duration:SetText(tostring(timeLeft))
    end
    local color = timeLeft < WARNING_TIME and HIGHLIGHT_FONT_COLOR or NORMAL_FONT_COLOR
    if color then
        duration:SetVertexColor(color.r, color.g, color.b)
    end
end

local function onUpdate(button)
    local timeLeft = EUI.SafeValue(GetTotemTimeLeft, button.slot)
    if type(timeLeft) == 'number' then
        setDurationText(button, math.ceil(timeLeft))
    end
    if GameTooltip:IsOwned(button) then
        GameTooltip:SetTotem(button.slot)
    end
end

-- The cooldown swipe through Blizzard's CircleMask atlas, as TotemButtonMixin:OnLoad sets it.
local function circleSwipe(cooldown)
    local info = C_Texture and C_Texture.GetAtlasInfo and EUI.SafeValue(C_Texture.GetAtlasInfo, 'CircleMask')
    if not info then
        return
    end
    cooldown:SetSwipeTexture(info.file or info.filename)
    if cooldown.SetTexCoordRange then
        pcall(cooldown.SetTexCoordRange, cooldown, { x = info.leftTexCoord, y = info.topTexCoord },
            { x = info.rightTexCoord, y = info.bottomTexCoord })
    end
end

local function createButton(parent, spec)
    local button = CreateFrame('Button', nil, parent)
    button:SetSize(spec.button, spec.button)
    button:RegisterForClicks('RightButtonUp')
    button:Hide()

    local duration = button:CreateFontString(nil, 'BACKGROUND', 'GameFontNormalSmall')
    duration:SetPoint('TOP', button, 'BOTTOM', 0, spec.durationOffset)
    button.duration = duration

    local border = button:CreateTexture(nil, 'OVERLAY')
    Style.SetAtlas(border, spec.border.atlas)
    border:SetSize(spec.border.size, spec.border.size)
    border:SetPoint('CENTER', spec.border.offset[1], spec.border.offset[2])

    local iconFrame = CreateFrame('Frame', nil, button)
    iconFrame:SetSize(spec.icon, spec.icon)
    iconFrame:SetPoint('CENTER')
    iconFrame:SetFrameLevel(button:GetFrameLevel())
    local icon = iconFrame:CreateTexture(nil, 'BACKGROUND', nil, 2)
    icon:SetAllPoints(iconFrame)
    local mask = iconFrame:CreateMaskTexture()
    mask:SetAllPoints(iconFrame)
    Style.SetAtlas(mask, 'CircleMask')
    pcall(mask.SetTexture, mask, mask:GetTexture(), 'CLAMPTOBLACKADDITIVE', 'CLAMPTOBLACKADDITIVE')
    icon:AddMaskTexture(mask)
    button.icon = icon

    local cooldown = CreateFrame('Cooldown', nil, iconFrame, 'CooldownFrameTemplate')
    cooldown:SetAllPoints(iconFrame)
    cooldown:SetFrameLevel(iconFrame:GetFrameLevel())
    cooldown:SetHideCountdownNumbers(true)
    cooldown:SetReverse(true)
    cooldown:SetSwipeColor(Style.Color(spec.swipeColor))
    circleSwipe(cooldown)
    button.cooldown = cooldown

    button:SetScript('OnClick', EUI.Guard('totem click', function(self, mouseButton)
        if mouseButton == 'RightButton' and self.slot and self.slot > 0
            and not EUI.SafeValue(GetTotemCannotDismiss, self.slot) then
            DestroyTotem(self.slot)
        end
    end))
    button:SetScript('OnEnter', function(self)
        if self.slot then
            GameTooltip:SetOwner(self, 'ANCHOR_BOTTOMRIGHT')
            GameTooltip:SetTotem(self.slot)
        end
    end)
    button:SetScript('OnLeave', function()
        GameTooltip:Hide()
    end)
    return button
end

-- Blizzard's HorizontalLayoutFrame settings: leftPadding, topPadding and (negative) spacing.
local function layout(self, shown)
    local spec = self.spec
    local x = spec.leftPadding
    for _, button in ipairs(shown) do
        button:ClearAllPoints()
        button:SetPoint('TOPLEFT', self.frame, 'TOPLEFT', x, -spec.topPadding)
        x = x + spec.button + spec.spacing
    end
    self.frame:SetShown(#shown > 0)
end

function TotemBar.Create(style)
    local spec = style.totems
    TotemBar.spec = spec
    local anchor = CreateFrame('Frame', 'EorzeaUITotemAnchor', UIParent)
    anchor:SetSize(spec.leftPadding + MAX_TOTEMS * spec.button + (MAX_TOTEMS - 1) * spec.spacing,
        spec.button - spec.topPadding + spec.durationHeight)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    TotemBar.anchor = anchor

    local frame = CreateFrame('Frame', nil, anchor)
    frame:SetAllPoints(anchor)
    frame:Hide()
    TotemBar.frame = frame

    -- The header lives in its own frame at the root scale, above the buttons.
    local headerHost = CreateFrame('Frame', nil, frame)
    headerHost:SetPoint('BOTTOMLEFT', anchor, 'TOPLEFT', 0, spec.headerGap)
    TotemBar.headerHost = headerHost
    TotemBar.header = Style.Header(headerHost, spec.header, style.fonts)

    TotemBar.buttons = {}
    for i = 1, MAX_TOTEMS do
        TotemBar.buttons[i] = createButton(frame, spec)
    end
    TotemBar.ApplyScale()
end

function TotemBar.ApplyScale()
    local anchor = TotemBar.anchor
    if not anchor then
        return
    end
    local userScale = EUI.Settings.Get('scale')
    anchor:SetScale(userScale * (EUI.Settings.Get('scales.totems') or 1))
    local headerScale = EUI.Style.RootScale() / userScale
    local host = TotemBar.headerHost
    host:SetScale(headerScale)
    local width = anchor:GetWidth() / headerScale
    host:SetSize(width, TotemBar.spec.header.height)
    TotemBar.header:SetWidth(width)
end

-- Blizzard's TotemFrameMixin:Update: active totems in priority order (SHAMAN_TOTEM_PRIORITIES
-- for shamans).
function TotemBar.Update()
    if TotemBar.preview or not TotemBar.frame or not GetTotemInfo then
        return
    end
    local class = EUI.SafeValue(function() return select(2, UnitClass('player')) end)
    local priorities = class == 'SHAMAN' and SHAMAN_TOTEM_PRIORITIES or STANDARD_TOTEM_PRIORITIES
    local shown = {}
    for i = 1, MAX_TOTEMS do
        local button = TotemBar.buttons[i]
        local slot = priorities and priorities[i] or i
        local ok, haveTotem, _, startTime, duration, icon = pcall(GetTotemInfo, slot)
        local readable = ok and EUI.CanAccess(haveTotem) and EUI.CanAccess(duration) and EUI.CanAccess(startTime)
        if ok and not readable then
            EUI.LogOnce('totem:secret', 'totem info is secret; totem timers hidden')
        end
        if readable and haveTotem and duration > 0 then
            button.slot = slot
            button.icon:SetTexture(icon)
            button.cooldown:SetCooldown(startTime, duration)
            button:SetScript('OnUpdate', onUpdate)
            button:Show()
            onUpdate(button)
            shown[#shown + 1] = button
        else
            button.slot = nil
            button:SetScript('OnUpdate', nil)
            button:Hide()
        end
    end
    layout(TotemBar, shown)
end

-- Demo and Edit Mode: samples = { { icon, timeLeft, duration }, ... }, or nil for live totems.
function TotemBar.SetPreview(samples)
    if not TotemBar.frame then
        return
    end
    TotemBar.preview = samples ~= nil
    if not samples then
        TotemBar.Update()
        return
    end
    local shown = {}
    for i, button in ipairs(TotemBar.buttons) do
        local sample = samples[i]
        button.slot = nil
        button:SetScript('OnUpdate', nil)
        button:SetShown(sample ~= nil)
        if sample then
            button.icon:SetTexture(sample[1])
            button.cooldown:SetCooldown(GetTime() - (sample[3] - sample[2]), sample[3])
            setDurationText(button, sample[2])
            shown[#shown + 1] = button
        end
    end
    layout(TotemBar, shown)
end
