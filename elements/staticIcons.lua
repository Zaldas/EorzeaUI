local _, AV = ...

-- A row of plain icon textures with timer text. Stands in for an AuraContainer in demo mode,
-- which cannot be fed fake auras.

AV.StaticIcons = {}
local StaticIcons = {}
StaticIcons.__index = StaticIcons

-- The total of each group's max when spec.groups sets them, else spec.max.
local function slotCount(spec)
    if not spec.groups then
        return spec.max
    end
    local count = 0
    for filter in pairs(spec.groups) do
        count = count + AV.AuraRow.GroupSpec(spec, filter).max
    end
    return count
end

-- spec = { pos, size, spacing, max, timers, border, dispelBorder, dispelColors, perLine,
-- lineSpacing, groups } as in AuraRow.
function AV.StaticIcons.Create(parent, spec, fonts)
    local self = setmetatable({ slots = {} }, StaticIcons)
    local count = slotCount(spec)
    local perLine = spec.perLine or count
    local frame = CreateFrame('Frame', nil, parent)
    frame:SetSize(AV.AuraRow.LineWidth(spec) or (spec.size + spec.spacing) * count, spec.size)
    AV.Style.Place(frame, parent, spec.pos)
    self.frame = frame
    self.spec = spec

    for i = 1, count do
        local slot = CreateFrame('Frame', nil, frame)
        slot:SetSize(spec.size, spec.size)
        local column, line = (i - 1) % perLine, math.floor((i - 1) / perLine)
        slot:SetPoint('TOPLEFT', frame, 'TOPLEFT', column * (spec.size + spec.spacing), -line * (spec.size + (spec.lineSpacing or 0)))
        local border = slot:CreateTexture(nil, 'BACKGROUND')
        border:SetAllPoints()
        border:SetColorTexture(AV.Style.Color(spec.border or '#000000D9'))
        slot.dispelEdge = slot:CreateTexture(nil, 'BACKGROUND', nil, 1)
        slot.dispelEdge:SetPoint('TOPLEFT', -1, 1)
        slot.dispelEdge:SetPoint('BOTTOMRIGHT', 1, -1)
        slot.dispelEdge:Hide()
        slot.icon = slot:CreateTexture(nil, 'ARTWORK')
        slot.icon:SetPoint('TOPLEFT', 1, -1)
        slot.icon:SetPoint('BOTTOMRIGHT', -1, 1)
        slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        slot.timer = slot:CreateFontString(nil, 'OVERLAY')
        slot.timer:SetPoint('TOP', slot, 'BOTTOM', 0, 0)
        AV.AuraRow.StyleTimer(slot.timer, spec.size, fonts)
        slot.timer:SetShown(spec.timers == true)
        slot:Hide()
        self.slots[i] = slot
    end
    return self
end

-- The edge colour a live AuraRow with the same spec would give entry, or nil.
local function dispelColor(spec, entry)
    if entry.group then
        spec = AV.AuraRow.GroupSpec(spec, entry.group)
    end
    local colors = spec.dispelColors
    if not colors then
        return nil
    end
    if spec.dispelBorder == 'stealable' then
        return entry.stealable and colors.Magic or nil
    end
    return entry.dispel and colors[entry.dispel]
end

-- icons = { { texture, timer, dispel = dispel type name, stealable = bool,
-- group = filter whose spec.groups entry styles it }, ... }
function StaticIcons:Set(icons)
    for i, slot in ipairs(self.slots) do
        local entry = icons and icons[i]
        if entry then
            slot.icon:SetTexture(entry[1])
            slot.timer:SetText(entry[2] or '')
            local color = dispelColor(self.spec, entry)
            if color then
                slot.dispelEdge:SetColorTexture(AV.Style.Color(color))
            end
            slot.dispelEdge:SetShown(color ~= nil)
            slot:Show()
        else
            slot:Hide()
        end
    end
    self.frame:SetShown(icons ~= nil)
end
