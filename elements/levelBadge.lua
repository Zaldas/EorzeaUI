local _, AV = ...

-- Level number straddling an edge of the class icon.

AV.LevelBadge = {}
local LevelBadge = {}
LevelBadge.__index = LevelBadge

-- spec = { size = {w, h}, textSize, textOffset = {x, y}, color, edge, overlap }
-- edge: side of `anchor` the label straddles ('BOTTOM' | 'LEFT'); overlap: fraction of the
-- label box lying on the anchor (0.5 = centred on the edge).
function AV.LevelBadge.Create(parent, anchor, spec, fonts)
    local self = setmetatable({}, LevelBadge)
    local w, h = spec.size[1], spec.size[2]
    local frame = CreateFrame('Frame', nil, parent)
    frame:SetSize(w, h)
    local shift = 0.5 - (spec.overlap or 0.5)
    if spec.edge == 'LEFT' then
        frame:SetPoint('CENTER', anchor, 'LEFT', -w * shift, 0)
    else
        frame:SetPoint('CENTER', anchor, 'BOTTOM', 0, -h * shift)
    end
    self.frame = frame

    -- Friz Quadrata has no bold face; the thick outline gives the heavier weight.
    local offset = spec.textOffset or { 0, 0 }
    self.text = frame:CreateFontString(nil, 'OVERLAY')
    self.text:SetFont(AV.Style.FontPath(fonts.standard), spec.textSize, 'THICKOUTLINE')
    self.text:SetPoint('TOPLEFT', offset[1], offset[2])
    self.text:SetPoint('BOTTOMRIGHT', offset[1], offset[2])
    self.text:SetJustifyH('CENTER')
    self.text:SetJustifyV('MIDDLE')
    self.text:SetTextColor(AV.Style.Color(spec.color))
    return self
end

-- level: number, or nil to hide. Non-positive levels (unknown) show "??".
function LevelBadge:Set(level)
    if not level then
        self.frame:Hide()
        return
    end
    self.text:SetText(level > 0 and tostring(level) or '??')
    self.frame:Show()
end
