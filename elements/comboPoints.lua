local _, EUI = ...

-- Combo point diamonds in PetsReborn's zigzag, shown as Blizzard's ComboFrame does: nothing at
-- 0 points, all five outlined sockets from 1, lit points filled. The count may be secret, so
-- every piece is a StatusBar fed the count: sockets span (0, 1) and appear from 1 point, pip i
-- spans (i - 1, i) and fills from i points. The engine clamps; Lua never compares.

EUI.ComboPoints = {}
local ComboPoints = {}
ComboPoints.__index = ComboPoints

local Style = EUI.Style

-- At fractional UI scales each texture snaps to the pixel grid on its own, which knocks
-- neighbouring diamonds a pixel out of line; unsnapped, they keep their exact offsets.
local function unsnap(texture)
    if texture.SetSnapToPixelGrid then
        pcall(texture.SetSnapToPixelGrid, texture, false)
    end
    if texture.SetTexelSnappingBias then
        pcall(texture.SetTexelSnappingBias, texture, 0)
    end
end

-- spec = { pos, size = {w, h}, offsets = { {x, y}, ... }, fill, outline, color }
function EUI.ComboPoints.Create(parent, spec)
    local self = setmetatable({ pips = {} }, ComboPoints)
    local frame = CreateFrame('Frame', nil, parent)
    frame:SetSize(spec.size[1], spec.size[2])
    Style.Place(frame, parent, spec.pos)
    self.frame = frame

    local function addBar(path, offset, minValue, level)
        local bar = CreateFrame('StatusBar', nil, frame)
        bar:SetSize(spec.size[1], spec.size[2])
        Style.Place(bar, frame, offset)
        bar:SetFrameLevel(frame:GetFrameLevel() + level)
        bar:SetStatusBarTexture(Style.AssetPath(path))
        bar:SetStatusBarColor(Style.Color(spec.color))
        bar:SetMinMaxValues(minValue, minValue + 1)
        bar:SetValue(minValue)
        unsnap(bar:GetStatusBarTexture())
        self.pips[#self.pips + 1] = bar
    end
    for i, offset in ipairs(spec.offsets) do
        addBar(spec.outline, offset, 0, 1)
        addBar(spec.fill, offset, i - 1, 2)
    end
    frame:Hide()
    return self
end

-- count: number of combo points, possibly secret.
function ComboPoints:SetCount(count)
    for _, pip in ipairs(self.pips) do
        pcall(pip.SetValue, pip, count or 0)
    end
end

function ComboPoints:SetShown(shown)
    self.frame:SetShown(shown)
end
