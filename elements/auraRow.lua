local _, AV = ...

-- Lua cannot read auras in combat on Forever. Blizzard's AuraContainer reads them engine-side;
-- we only supply button art. Creation, unit changes and layout must happen out of combat.

AV.AuraRow = {}
local AuraRow = {}
AuraRow.__index = AuraRow

local loaded = false
local function ensureLoaded()
    if loaded then
        return
    end
    loaded = true
    local loadAddOn = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
    if loadAddOn then
        pcall(loadAddOn, 'Blizzard_AuraContainer')
    end
end

-- Durations are secret, so formatting happens engine-side: "12", "6m", "2h". At most 3
-- characters, so a timer fits under its icon.
local timerFormatter
function AV.AuraRow.TimerFormatter()
    if timerFormatter ~= nil then
        return timerFormatter or nil
    end
    timerFormatter = false
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter and Enum.NumericRuleFormatRounding) then
        return nil
    end
    local ok, formatter = pcall(C_StringUtil.CreateNumericRuleFormatter)
    if not ok or not formatter then
        return nil
    end
    -- Matches Blizzard's buff timers: seconds round down, minutes and hours round up.
    local up = Enum.NumericRuleFormatRounding.Up
    local breakpoints = {
        { threshold = 0, format = '%d', step = 1, rounding = Enum.NumericRuleFormatRounding.Down },
        -- step snaps the input before div truncates, so it must equal div to round up.
        { threshold = 60, format = '%dm', step = 60, rounding = up, components = { { div = 60 } } },
        { threshold = 3600, format = '%dh', step = 3600, rounding = up, components = { { div = 3600 } } },
    }
    if pcall(formatter.SetBreakpoints, formatter, breakpoints) then
        timerFormatter = formatter
    end
    return timerFormatter or nil
end

function AV.AuraRow.StyleTimer(fontString, iconSize, fonts)
    AV.Style.SetFont(fontString, fonts.timer, math.max(9, math.floor(iconSize * 0.5)), 'OUTLINE')
    fontString:SetTextColor(AV.Style.Color('#C8C8C8FF'))
end

-- PreserveAsset keeps our white edge texture; the engine tints it from colorMap by the aura's
-- dispel type and hides it when the aura does not qualify.
local function dispelOptions(kind, colors)
    local colorMap = {}
    for dispelType, hex in pairs(colors) do
        colorMap[dispelType] = CreateColor(AV.Style.Color(hex))
    end
    local options = {
        style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
        showWhenHarmful = kind ~= 'stealable',
        showWhenHelpful = kind == 'stealable',
        customDispelColorMap = colorMap,
    }
    if kind == 'stealable' then
        local filters = Enum.CustomAuraButtonDispelTypeStealableFilter
        options.stealableFilter = filters and filters.Stealable
    end
    return options
end

