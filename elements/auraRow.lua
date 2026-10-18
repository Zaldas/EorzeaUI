local _, EUI = ...

-- Lua cannot read auras in combat on Forever. Blizzard's AuraContainer reads them engine-side;
-- we only supply button art. Creation and layout must happen out of combat; a unit change in
-- combat is tried at once and otherwise waits for combat to end.

EUI.AuraRow = {}
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
function EUI.AuraRow.TimerFormatter()
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

function EUI.AuraRow.StyleTimer(fontString, iconSize, fonts)
    EUI.Style.SetFont(fontString, fonts.timer, math.max(9, math.floor(iconSize * 0.5)), 'OUTLINE')
    fontString:SetTextColor(EUI.Style.Color('#C8C8C8FF'))
end

-- PreserveAsset keeps our white edge texture; the engine tints it from colorMap by the aura's
-- dispel type and hides it when the aura does not qualify.
local function dispelOptions(kind, colors)
    local colorMap = {}
    for dispelType, hex in pairs(colors) do
        colorMap[dispelType] = CreateColor(EUI.Style.Color(hex))
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
        border:SetColorTexture(EUI.Style.Color(spec.border or '#000000D9'))

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
                EUI.LogOnce('aura:dispel:' .. spec.dispelBorder, 'AddDispelTypeTexture (%s) failed: %s', spec.dispelBorder, tostring(err))
            end
        end

        if spec.timers and button.SetDurationText then
            local timer = button:CreateFontString(nil, 'OVERLAY')
            timer:SetPoint('TOP', button, 'BOTTOM', 0, 0)
            local formatter = EUI.AuraRow.TimerFormatter()
            pcall(button.SetDurationText, button, timer, formatter and { textFormatter = formatter } or nil)
            -- The binding may restyle the FontString, so the font is applied after it.
            EUI.AuraRow.StyleTimer(timer, size, fonts)
        end
        if button.SetApplicationCount then
            local count = button:CreateFontString(nil, 'OVERLAY')
            EUI.Style.SetFont(count, fonts.number, math.max(9, math.floor(size * 0.5)), 'OUTLINE')
            count:SetPoint('TOPRIGHT', button, 'TOPRIGHT', 1, 1)
            pcall(button.SetApplicationCount, button, count, {})
        end
    end
end

-- The spec for one filter's group: spec.groups[filter] fields override spec's.
function EUI.AuraRow.GroupSpec(spec, filter)
    local overrides = spec.groups and spec.groups[filter]
    if not overrides then
        return spec
    end
    local merged = {}
    for key, value in pairs(spec) do
        merged[key] = value
    end
    for key, value in pairs(overrides) do
        merged[key] = value
    end
    return merged
end

-- Width of a line holding spec.perLine icons, or nil when the row does not wrap.
function EUI.AuraRow.LineWidth(spec)
    if not spec.perLine then
        return nil
    end
    return spec.perLine * spec.size + (spec.perLine - 1) * spec.spacing
end

-- spec = { pos, size, spacing, max, timers, border = '#RRGGBBAA' edge colour,
-- dispelBorder = 'dispel' | 'stealable' | nil, dispelColors = { [dispel type] = '#RRGGBBAA' },
-- perLine = icons per line before wrapping (nil: one line), lineSpacing = gap between lines,
-- groups = { [name] = per-group overrides of max, dispelBorder, dispelColors, ... },
-- processAuras = classify auras with AuraUtil.ProcessAura, as Blizzard's raid frames do }
-- A group may also set filter (the aura filter, default its name), auraType ('Debuff', 'Dispel'
-- or 'Buff': ProcessAura's class, with processAuras) and sort (an AuraContainerSortMethod key,
-- default Expiration).
-- filter: an aura filter or group name, or a list of them laid out one after another in the row,
-- each showing up to its group's max auras.
function EUI.AuraRow.Create(parent, unit, filter, spec, fonts)
    ensureLoaded()
    local self = setmetatable({ unit = unit }, AuraRow)
    local filters = type(filter) == 'table' and filter or { filter }

    local ok, container = pcall(CreateFrame, 'AuraContainer', nil, parent, 'CustomAuraContainerTemplate')
    if not ok or not container then
        EUI.Print('AuraContainer unavailable (%s)', tostring(container))
        return self
    end
    local count = 0
    for _, groupFilter in ipairs(filters) do
        count = count + EUI.AuraRow.GroupSpec(spec, groupFilter).max
    end
    local lineWidth = EUI.AuraRow.LineWidth(spec)
    container:SetSize(lineWidth or (spec.size + spec.spacing) * count, spec.size)
    EUI.Style.Place(container, parent, spec.pos)

    local defaultSort = AuraContainerSortMethod and (AuraContainerSortMethod.Expiration or AuraContainerSortMethod.ExpirationOnly) or 4
    local sortDirection = AuraContainerSortDirection and AuraContainerSortDirection.Normal or 0

    local setupOk, err = pcall(function()
        container:SetUnit(unit)
        if spec.processAuras then
            container:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.ProcessAura, {})
        end
        if container.SetFlowLayoutAxis and AnchorUtil and AnchorUtil.FlowLayoutAxis then
            container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal or 0)
        end
        if container.SetFlowLayoutAnchorPoint then
            container:SetFlowLayoutAnchorPoint('TOPLEFT')
        end
        if lineWidth then
            container:SetFlowLayoutMaximumLineSize(lineWidth)
        end
        -- Groups flow in registration order; trailing element spacing separates them.
        for index, groupName in ipairs(filters) do
            local groupSpec = EUI.AuraRow.GroupSpec(spec, groupName)
            local candidateFilters
            if groupSpec.auraType then
                candidateFilters = { processedAuraType = AuraUtil.AuraUpdateChangedType[groupSpec.auraType] }
            end
            container:AddAuraGroup('row' .. index, groupSpec.filter or groupName, {
                maxFrameCount = groupSpec.max,
                sortMethod = groupSpec.sort and AuraContainerSortMethod[groupSpec.sort] or defaultSort,
                sortDirection = sortDirection,
                candidateFilters = candidateFilters,
                initializeFrame = makeInitializer(groupSpec, fonts),
                layout = {
                    elementWidth = spec.size,
                    elementHeight = spec.size,
                    elementSpacing = spec.spacing,
                    lineSpacing = spec.lineSpacing,
                },
            })
        end
        container:SetEnabled(true)
        container:Show()
    end)
    if not setupOk then
        EUI.Print('AuraContainer %s %s setup failed: %s', unit, table.concat(filters, '+'), tostring(err))
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
    if InCombatLockdown() then
        local ok, err = pcall(self.container.SetUnit, self.container, unit)
        if ok then
            EUI.LogOnce('aura:setUnitCombatOk', 'AuraContainer:SetUnit in combat works (%s)', tostring(unit))
            self:Refresh()
            return
        end
        EUI.LogOnce('aura:setUnitCombat', 'AuraContainer:SetUnit in combat failed, deferred: %s', tostring(err))
    end
    EUI.RunOutOfCombat(function()
        pcall(self.container.SetUnit, self.container, self.unit)
        self:Refresh()
    end, self)
end

function AuraRow:Refresh()
    if self.container and self.container.UpdateAllAuras then
        pcall(self.container.UpdateAllAuras, self.container)
    end
end
