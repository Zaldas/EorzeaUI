local _, AV = ...

-- A row of plain icon textures with timer text. Stands in for an AuraContainer in demo mode,
-- which cannot be fed fake auras.

AV.StaticIcons = {}
local StaticIcons = {}
StaticIcons.__index = StaticIcons

-- spec = { pos, size, spacing, max, timers }
function AV.StaticIcons.Create(parent, spec, fonts)
    local self = setmetatable({ slots = {} }, StaticIcons)
    local frame = CreateFrame('Frame', nil, parent)
    frame:SetSize((spec.size + spec.spacing) * spec.max, spec.size)
    AV.Style.Place(frame, parent, spec.pos)
    self.frame = frame

    for i = 1, spec.max do
        local slot = CreateFrame('Frame', nil, frame)
        slot:SetSize(spec.size, spec.size)
        slot:SetPoint('TOPLEFT', frame, 'TOPLEFT', (i - 1) * (spec.size + spec.spacing), 0)
        local border = slot:CreateTexture(nil, 'BACKGROUND')
        border:SetAllPoints()
        border:SetColorTexture(AV.Style.Color(spec.border or '#000000D9'))
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

-- icons = { { texture, timer }, ... }
function StaticIcons:Set(icons)
    for i, slot in ipairs(self.slots) do
        local entry = icons and icons[i]
        if entry then
            slot.icon:SetTexture(entry[1])
            slot.timer:SetText(entry[2] or '')
            slot:Show()
        else
            slot:Hide()
        end
    end
    self.frame:SetShown(icons ~= nil)
end