local function makeInitializer(spec, fonts)
    local size = spec.size
    return function(button)
        button:SetSize(size, size)
        button:EnableMouse(true)

        local border = button:CreateTexture(nil, 'BACKGROUND')
        border:SetAllPoints()
        border:SetColorTexture(AV.Style.Color(spec.border or '#000000D9'))

        local icon = button:CreateTexture(nil, 'ARTWORK')
        icon:SetPoint('TOPLEFT', 1, -1)
        icon:SetPoint('BOTTOMRIGHT', -1, 1)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        if button.SetIcon then
            button:SetIcon(icon)
        end

        -- Covers the plain edge and 1px beyond it, so the coloured edge reads at icon size.
        if spec.dispelBorder and Enum.CustomAuraButtonDispelTypeTextureStyle then
            local dispelBorder = button:CreateTexture(nil, 'BACKGROUND', nil, 1)
            dispelBorder:SetPoint('TOPLEFT', -1, 1)
            dispelBorder:SetPoint('BOTTOMRIGHT', 1, -1)
            dispelBorder:SetColorTexture(1, 1, 1, 1)
            local ok, err = pcall(button.AddDispelTypeTexture, button, dispelBorder, dispelOptions(spec.dispelBorder, spec.dispelColors))
            if not ok then
                AV.LogOnce('aura:dispel:' .. spec.dispelBorder, 'AddDispelTypeTexture (%s) failed: %s', spec.dispelBorder, tostring(err))
            end
        end

        if spec.timers and button.SetDurationText then
            local timer = button:CreateFontString(nil, 'OVERLAY')
            timer:SetPoint('TOP', button, 'BOTTOM', 0, 0)
            local formatter = AV.AuraRow.TimerFormatter()
            pcall(button.SetDurationText, button, timer, formatter and { textFormatter = formatter } or nil)
            -- The binding may restyle the FontString, so the font is applied after it.
            AV.AuraRow.StyleTimer(timer, size, fonts)
        end
        if button.SetApplicationCount then
            local count = button:CreateFontString(nil, 'OVERLAY')
            AV.Style.SetFont(count, fonts.number, math.max(9, math.floor(size * 0.5)), 'OUTLINE')
            count:SetPoint('TOPRIGHT', button, 'TOPRIGHT', 1, 1)
            pcall(button.SetApplicationCount, button, count, {})
        end
    end
end

-- spec = { pos, size, spacing, max, timers, border = '#RRGGBBAA' edge colour,
-- dispelBorder = 'dispel' | 'stealable' | nil, dispelColors = { [dispel type] = '#RRGGBBAA' } }
-- filter: an aura filter, or a list of filters laid out one after another in the row, each
-- showing up to spec.max auras.
function AV.AuraRow.Create(parent, unit, filter, spec, fonts)
    ensureLoaded()
    local self = setmetatable({ unit = unit }, AuraRow)
    local filters = type(filter) == 'table' and filter or { filter }

    local ok, container = pcall(CreateFrame, 'AuraContainer', nil, parent, 'CustomAuraContainerTemplate')
    if not ok or not container then
        AV.Print('AuraContainer unavailable (%s)', tostring(container))
        return self
    end
    container:SetSize((spec.size + spec.spacing) * spec.max * #filters, spec.size)
    AV.Style.Place(container, parent, spec.pos)

    local sortMethod = AuraContainerSortMethod and (AuraContainerSortMethod.Expiration or AuraContainerSortMethod.ExpirationOnly) or 4
    local sortDirection = AuraContainerSortDirection and AuraContainerSortDirection.Normal or 0

    local setupOk, err = pcall(function()
        container:SetUnit(unit)
        if container.SetFlowLayoutAxis and AnchorUtil and AnchorUtil.FlowLayoutAxis then
            container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal or 0)
        end
        if container.SetFlowLayoutAnchorPoint then
            container:SetFlowLayoutAnchorPoint('TOPLEFT')
        end
        -- Groups flow in registration order; trailing element spacing separates them.
        for index, groupFilter in ipairs(filters) do
            container:AddAuraGroup('row' .. index, groupFilter, {
                maxFrameCount = spec.max,
                sortMethod = sortMethod,
                sortDirection = sortDirection,
                initializeFrame = makeInitializer(spec, fonts),
                layout = { elementWidth = spec.size, elementHeight = spec.size, elementSpacing = spec.spacing },
            })
        end
        container:SetEnabled(true)
        container:Show()
    end)
    if not setupOk then
        AV.Print('AuraContainer %s %s setup failed: %s', unit, table.concat(filters, '+'), tostring(err))
        container:Hide()
        return self
    end

    self.container = container
    return self
end

function AuraRow:SetUnit(unit)
    if not self.container or unit == self.unit then
        return
    end
    self.unit = unit
    AV.RunOutOfCombat(function()
        pcall(self.container.SetUnit, self.container, self.unit)
        self:Refresh()
    end)
end

function AuraRow:Refresh()
    if self.container and self.container.UpdateAllAuras then
        pcall(self.container.UpdateAllAuras, self.container)
    end
end
