local _, EUI = ...

-- Drawing pieces shared by the party rows, pet sub-rows and target bars.

EUI.UnitVisual = {}
local UnitVisual = EUI.UnitVisual

local Style = EUI.Style

-- Class icons and portraits are drawn as ringed circles; cropping to the inscribed square
-- (14.6% per side) drops the ring so the art fills the square job frame.
local CIRCLE_INSET = 0.146

-- Crops texture's (left, right, top, bottom) sub-rectangle, default the whole texture.
function UnitVisual.CropCircle(texture, left, right, top, bottom)
    left, right, top, bottom = left or 0, right or 1, top or 0, bottom or 1
    local dx, dy = (right - left) * CIRCLE_INSET, (bottom - top) * CIRCLE_INSET
    texture:SetTexCoord(left + dx, right - dx, top + dy, bottom - dy)
end

-- The job frame: background, gradient (tinted by class), a picture inset by inset, and the frame
-- art on top. art = { bg, gradient, frame } paths. Returns the frame, gradient and picture.
function UnitVisual.JobFrame(parent, pos, size, inset, art)
    local frame = CreateFrame('Frame', nil, parent)
    frame:SetSize(size, size)
    Style.Place(frame, parent, pos)
    local full = { 0, 0 }
    Style.Image(frame, 'BACKGROUND', { path = art.bg, pos = full, size = { size, size } })
    local gradient = Style.Image(frame, 'BORDER', { path = art.gradient, pos = full, size = { size, size } })
    local picture = frame:CreateTexture(nil, 'ARTWORK')
    picture:SetPoint('TOPLEFT', inset, -inset)
    picture:SetPoint('BOTTOMRIGHT', -inset, inset)
    Style.Image(frame, 'OVERLAY', { path = art.frame, pos = full, size = { size, size } })
    return frame, gradient, picture
end

-- Secure button hooks for a visual object with hover, SetUnit, Refresh and unit: hover
-- highlight, unit tooltip, unit attribute changes and a refresh on show.
function UnitVisual.AttachButton(object, button)
    button:HookScript('OnEnter', function()
        object.hover:Show()
    end)
    button:HookScript('OnLeave', function()
        object.hover:Hide()
    end)
    EUI.AttachUnitTooltip(button, function() return object.unit end)
    button:HookScript('OnAttributeChanged', function(_, name, value)
        if name == 'unit' then
            object:SetUnit(value)
        end
    end)
    button:HookScript('OnShow', function()
        object:Refresh()
    end)
end

-- Tints bar's frame and fill with color when key (a power type, or a stand-in) changes.
function UnitVisual.TintBar(bar, key, color)
    if key == bar.tintKey then
        return
    end
    bar.tintKey = key
    bar:SetFrameColor(color)
    bar:SetFillColor(color)
end

-- hpSpec.thresholds' colour for a health fraction, else hpSpec.textColor.
function UnitVisual.ThresholdColor(hpSpec, fraction)
    for _, step in ipairs(hpSpec.thresholds) do
        if fraction < step.below then
            return step.color
        end
    end
    return hpSpec.textColor
end

-- Demo numbers, with the client's thousands separators.
function UnitVisual.FormatNumber(value)
    return BreakUpLargeNumbers and BreakUpLargeNumbers(value) or tostring(value)
end

-- A raid marker, then an AFK/DND flag, sit where the name starts and push it right. Places the
-- flag after a shown marker and returns the name's shift. flag is optional.
function UnitVisual.NameLineShift(parent, marker, markerSpec, flag, flagSpec)
    local shift = marker:IsShown() and (markerSpec.size[1] + 3) or 0
    if flag and flag:IsShown() then
        Style.Place(flag, parent, { flagSpec.pos[1] + shift, flagSpec.pos[2] })
        shift = shift + flagSpec.size[1] + 3
    end
    return shift
end
