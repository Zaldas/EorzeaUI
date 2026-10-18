local _, EUI = ...

-- Level number straddling an edge of the class icon.

EUI.LevelBadge = {}
local LevelBadge = {}
LevelBadge.__index = LevelBadge

-- spec = { size = {w, h}, textSize, textOffset = {x, y}, color, edge, overlap, skull = { atlas, path } }
-- skull.path: an asset under assets/ or, holding a backslash, a game texture.
-- edge: side of `anchor` the label straddles ('BOTTOM' | 'LEFT'); overlap: fraction of the
-- label box lying on the anchor (0.5 = centred on the edge).
function EUI.LevelBadge.Create(parent, anchor, spec, fonts)
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
    EUI.Style.SetFont(self.text, fonts.standard, spec.textSize, 'THICKOUTLINE')
    self.text:SetPoint('TOPLEFT', offset[1], offset[2])
    self.text:SetPoint('BOTTOMRIGHT', offset[1], offset[2])
    self.text:SetJustifyH('CENTER')
    self.text:SetJustifyV('MIDDLE')
    self.text:SetTextColor(EUI.Style.Color(spec.color))
    self.color = spec.color

    -- Replaces the number for unknown levels and corpses, as on Blizzard's target frame.
    self.skull = frame:CreateTexture(nil, 'OVERLAY')
    local skull = spec.skull
    local path = skull.path
    if path and not path:find('\\', 1, true) then
        path = EUI.Style.AssetPath(path)
    end
    if skull.atlas then
        EUI.Style.SetAtlas(self.skull, skull.atlas, path and { path = path })
    else
        self.skull:SetTexture(path)
    end
    self.skull:SetSize(h, h)
    self.skull:SetPoint('CENTER', offset[1], offset[2])
    self.skull:Hide()
    return self
end

-- r, g, b in 0..1, or nil to restore the spec colour.
function LevelBadge:SetColor(r, g, b)
    if r then
        self.text:SetTextColor(r, g, b, 1)
    else
        self.text:SetTextColor(EUI.Style.Color(self.color))
    end
end

-- level: number, or nil to hide. Non-positive levels (unknown) and skull (a corpse) show the
-- skull in place of the number.
function LevelBadge:Set(level, skull)
    if not level and not skull then
        self.frame:Hide()
        return
    end
    skull = skull == true or level <= 0
    self.text:SetShown(not skull)
    self.skull:SetShown(skull)
    if not skull then
        self.text:SetText(tostring(level))
    end
    self.frame:Show()
end
